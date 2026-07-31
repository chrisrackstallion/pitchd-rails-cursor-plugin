# Receipt 3 — Generalisation test: a case the rules never mention

**The question this answers.** Do the rules only make an agent pattern-match the examples
(`publish`/`close`/`archive` appear literally in the rules), or does the agent transfer the
*principles* to a feature the rules never name?

**How this was produced.** Claude (fresh context) read the compass and the applicable
`rules/*.mdc`, then got this feature request. The word "spotlight" appears nowhere in the
plugin. The prompt also asked the model to name which rule drove each structural decision.
Output unedited.

**The prompt:**

> Admins can put one agency 'in the spotlight'. The spotlighted agency appears in a banner on
> the marketplace home page. Only one agency can be in the spotlight at a time — spotlighting a
> new agency replaces the current one. Admins can also clear the spotlight entirely. We want to
> know when the spotlight was set and by which admin.

**What generalised (none of these are literal examples in the rules):**

1. **State-as-records transferred**: a `Spotlight` child record whose existence is the state,
   `created_at` as the spotlighted-at time, `creator` FK for attribution — triggered by the
   rule's *principle* ("timestamp, actor, or joins → state record"), not by a matching example.
2. **The novel constraint got a novel-but-principled solution**: "only one at a time" is not
   covered by any rule. The agent put replacement in a model domain verb (`Spotlight#feature`)
   wrapped in a transaction, then **backstopped it with a Postgres unique expression index on a
   constant** so the database — not just Ruby — guarantees at-most-one-row, citing
   `models.mdc` § Database Constraints Over Validations. That is principle application, not
   pattern matching.
3. **REST shape derived, not copied**: it reasoned that a single global spotlight is a *true
   singleton* → `resource :spotlight` under `namespace :admin`, where "replace" is just
   `create` again and "clear" is `destroy`. The rules' examples are all nested per-record
   resources; the singleton move required combining two rules (`routes.mdc` singleton
   guidance + `controllers.mdc` CRUD mapping).
4. **Policy shape held**: `SpotlightPolicy#create?/#destroy?` — it did not invent `spotlight?`
   or `clear?` verbs even though the feature language ("spotlight", "clear") invites them.
5. **Public-page authorization edge handled**: the marketplace home is public, so it used
   `allow_unauthenticated_access` + explicit `skip_after_action :verify_authorized` — the
   documented escape hatch, not a silent hole.
6. **Test budget held under temptation**: replacement, clearing, and authorization all stayed
   in model/policy/request specs; exactly one system journey (set → see banner), with the
   explicit note that "the default answer to more system specs is no."

**Honest caveats:** single run, not a benchmark; the model was asked to cite rules, which
encourages compliance (that's the point of the pipeline — the same instruction lives in the
implementor skill); `add_index :spotlights, "((true))"` is clever enough that a human reviewer
should still look at it — which is what the reviewer pass is for.

---

## Rules-loaded output (unedited)

I'm using the rails-omakase-compass skill for solution shape. All rules read; here is the full implementation.

## Structural decisions (rule → choice)

