# Receipt 1a — Baseline generation (no rules loaded)

**How this was produced.** Claude (claude-sonnet class model, fresh context) was given the
feature request below with **no plugin rules, no skills, no custom instructions**, and told to
make its normal choices for a Rails 8 + RSpec + Pundit + Hotwire app. The output is unedited.
The same prompt with the plugin rules loaded is in
[`02-after-with-rules.md`](02-after-with-rules.md); the reviewer agent's report on *this*
implementation is in [`03-review-catch.md`](03-review-catch.md).

**The prompt:**

> Users need to be able to archive and unarchive a project. Archived projects should be hidden
> from the main projects list, and there should be an 'Archived' page where users can see their
> archived projects and restore them. We need to know when a project was archived and who
> archived it.

**Why this baseline matters.** This is not a strawman. The baseline output is *competent,
mainstream Rails* — it even avoids a service object. The point of the comparison is that the
plugin rules encode a specific architectural position that generic "good Rails" does not reach
on its own: state as records instead of nullable timestamp + FK columns, new noun resources
instead of custom member verbs, CRUD-only policies, non-bang domain verbs, `params.expect`.

---

## Baseline output (unedited)

# Archive / Unarchive Projects

Design decisions, briefly: an `archived_at` timestamp (rather than a boolean) gives us "when" for free, and an `archived_by` FK to `users` gives us "who". Archiving is a state change, not a destroy, so it gets its own member actions rather than overloading `update`. The archived list is a collection action. I'm assuming `Project belongs_to :user` (owner) and Devise for auth — adjust the `sign_in` helpers if you use something else.

## db/migrate/20260731000000_add_archival_to_projects.rb

```ruby
class AddArchivalToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :archived_at, :datetime
    add_reference :projects, :archived_by, foreign_key: { to_table: :users }, index: true

    add_index :projects, :archived_at
  end
end
```

## app/models/project.rb

```ruby
class Project < ApplicationRecord
  belongs_to :user
  belongs_to :archived_by, class_name: "User", optional: true

  scope :active,   -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  validates :name, presence: true

  def archived?
    archived_at.present?
  end

  def archive!(archiver)
    update!(archived_at: Time.current, archived_by: archiver)
  end

  def unarchive!
    update!(archived_at: nil, archived_by: nil)
  end
end
```

## config/routes.rb (relevant portion)

```ruby
Rails.application.routes.draw do
  resources :projects do
    member do
      patch :archive
      patch :unarchive
    end
    collection do
      get :archived
    end
  end
end
```

## app/controllers/projects_controller.rb

```ruby
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: %i[show edit update destroy archive unarchive]

  def index
    @projects = policy_scope(Project).active.order(created_at: :desc)
  end

  def archived
    authorize Project, :index?
    @projects = policy_scope(Project).archived.order(archived_at: :desc)
  end

  def show
  end

  def archive
    authorize @project

    @project.archive!(current_user)
    redirect_to projects_path, notice: "#{@project.name} has been archived."
  end

  def unarchive
    authorize @project

    @project.unarchive!
    redirect_to archived_projects_path, notice: "#{@project.name} has been restored."
  end

  # ... existing new/create/edit/update/destroy actions unchanged ...

  private

  def set_project
    @project = Project.find(params[:id])
    authorize @project
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
```

Note: `archived_at`/`archived_by` are deliberately **not** in `project_params` — archival state can only change through the dedicated actions, so it can't be mass-assigned around authorization.

## app/policies/project_policy.rb

```ruby
class ProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  def index?
    user.present?
  end

  def show?
    owner?
  end

  def create?
    user.present?
  end

  def update?
    owner? && !record.archived?
  end

  def destroy?
    owner?
  end

  def archive?
    owner? && !record.archived?
  end

  def unarchive?
    owner? && record.archived?
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
```

Two policy choices worth calling out: archiving an already-archived project (and vice versa) is forbidden rather than a silent no-op, and `update?` is disabled while archived so archived projects are read-only until restored. Loosen that if you don't want it.

## app/views/projects/index.html.erb

```erb
<div class="projects-header">
  <h1>Projects</h1>
  <%= link_to "Archived", archived_projects_path %>
  <%= link_to "New project", new_project_path %>
</div>

<div id="projects">
  <% @projects.each do |project| %>
    <div id="<%= dom_id(project) %>" class="project-row">
      <%= link_to project.name, project %>
      <%= button_to "Archive",
            archive_project_path(project),
            method: :patch,
            data: { turbo_confirm: "Archive #{project.name}?" } %>
    </div>
  <% end %>

  <% if @projects.empty? %>
    <p>No projects yet.</p>
  <% end %>
</div>
```

## app/views/projects/archived.html.erb

```erb
<div class="projects-header">
  <h1>Archived projects</h1>
  <%= link_to "Back to projects", projects_path %>
</div>

<div id="archived_projects">
  <% @projects.each do |project| %>
    <div id="<%= dom_id(project) %>" class="project-row">
      <%= link_to project.name, project %>
      <span class="meta">
        Archived <%= l(project.archived_at, format: :long) %>
        by <%= project.archived_by&.name || "unknown" %>
      </span>
      <%= button_to "Restore", unarchive_project_path(project), method: :patch %>
    </div>
  <% end %>

  <% if @projects.empty? %>
    <p>No archived projects.</p>
  <% end %>
</div>
```

