# Receipt 1b — Same prompt, rules loaded

**How this was produced.** Claude (same model class, fresh context) was given the **identical
feature request** as [`01-before-no-rules.md`](01-before-no-rules.md), but was first told to read
the plugin's compass and the applicable `rules/*.mdc` files and follow them. The output is
unedited, including the model's own rule citations.

**The diff that matters** (same prompt, same model — the only variable is the rules):

| Decision | Without rules | With rules |
|---|---|---|
| State modelling | `archived_at` timestamp + `archived_by` FK columns on `projects` | `Archival` child record — the row's existence *is* the state; its `created_at` is the archived time; unique index enforces one-per-project |
| Routes | `patch :archive` / `patch :unarchive` member verbs + `get :archived` collection | `resource :archival, only: [:create, :destroy]` under `scope module: :projects`; archived page is its own `resources :archived_projects, only: :index` |
| Controller | Verb actions on `ProjectsController` | `Projects::ArchivalsController#create/#destroy` — CRUD only |
| Domain verbs | `archive!(archiver)` / `unarchive!` bang methods | `archive(by: Current.user)` / `unarchive` — non-bang, bang stays on the internal AR calls |
| Policy | Custom `archive?` / `unarchive?` verb methods | `Projects::ArchivalPolicy#create?/#destroy?` — CRUD-only policy mirroring the controller |
| Strong params | `params.require(:project).permit(...)` | (untouched here; plugin mandates `params.expect`) |
| Authorization site | `authorize` inside the `set_project` before_action | `authorize` in the action body; `before_action` only finds the record |
| Tests | Model + policy + request, with the journey re-tested across layers | Explicit layer ownership: model owns logic, policy owns matrix, request owns HTTP gates, exactly **one** system journey within the budget |

---

## Rules-loaded output (unedited)

I've read all the plugin rules. Key shape decisions before the code:

- **Archival is a state record, not a boolean** — the feature needs a timestamp *and* an actor ("who archived it"), which is exactly the trigger for a child record whose existence *is* the state (per `rules/models.mdc` § State as Records, Not Booleans). The record's `created_at` is the archived time — no duplicate `archived_at` column.
- **Archive/unarchive are CRUD on a noun resource** — `Projects::ArchivalsController#create`/`#destroy`, not `post :archive` (per `rules/controllers.mdc` § Everything Maps to CRUD).
- **The "Archived" page is its own index resource** — `resources :archived_projects, only: :index`, not a custom collection verb (per `rules/routes.mdc` § Member vs Collection).
- **No service objects** — the logic is two one-liners on `Project` (per `rules/services.mdc` § There Is No Service Layer).