1. **How state is modelled** — a `Spotlight` state record, not an `agencies.spotlighted` boolean or `spotlighted_at` column: `models.mdc` § *State as Records, Not Booleans* — we need a timestamp **and** an actor ("when, by which admin"), which is exactly the "state record" rung of the ladder; the row's existence *is* the state, `created_at` *is* the spotlighted-at time (no duplicate column, per the Publication example), and destroying the row *is* the revert.
2. **Where "only one at a time" lives** — a domain verb (`Spotlight#feature`) wrapping replace+save in a transaction on the model (`models.mdc` *Rich Domain Models*, `services.mdc` *There Is No Service Layer* — no `SpotlightService`), backstopped by a **unique index on a constant expression** so the database, not just Ruby, guarantees at most one row (`models.mdc` § *Database Constraints Over Validations*).
3. **Routes/controller shape** — spotlighting is not a custom `post :spotlight` verb on agencies; it is CRUD on a new noun: a **true singleton** `resource :spotlight` under `namespace :admin` — set = `create`, replace = `create` again, clear = `destroy` (`controllers.mdc` § *Everything Maps to CRUD*, `routes.mdc` singleton-resource default, `naming.mdc` plural controller for singular resource).
4. **Policy shape** — one `SpotlightPolicy` mirroring CRUD actions only (`create?`/`destroy?`, never `spotlight?`/`clear?`): `policies.mdc` + `naming.mdc` "state changes map to `create?`/`destroy?` on a noun-resource policy". Admin-ness is checked in the policy, never inline in the controller or router (`routes.mdc` — no authorization in constraints).
5. **Attribution** — `belongs_to :creator, default: -> { Current.user }` so the server owns who set it (`models.mdc` § *Association Defaults with Current*; compass § *Server owns truth* — the actor never comes from params).
6. **Test layering** — replacement logic in the model spec, role matrix in the policy spec, HTTP gates + non-canonical CRUD + rendering smoke in request specs, exactly **one** canonical system journey (`testing.mdc` pyramid, budget, and "each behaviour has one home").

---

### `db/migrate/20260731120000_create_spotlights.rb`

```ruby
class CreateSpotlights < ActiveRecord::Migration[8.0]
  def change
    create_table :spotlights do |t|
      t.references :agency,  null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Only one agency can be in the spotlight at a time: a unique index on a
    # constant expression allows at most one row in the table. The model's
    # #feature verb replaces inside a transaction; this is the DB backstop.
    add_index :spotlights, "((true))", unique: true, name: "index_spotlights_singleton"
  end
end
```

*Note:* semantic FK `creator_id` (not `user_id`) because the role differs from the class — `naming.mdc` § Database. Integrity (`null: false`, FKs, singleton index) at the DB level — `models.mdc` § Database Constraints Over Validations.

---

### `app/models/spotlight.rb`

```ruby
class Spotlight < ApplicationRecord
  belongs_to :agency
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  # The singleton index guarantees at most one row, so `first` is the spotlight.
  def self.current
    first
  end

  # Puts this spotlight's agency in the spotlight, replacing whichever agency
  # currently holds it. created_at is the "spotlighted at" time — no extra column.
  def feature
    return false if invalid?

    transaction do
      self.class.current&.destroy!
      save!
    end
  end
end
```

*Note:* `feature` is an imperative, non-bang domain verb (not `set_spotlight`/`save_spotlight`) with the bang on the internal AR calls — `naming.mdc` § Domain Layer, `models.mdc` § Bang Convention; the transaction wraps the two writes per the `publish` example.

### `app/models/agency.rb` (additions)

```ruby
class Agency < ApplicationRecord
  # ... existing associations ...
  has_one :spotlight, dependent: :destroy

  # ... existing scopes ...
  scope :alphabetically, -> { order(:name) }   # add if not already present

  def spotlighted?
    spotlight.present?
  end
end
```

*Note:* predicate `spotlighted?` (present tense + `?`, no `is_` prefix) reads the record's existence — `models.mdc` `closed?` pattern.

---

### `config/routes.rb` (additions)

```ruby
Rails.application.routes.draw do
  # ... existing routes (root "home#show", resources :agencies, ...) ...

  namespace :admin do
    # True singleton — only one spotlight exists at a time.
    resource :spotlight, only: %i[ new create destroy ]
  end
end
```

*Note:* `resource` (singular) for a true singleton, with `only:` so dead actions don't exist in the routing table — `routes.mdc` § Defaults; no `post "agencies/:id/spotlight"` RPC verb — `routes.mdc` § REST Is the Default Vocabulary.

---

### `app/controllers/admin/spotlights_controller.rb`