The `button_to` forms work with Turbo out of the box (they issue real PATCH requests); the redirect + flash keeps things simple and reliable. If you later want the row to vanish without a full page load, swap the redirect for a `turbo_stream.remove(dom_id(@project))` response.

## spec/factories/projects.rb

```ruby
FactoryBot.define do
  factory :project do
    association :user
    sequence(:name) { |n| "Project #{n}" }

    trait :archived do
      archived_at { 1.day.ago }
      archived_by { user }
    end
  end
end
```

## spec/models/project_spec.rb

```ruby
require "rails_helper"

RSpec.describe Project, type: :model do
  describe "scopes" do
    let!(:active_project)   { create(:project) }
    let!(:archived_project) { create(:project, :archived) }

    it ".active returns only unarchived projects" do
      expect(described_class.active).to contain_exactly(active_project)
    end

    it ".archived returns only archived projects" do
      expect(described_class.archived).to contain_exactly(archived_project)
    end
  end

  describe "#archive!" do
    it "records when and by whom the project was archived" do
      project = create(:project)
      archiver = project.user

      freeze_time do
        project.archive!(archiver)

        expect(project.reload).to be_archived
        expect(project.archived_at).to eq(Time.current)
        expect(project.archived_by).to eq(archiver)
      end
    end
  end

  describe "#unarchive!" do
    it "clears the archival timestamp and archiver" do
      project = create(:project, :archived)

      project.unarchive!

      expect(project.reload).not_to be_archived
      expect(project.archived_at).to be_nil
      expect(project.archived_by).to be_nil
    end
  end
end
```

## spec/policies/project_policy_spec.rb

```ruby
require "rails_helper"

RSpec.describe ProjectPolicy do
  subject(:policy) { described_class.new(user, project) }

  let(:owner)      { create(:user) }
  let(:other_user) { create(:user) }

  describe "#archive?" do
    let(:project) { create(:project, user: owner) }

    context "as the owner" do
      let(:user) { owner }

      it { is_expected.to permit_action(:archive) }

      it "forbids archiving an already archived project" do
        project.update!(archived_at: Time.current, archived_by: owner)
        expect(policy.archive?).to be(false)
      end
    end

    context "as another user" do
      let(:user) { other_user }

      it { is_expected.to forbid_action(:archive) }
    end
  end

  describe "#unarchive?" do
    let(:project) { create(:project, :archived, user: owner) }

    context "as the owner" do
      let(:user) { owner }

      it { is_expected.to permit_action(:unarchive) }
    end

    context "as another user" do
      let(:user) { other_user }

      it { is_expected.to forbid_action(:unarchive) }
    end
  end

  describe described_class::Scope do
    it "only exposes the user's own projects" do
      mine   = create(:project, user: owner)
      _other = create(:project, user: other_user)

      resolved = described_class.new(owner, Project).resolve
      expect(resolved).to contain_exactly(mine)
    end
  end
end
```

(Uses `pundit-matchers`; if you don't have it, replace `permit_action`/`forbid_action` with plain `expect(policy.archive?).to be(true)` assertions.)

## spec/requests/projects/archival_spec.rb

```ruby
require "rails_helper"

RSpec.describe "Project archival", type: :request do
  let(:user)    { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in user }

  describe "PATCH /projects/:id/archive" do
    it "archives the project and records the archiver" do
      patch archive_project_path(project)

      expect(response).to redirect_to(projects_path)
      expect(project.reload).to be_archived
      expect(project.archived_by).to eq(user)
    end

    it "does not allow archiving another user's project" do
      other_project = create(:project)

      patch archive_project_path(other_project)

      expect(other_project.reload).not_to be_archived
      expect(response).to redirect_to(root_path) # or however you handle Pundit::NotAuthorizedError
    end
  end

  describe "PATCH /projects/:id/unarchive" do
    it "restores an archived project" do
      project.archive!(user)

      patch unarchive_project_path(project)

      expect(response).to redirect_to(archived_projects_path)
      expect(project.reload).not_to be_archived
      expect(project.archived_by).to be_nil
    end
  end

  describe "GET /projects" do
    it "hides archived projects" do
      active   = create(:project, user: user, name: "Active one")
      archived = create(:project, :archived, user: user, name: "Archived one")

      get projects_path

      expect(response.body).to include(active.name)
      expect(response.body).not_to include(archived.name)
    end
  end

  describe "GET /projects/archived" do
    it "lists only the user's archived projects" do
      archived      = create(:project, :archived, user: user, name: "Mine archived")
      _active       = create(:project, user: user, name: "Mine active")
      _someone_else = create(:project, :archived, name: "Not mine")

      get archived_projects_path

      expect(response.body).to include("Mine archived")
      expect(response.body).not_to include("Mine active")
      expect(response.body).not_to include("Not mine")
    end
  end
end
```

## Run it

```
bin/rails db:migrate
bundle exec rspec spec/models/project_spec.rb spec/policies/project_policy_spec.rb spec/requests/projects/archival_spec.rb
```

That's the whole feature: timestamp + FK for the audit trail, scopes to partition the lists, dedicated member actions guarded by Pundit, a collection route for the archived page, and coverage at the model, policy, and request levels.