Assumptions (stated per the compass's "document exceptions"): the app already has `User`, `Project belongs_to :creator`, Rails 8 built-in authentication with `Current.user`, the `ApplicationController` Pundit posture from `rules/controllers.mdc`, and a `sign_in(user)` spec helper.

---

# Archive / Unarchive Projects

## `db/migrate/20260731120000_create_archivals.rb`

> Reversible `def change`; DB constraints (NOT NULL, FKs, unique index) are the source of truth, per `rules/migrations.mdc`. `archiver_id` is a semantic FK name because the role differs from the class, per `rules/naming.mdc` § Database.

```ruby
class CreateArchivals < ActiveRecord::Migration[8.0]
  def change
    create_table :archivals do |t|
      # Unique index: a project has at most one archival — the row's existence is the state
      t.references :project,  null: false, foreign_key: true, index: { unique: true }
      t.references :archiver, null: false, foreign_key: { to_table: :users }

      t.timestamps # created_at IS the archived-at time — no duplicate column
    end
  end
end
```

## `app/models/archival.rb`

> Top-level noun for the state (`Closure`, `Publication`, `Archival`), per `rules/naming.mdc` § Domain Layer. Association default via `Current`, per `rules/models.mdc` § Association Defaults with Current.

```ruby
class Archival < ApplicationRecord
  belongs_to :project
  belongs_to :archiver, class_name: "User", default: -> { Current.user }
end
```

## `app/models/project.rb` (additions)

> Domain verbs, non-bang (`archive`, `unarchive`), predicates with `?`, query logic in named scopes, no `default_scope`, per `rules/models.mdc` § State as Records / § Scopes / § Bang Convention.

```ruby
class Project < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_one :archival, dependent: :destroy

  scope :active,                  -> { where.missing(:archival) }
  scope :archived,                -> { joins(:archival) }
  scope :recently_archived_first, -> { order(archivals: { created_at: :desc }) }
  scope :alphabetically,          -> { order(:name) }

  def archived? = archival.present?

  def archive(by: Current.user)
    create_archival!(archiver: by)
  end

  def unarchive
    archival&.destroy!
  end
end
```

## `config/routes.rb` (additions)

> `scope module: :projects` so the singleton archival routes to `Projects::ArchivalsController`, per `rules/controllers.mdc` § Everything Maps to CRUD. Unused actions trimmed with `only:`, per `rules/routes.mdc` § Defaults.

```ruby
Rails.application.routes.draw do
  resources :projects do
    scope module: :projects do
      # Archiving is state, not a verb: POST creates the archival, DELETE restores
      resource :archival, only: %i[ create destroy ]
    end
  end

  # The "Archived" page — a read-only index of the archived set,
  # a new noun resource rather than a custom collection action (rules/routes.mdc)
  resources :archived_projects, only: :index
end
```

## `app/controllers/projects/archivals_controller.rb`

> Thin controller delegating to model verbs; `authorize` in the action body (not `before_action`); redirect on success, per `rules/controllers.mdc`. Record lookup is a top-level find since `project_id` is the identity here.

```ruby
class Projects::ArchivalsController < ApplicationController
  before_action :set_project

  def create
    authorize @project, policy_class: Projects::ArchivalPolicy
    @project.archive(by: Current.user)
    redirect_to projects_path, notice: "Project archived."
  end

  def destroy
    authorize @project, policy_class: Projects::ArchivalPolicy
    @project.unarchive
    redirect_to archived_projects_path, notice: "Project restored."
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end
end
```

## `app/controllers/archived_projects_controller.rb`

> `policy_scope` + `authorize` on index — visibility rules are identical to the main list, so this reuses `ProjectPolicy` rather than inventing a second policy, per `rules/policies.mdc` § Scoping Collections.

```ruby
class ArchivedProjectsController < ApplicationController
  def index
    @projects = policy_scope(Project).archived.recently_archived_first.includes(archival: :archiver)
    authorize Project
  end
end
```

## `app/controllers/projects_controller.rb` (index change only)

```ruby
class ProjectsController < ApplicationController
  def index
    @projects = policy_scope(Project).active.alphabetically
    authorize Project
  end

  # show/new/create/edit/update/destroy unchanged
end
```

## `app/policies/projects/archival_policy.rb`

> State-change policy in the noun-resource namespace mirroring the controller (`Projects::ArchivalPolicy`), CRUD methods only — no `archive?` custom verb, per `rules/naming.mdc` § Policies and `rules/policies.mdc`. The record is the `Project`, since the archival's existence is project state. Note `destroy?` does **not** check `archived?` — policies answer "who may", not "what happens" (`unarchive` is a safe no-op), per `rules/policies.mdc` § Why Pundit.

```ruby
class Projects::ArchivalPolicy < ApplicationPolicy
  def create?  = creator?
  def destroy? = creator?

  private
    def creator?
      record.creator == user
    end
end
```

## `app/policies/project_policy.rb` (existing, shown for the scope the feature relies on)

```ruby
class ProjectPolicy < ApplicationPolicy
  def index?   = user.present?
  def show?    = record.creator == user
  def create?  = user.present?
  def update?  = record.creator == user
  def destroy? = record.creator == user

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(creator: user)
    end
  end
end
```

## `app/views/projects/index.html.erb` (abbreviated)

> Plain redirect-driven Turbo flow — step 1 of the response hierarchy, no frames/streams needed, per `rules/controllers.mdc` § Response Hierarchy. No inline policy conditionals: the scope already restricts the list to projects the user may archive — a second check in ERB would duplicate the policy, per `rules/policies.mdc` § Anti-Patterns.

```erb
<h1>Projects</h1>
<%= link_to "Archived", archived_projects_path %>

<ul>
  <% @projects.each do |project| %>
    <li>
      <%= link_to project.name, project %>
      <%= button_to "Archive", project_archival_path(project), method: :post %>
    </li>
  <% end %>
</ul>
```

## `app/views/archived_projects/index.html.erb` (abbreviated)

```erb
<h1>Archived projects</h1>
<%= link_to "Projects", projects_path %>

<ul>
  <% @projects.each do |project| %>
    <li>
      <%= project.name %> —
      archived <%= l project.archival.created_at, format: :long %>
      by <%= project.archival.archiver.name %>
      <%= button_to "Restore", project_archival_path(project), method: :delete %>
    </li>
  <% end %>
</ul>
```

---

# Tests

Layer plan per `rules/testing.mdc` § Each Behaviour Has One Home: domain logic in the **model spec**; the role matrix in the **policy spec**; HTTP/auth gates and rendering smoke in **request specs**; exactly **one system spec** for the cross-resource journey (archive → archived page → restore) — within the budget of 1 per journey.

## `spec/factories/projects.rb`

> Trait passes the actor explicitly — factories run outside a request so `Current.user` is nil, per `rules/testing.mdc` § FactoryBot.

```ruby
FactoryBot.define do
  factory :project do
    name { "Sample Project" }
    association :creator, factory: :user

    trait :archived do
      after(:create) { |project| project.archive(by: project.creator) }
    end
  end
end
```

## `spec/models/project_spec.rb`

> One test per behaviour with multiple assertions on the same action; inline setup, role names not ordinals, per `rules/testing.mdc` and `rules/naming.mdc` § Tests.

```ruby
require "rails_helper"

RSpec.describe Project, type: :model do
  describe "#archive" do
    it "archives the project and records who archived it and when" do
      owner = create(:user)
      project = create(:project, creator: owner)

      project.archive(by: owner)

      expect(project).to be_archived
      expect(project.archival.archiver).to eq(owner)
      expect(project.archival.created_at).to be_present
    end
  end

  describe "#unarchive" do
    it "restores the project to the active set" do
      project = create(:project, :archived)

      project.unarchive

      expect(Project.active).to include(project)
      expect(project.reload).not_to be_archived
    end
  end

  describe ".active / .archived" do
    it "partitions projects by their archival" do
      active_project = create(:project)
      archived_project = create(:project, :archived)

      expect(Project.active).to eq([ active_project ])
      expect(Project.archived).to eq([ archived_project ])
    end
  end
end
```

## `spec/policies/projects/archival_policy_spec.rb`

> Policy spec owns the full role × action matrix, per `rules/testing.mdc` § Ownership by Layer.

```ruby
require "rails_helper"

RSpec.describe Projects::ArchivalPolicy, type: :policy do
  describe "#create? and #destroy?" do
    context "when the user is the project's creator" do
      it "permits archiving and restoring" do
        owner = create(:user)
        project = create(:project, creator: owner)
        policy = described_class.new(owner, project)

        expect(policy.create?).to be true
        expect(policy.destroy?).to be true
      end
    end

    context "when the user is not the project's creator" do
      it "denies archiving and restoring" do
        other_user = create(:user)
        project = create(:project)
        policy = described_class.new(other_user, project)

        expect(policy.create?).to be false
        expect(policy.destroy?).to be false
      end
    end
  end
end
```

## `spec/requests/projects/archivals_spec.rb`

> Request specs own HTTP gates and redirect chains — auth gates always live here even though a system spec exists; they do not re-test the domain logic the model spec owns, per `rules/testing.mdc` § Ownership by Layer.

```ruby
require "rails_helper"

RSpec.describe "Projects::Archivals", type: :request do
  describe "POST /projects/:project_id/archival" do
    context "when signed in as the project's creator" do
      it "redirects to the projects list" do
        owner = create(:user)
        project = create(:project, creator: owner)
        sign_in owner

        post project_archival_path(project)

        expect(response).to redirect_to(projects_path)
      end
    end

    context "when signed in as another user" do
      it "denies the request and leaves the project active" do
        intruder = create(:user)
        project = create(:project)
        sign_in intruder

        post project_archival_path(project)

        expect(response).to redirect_to(root_path)
        expect(project.reload).not_to be_archived
      end
    end

    context "when signed out" do
      it "redirects to sign-in" do
        project = create(:project)

        post project_archival_path(project)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "DELETE /projects/:project_id/archival" do
    context "when signed in as the project's creator" do
      it "redirects to the archived projects page" do
        owner = create(:user)
        project = create(:project, :archived, creator: owner)
        sign_in owner

        delete project_archival_path(project)

        expect(response).to redirect_to(archived_projects_path)
      end
    end

    context "when signed out" do
      it "redirects to sign-in" do
        project = create(:project, :archived)

        delete project_archival_path(project)

        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
```

## `spec/requests/archived_projects_spec.rb`

> Rendering smoke via `response.body.include?` belongs at the request layer, not a `visit`-only system spec; the "doesn't show others' projects" check is paired with a positive assertion, per `rules/testing.mdc` § What NOT to Do.

```ruby
require "rails_helper"

RSpec.describe "ArchivedProjects", type: :request do
  describe "GET /archived_projects" do
    context "when signed in" do
      it "shows the user's archived projects with archival details, scoped to the user" do
        owner = create(:user)
        archived_project = create(:project, :archived, name: "Apollo", creator: owner)
        create(:project, :archived, name: "Someone Elses")
        sign_in owner

        get archived_projects_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Apollo")
        expect(response.body).to include(archived_project.archival.archiver.name)
        expect(response.body).not_to include("Someone Elses")
      end
    end

    context "when signed out" do
      it "redirects to sign-in" do
        get archived_projects_path

        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
```

## `spec/system/archiving_projects_spec.rb`

> One canonical cross-resource journey — exactly the system-spec budget (`rules/testing.mdc` § System-Spec Budget). Passes the interaction gate (clicks), needs no JS (`rack_test`), asserts what the user sees; page state is the primary signal, flash secondary.

```ruby
require "rails_helper"

RSpec.describe "Archiving projects", type: :system do
  it "user archives a project and restores it from the archived page" do
    owner = create(:user)
    create(:project, name: "Apollo", creator: owner)
    sign_in owner

    visit projects_path
    click_button "Archive"

    expect(page).to have_content("Project archived.")
    expect(page).not_to have_content("Apollo")

    click_link "Archived"

    expect(page).to have_content("Apollo")
    expect(page).to have_content("archived")

    click_button "Restore"

    expect(page).to have_content("Project restored.")
    expect(page).to have_content("Apollo")
  end
end
```

---

## Summary of rule-driven decisions

| Decision | Rule |
|---|---|
| `Archival` child record instead of `archived` boolean + `archived_at`/`archived_by` columns | `rules/models.mdc` § State as Records (timestamp + actor requirement is the explicit trigger) |
| `created_at` on the archival is the archived time — no extra column | `rules/models.mdc` § Rich Domain Models ("no duplicate column") |
| `POST`/`DELETE` on `resource :archival` instead of `post :archive` member routes | `rules/controllers.mdc` § Everything Maps to CRUD; `rules/routes.mdc` |
| Archived page = `resources :archived_projects, only: :index`, a new noun resource | `rules/routes.mdc` § Member vs Collection |
| No `ArchiveProjectService` — two one-line domain verbs on `Project` | `rules/services.mdc` § There Is No Service Layer |
| `Projects::ArchivalPolicy` with `create?`/`destroy?` only (no `archive?`) | `rules/naming.mdc` § Policies; `rules/policies.mdc` § Anti-Patterns |
| Unique index + NOT NULL + FKs in the migration as the integrity source of truth | `rules/migrations.mdc`; `rules/models.mdc` § Database Constraints Over Validations |
| Test layering: model owns logic, policy owns matrix, request owns gates/smoke, one system journey | `rules/testing.mdc` § Each Behaviour Has One Home / § System-Spec Budget |