```ruby
class Admin::SpotlightsController < ApplicationController
  def new
    @spotlight = Spotlight.new
    authorize @spotlight

    @current_spotlight = Spotlight.current
    @agencies = Agency.alphabetically
  end

  def create
    @spotlight = Spotlight.new(spotlight_params)
    authorize @spotlight

    if @spotlight.feature
      redirect_to new_admin_spotlight_path, notice: "#{@spotlight.agency.name} is now in the spotlight."
    else
      @current_spotlight = Spotlight.current
      @agencies = Agency.alphabetically
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @spotlight = Spotlight.sole
    authorize @spotlight

    @spotlight.destroy!
    redirect_to new_admin_spotlight_path, notice: "Spotlight cleared."
  end

  private
    def spotlight_params
      params.expect(spotlight: %i[ agency_id ])
    end
end
```

*Notes:* thin controller — replacement logic lives in the model verb, the controller only builds/authorizes/responds (`controllers.mdc` § Thin Controllers). `creator` is never permitted from params — it defaults from `Current.user` (compass § Server owns truth). `params.expect` per Rails 8 convention. `Spotlight.sole` gives an honest 404 when clearing a non-existent spotlight. No `before_action` admin check — `authorize` in every action is the single gate (`policies.mdc` anti-patterns). Plural `SpotlightsController` for `resource :spotlight` — `naming.mdc`. Failed save renders 422, never redirects — `controllers.mdc` § Response Hierarchy.

### `app/controllers/home_controller.rb` (marketplace home — additions to existing controller)

```ruby
class HomeController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized   # public page — intentionally unauthorized

  def show
    # ... existing marketplace home assigns ...
    @spotlight = Spotlight.includes(:agency).current
  end
end
```

*Note:* the banner is server-rendered HTML on the existing page — no JSON endpoint, no client state (compass §§ HTML as primary interface, Server owns truth); `skip_after_action` is the explicit opt-out `policies.mdc` requires for public pages.

---

### `app/views/admin/spotlights/new.html.erb` (abbreviated)

```erb
<h1>Marketplace spotlight</h1>

<% if @current_spotlight %>
  <div class="spotlight-current">
    <p>
      <strong><%= @current_spotlight.agency.name %></strong> is in the spotlight —
      set by <%= @current_spotlight.creator.name %>,
      <%= time_ago_in_words(@current_spotlight.created_at) %> ago.
    </p>
    <%= button_to "Clear spotlight", admin_spotlight_path, method: :delete %>
  </div>
<% end %>

<%= form_with model: @spotlight, url: admin_spotlight_path do |form| %>
  <% if @spotlight.errors.any? %>
    <div class="form-errors"><%= @spotlight.errors.full_messages.to_sentence %></div>
  <% end %>

  <%= form.label :agency_id, "Agency" %>
  <%= form.collection_select :agency_id, @agencies, :id, :name, prompt: "Choose an agency" %>

  <%= form.submit @current_spotlight ? "Replace spotlight" : "Put in the spotlight" %>
<% end %>
```

*Note:* plain form + `button_to` — full-page redirect flow, step 1 of the response hierarchy; no Turbo Streams needed (`controllers.mdc` § Response Hierarchy, compass § Progressive enhancement).

### `app/views/home/show.html.erb` (addition, abbreviated)

```erb
<%# ... existing marketplace home ... %>
<%= render "spotlight_banner", spotlight: @spotlight if @spotlight %>
```

### `app/views/home/_spotlight_banner.html.erb` (abbreviated)

```erb
<section class="spotlight-banner">
  <h2>In the spotlight</h2>
  <p><%= link_to spotlight.agency.name, agency_path(spotlight.agency) %></p>
</section>
```

*Note:* partial named for its noun with a singular domain-noun local (`spotlight`, not `item`) — `naming.mdc` § Views and Partials.

---

### `app/policies/spotlight_policy.rb`

```ruby
class SpotlightPolicy < ApplicationPolicy
  def create?
    admin?
  end

  def destroy?
    admin?
  end

  private
    def admin?
      user.present? && user.admin?
    end
end
```

*Notes:* CRUD methods only — spotlighting is `create?`, clearing is `destroy?`, never a custom `spotlight?`/`clear?` verb (`naming.mdc` § Policies, `policies.mdc` anti-patterns). `new?` falls through to `create?` via `ApplicationPolicy`; everything else stays denied by the base class defaults. The policy composes a role check and holds no business rules.

---

## Tests (layers per `testing.mdc`)

### `spec/factories/spotlights.rb`

```ruby
FactoryBot.define do
  factory :spotlight do
    association :agency
    # Pass the actor explicitly — factories run outside a request,
    # so the `default: -> { Current.user }` would get nil.
    association :creator, factory: %i[ user admin ]
  end
end
```

*(Assumes existing `:agency` factory and a `:user` factory with an `:admin` trait.)*

### `spec/models/spotlight_spec.rb` — domain logic's one home

```ruby
require "rails_helper"

RSpec.describe Spotlight, type: :model do
  describe "#feature" do
    it "puts the agency in the spotlight and records who set it" do
      admin = create(:user, :admin)
      agency = create(:agency)

      spotlight = Spotlight.new(agency: agency, creator: admin)

      expect(spotlight.feature).to be_truthy
      expect(Spotlight.current.agency).to eq(agency)
      expect(Spotlight.current.creator).to eq(admin)
      expect(agency.reload).to be_spotlighted
    end

    context "when another agency is already in the spotlight" do
      it "replaces the current spotlight" do
        create(:spotlight)
        new_agency = create(:agency, name: "Bright Ideas")

        Spotlight.new(agency: new_agency, creator: create(:user, :admin)).feature

        expect(Spotlight.count).to eq(1)
        expect(Spotlight.current.agency).to eq(new_agency)
      end
    end

    context "with no agency chosen" do
      it "returns false and leaves the spotlight untouched" do
        existing = create(:spotlight)

        result = Spotlight.new(agency: nil, creator: create(:user, :admin)).feature

        expect(result).to be(false)
        expect(Spotlight.current).to eq(existing)
      end
    end
  end

  describe ".current" do
    it "returns the one spotlight, or nil when the spotlight is clear" do
      expect(Spotlight.current).to be_nil

      spotlight = create(:spotlight)
      expect(Spotlight.current).to eq(spotlight)
    end
  end

  it "refuses a second spotlight row at the database level" do
    create(:spotlight)

    expect { create(:spotlight) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
```

*Note:* one test per behaviour with multiple assertions about the same action (set + attribution together), not one test per assertion — `testing.mdc` § Within a Single Spec File. The DB-constraint test proves *our* singleton index, not framework behaviour.

### `spec/policies/spotlight_policy_spec.rb` — the role × action matrix

```ruby
require "rails_helper"

RSpec.describe SpotlightPolicy, type: :policy do
  context "when the user is an admin" do
    it "permits setting and clearing the spotlight" do
      policy = described_class.new(build(:user, :admin), Spotlight.new)

      expect(policy.new?).to be true
      expect(policy.create?).to be true
      expect(policy.destroy?).to be true
    end
  end

  context "when the user is not an admin" do
    it "denies setting and clearing the spotlight" do
      policy = described_class.new(build(:user), Spotlight.new)

      expect(policy.new?).to be false
      expect(policy.create?).to be false
      expect(policy.destroy?).to be false
    end
  end

  context "with no user" do
    it "denies everything" do
      policy = described_class.new(nil, Spotlight.new)

      expect(policy.create?).to be false
      expect(policy.destroy?).to be false
    end
  end
end
```

### `spec/requests/admin/spotlights_spec.rb` — HTTP gates + non-canonical CRUD

```ruby
require "rails_helper"

RSpec.describe "Admin::Spotlights", type: :request do
  # Assumes the suite's request-spec auth helper, e.g. `sign_in(user)`.

  describe "authorization gates" do
    it "redirects a non-admin away from the spotlight form" do
      sign_in create(:user)

      get new_admin_spotlight_path

      expect(response).to redirect_to(root_path)
    end

    it "redirects a non-admin trying to set the spotlight" do
      agency = create(:agency)
      sign_in create(:user)

      post admin_spotlight_path, params: { spotlight: { agency_id: agency.id } }

      expect(response).to redirect_to(root_path)
      expect(Spotlight.current).to be_nil
    end

    it "redirects a non-admin trying to clear the spotlight" do
      create(:spotlight)
      sign_in create(:user)

      delete admin_spotlight_path

      expect(response).to redirect_to(root_path)
      expect(Spotlight.current).to be_present
    end
  end

  describe "GET /admin/spotlight/new" do
    it "shows the current spotlight to an admin" do
      create(:spotlight, agency: create(:agency, name: "Acme Talent"))
      sign_in create(:user, :admin)

      get new_admin_spotlight_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acme Talent")
    end
  end

  describe "POST /admin/spotlight" do
    context "with no agency chosen" do
      it "re-renders the form as unprocessable" do
        sign_in create(:user, :admin)

        post admin_spotlight_path, params: { spotlight: { agency_id: "" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/spotlight" do
    it "clears the spotlight and returns to the form" do
      create(:spotlight)
      sign_in create(:user, :admin)

      delete admin_spotlight_path

      expect(response).to redirect_to(new_admin_spotlight_path)
      expect(Spotlight.current).to be_nil
    end

    it "404s when there is no spotlight to clear" do
      sign_in create(:user, :admin)

      delete admin_spotlight_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
```

*Note:* auth gates are always tested at the HTTP layer even though a system spec exists; the canonical create happy path is **not** repeated here (it belongs to the system spec), while `destroy` and the 422 path live here as non-canonical CRUD — `testing.mdc` § Ownership by Layer.

### `spec/requests/home_spec.rb` — rendering smoke for the banner (addition)

```ruby
require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "shows the spotlighted agency in the banner" do
      create(:spotlight, agency: create(:agency, name: "Acme Talent"))

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("In the spotlight")
      expect(response.body).to include("Acme Talent")
    end
  end
end
```

*Note:* `visit`-and-assert with no interaction is a request spec with `response.body.include?`, not a system spec — `testing.mdc` interaction gate.

### `spec/system/spotlight_spec.rb` — the one canonical journey

```ruby
require "rails_helper"

RSpec.describe "Spotlight", type: :system do
  it "admin puts an agency in the spotlight and it appears on the marketplace home" do
    create(:agency, name: "Acme Talent")
    sign_in create(:user, :admin)

    visit new_admin_spotlight_path
    select "Acme Talent", from: "Agency"
    click_button "Put in the spotlight"

    expect(page).to have_content("Acme Talent is in the spotlight")

    visit root_path
    expect(page).to have_content("In the spotlight")
    expect(page).to have_content("Acme Talent")
  end
end
```

*Note:* exactly one system spec, within budget — one happy path telling one story (set → see it live), interacting with the form, running under `rack_test` (no JS required). Replacement, clearing, and authorization are already owned by lower layers — the default answer to more system specs is no (`testing.mdc` § System-Spec Budget, Five Gates).

---

## Documented exceptions / assumptions (compass § 9)

- `add_index :spotlights, "((true))"` is the one non-obvious line in the migration — a unique expression index over a constant is the standard Postgres idiom for "at most one row"; the comment in the migration carries the why.
- Assumes the app's existing `Current.user`, `User#admin?`, `HomeController#show` as marketplace home (`root "home#show"`), an `:agency` factory, a `:user` factory with an `:admin` trait, and a `sign_in` spec helper — rename to match the app's actual equivalents.
- No `app/services/` entry, no state-machine gem, no JSON endpoint, no Turbo Streams: the defaults solved it, so no layer was added (compass § Omakase first).
