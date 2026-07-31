# Receipt 2 — The review agent catching violations

**How this was produced.** The `pitchd-rails-reviewer` agent (following
[`agents/pitchd-rails-reviewer.md`](../../agents/pitchd-rails-reviewer.md) and
[`skills/reviewing-pitchd-rails/SKILL.md`](../../skills/reviewing-pitchd-rails/SKILL.md)) was
given the baseline implementation from [`01-before-no-rules.md`](01-before-no-rules.md) as an
implementation-phase review — Phase: `implementation`, Plan: `none`, greenfield scope. The
report below is unedited.

**What it demonstrates.** This is the loop's second half: even when a generation misses the
conventions, the violations don't survive review. Note three properties of the report:

1. **Findings cite the rule, not vibes** — every violation names the exact rule file and
   section it breaks, because the reviewer is required to *re-read the rule* before asserting
   a violation ("Confirm the rule or skill you're citing actually prohibits the pattern").
2. **Findings carry confidence scores and Verified notes** — the reviewer must state what it
   opened and read to confirm each finding, and drop anything it can't verify. This is the
   anti-hallucination mechanism, visible in the output.
3. **It caught things beyond the headline violations** — the missing `authorize` on `index`,
   the double authorization gate (`authorize` in both the `before_action` finder and the action
   body), a request spec re-asserting behaviour the model spec owns, and a spec pinned to
   unverified redirect behaviour.

**The corrected shape** for this same feature — state record, noun resource, CRUD-only policy —
is what the rules-loaded generation produced in [`02-after-with-rules.md`](02-after-with-rules.md).
In the execution pipeline (`executing-pitchd-rails-plan`), this report would go back to the
implementor as a fix pass and the reviewer would re-review the changed areas until
`Status: Approved`.

**Honest caveats:** this baseline came from a rules-free generation, staged to demonstrate the
catch (in day-to-day use the implementor has the rules loaded, so reviews catch subtler drift
— wrong test layer, a sneaky custom route, a policy check duplicated in a view). Single run,
model-graded; the confidence scores are the reviewer's own.

---

## Reviewer report (unedited)

All rules and skills loaded, implementation read in full. Here is the report.

## Pitchd Rails review

**Phase covered:** implementation

**Status:** Issues found

### philosophy: (rails-omakase-compass)

- [confidence: 0.9] `config/routes.rb` / `app/controllers/projects_controller.rb`: The solution drifts from REST gravity into RPC. `patch :archive`, `patch :unarchive`, and `get :archived` are verb/adjective actions bolted onto the projects resource instead of noun resources with CRUD. The compass is explicit: "Model URLs and controllers around resources and conventional verbs. RPC shapes are exceptions — name the exception." No exception is named; the accompanying prose even presents member actions as the deliberate choice.
  **Verified:** Read `docs/receipts/01-before-no-rules.md` lines 72–83 (routes block with `member do patch :archive / patch :unarchive end` and `collection do get :archived end`) and lines 105–117 (controller actions); read `skills/rails-omakase-compass/SKILL.md` §4 RESTful gravity.

- [confidence: 0.85] Overall shape is otherwise on-compass: HTML-first with `button_to` + redirect + flash, server owns truth, no service object, one monolith, Turbo escalation explicitly deferred (line 236). The drift is concentrated in the resource modeling, not the interface choice.
  **Verified:** Read the full receipt (lines 27–441); no `app/services/`, no JSON surface, no client-side state.

### tactical: (writing-* / rules)

- [confidence: 0.95] `db/migrate/20260731000000_add_archival_to_projects.rb` + `app/models/project.rb`: Archival state is modeled as a nullable `archived_at` timestamp + `archived_by` FK on `projects`. This violates `rules/models.mdc` § State as Records: when you need **timestamps and actor** — which is the literal spec ("when a project was archived and who archived it") — the rule mandates a state record (`has_one :archival`, existence of the row *is* the state, `destroy` is the revert). The writing-models patterns table says it twice: "Need to know *who* made the change → State record. Need to know *when* it happened → State record." The correct shape is a `project_archivals` (or `archivals`) table with `creator` `null: false`, `archived?` = `archival.present?`, and the two nullable columns disappear — along with the `unarchive!` clearing dance and the view's `archived_by&.name || "unknown"` nil guard.
  **Verified:** Read receipt lines 33–41 (migration adding both columns) and 47–67 (model with nullable-column scopes and clearing in `unarchive!`); read `rules/models.mdc` § State as Records and `skills/writing-models/references/patterns.md` § State as Records (lines 64–151, including the When to Use table).

- [confidence: 0.95] `config/routes.rb`: `member { patch :archive; patch :unarchive }` violates `rules/routes.mdc` ("Bad — RPC verbs where a resource or model method belongs") and `rules/controllers.mdc` § Everything Maps to CRUD, whose "Bad" example is exactly this diff (`member do post :archive end`). The correct route is `resources :projects do scope module: :projects { resource :archival } end` — archive is `Projects::ArchivalsController#create`, unarchive is `#destroy`. `get :archived` on the collection is likewise a non-REST action name (`rules/naming.mdc`: "Action names — Seven standard REST actions only"); the archived page is an `index` on its own noun resource, not an eighth action on `ProjectsController`.
  **Verified:** Read receipt lines 72–83; read `rules/routes.mdc` § REST Is the Default Vocabulary and anti-patterns table; `rules/controllers.mdc` § Everything Maps to CRUD; `rules/naming.mdc` § Controllers.

- [confidence: 0.95] `app/models/project.rb`: `archive!(archiver)` and `unarchive!` violate the Bang Convention in `rules/models.mdc`: "Domain verbs use the non-bang form (`publish`, `close`) … Reserve a bang domain verb only when you offer both a 'try' form and a 'must succeed' form." No non-bang forms exist. Also prefer the keyword-argument shape from the rule: `archive(by: Current.user)`, not a positional `archiver`.
  **Verified:** Read receipt lines 60–66; read `rules/models.mdc` § Bang Convention and `rules/naming.mdc` ("Bang domain verb — only when a 'try' form also exists").

- [confidence: 0.95] `app/policies/project_policy.rb`: `archive?` and `unarchive?` are custom verb policy methods. `rules/policies.mdc` anti-patterns table: "Custom verb methods (`close?`, `publish?`) → CRUD only — state changes map to `create?`/`destroy?` on a noun-resource policy." With the archival resource this becomes `Projects::ArchivalPolicy#create?` / `#destroy?` (`rules/naming.mdc` § Policies). The already-archived guard then falls out naturally — a unique index on the archival row makes double-archive impossible at the database, where `rules/models.mdc` says integrity belongs.
  **Verified:** Read receipt lines 166–172; read `rules/policies.mdc` anti-patterns table and `rules/naming.mdc` § Policies ("State-change policy — Noun-resource namespace").

- [confidence: 1.0] `app/controllers/projects_controller.rb`: `params.require(:project).permit(:name, :description)` violates `rules/controllers.mdc` § Strong Parameters: "Prefer `params.expect` over `params.require(...).permit(...)` — it is the Rails 8+ convention." Should be `params.expect(project: %i[ name description ])`.
  **Verified:** Read receipt lines 128–130; read `rules/controllers.mdc` § Strong Parameters and the anti-patterns row.

- [confidence: 0.95] `app/controllers/projects_controller.rb`: `index` never calls `authorize`. `rules/controllers.mdc` § Authorization with Pundit: "Call `authorize` in every action — including `index`." The `archived` action does it (`authorize Project, :index?`, itself a smell — borrowing another action's policy method); `index` does not.
  **Verified:** Read receipt lines 93–95 (index body: `policy_scope` + order only) against lines 97–99; read `rules/controllers.mdc` § Authorization with Pundit.

- [confidence: 0.9] `app/controllers/projects_controller.rb`: `set_project` calls `authorize @project` inside a `before_action`, and `archive`/`unarchive` then call `authorize @project` again in the body — two gates for one decision. `rules/controllers.mdc` anti-patterns: "Pundit policy checks in `before_action` → `authorize` in the action body — keep `before_action` for authentication and finders" and "One gate: the policy is the single home for the logic." Move `authorize` out of the finder; each action authorizes once, in its body.
  **Verified:** Read receipt lines 91, 105–107, 112–114, 123–126; read `rules/controllers.mdc` anti-patterns table and `rules/policies.mdc` anti-patterns table (same row).

- [confidence: 0.8] `app/controllers/projects_controller.rb`: `.order(created_at: :desc)` and `.order(archived_at: :desc)` inline in actions violate `rules/models.mdc` § Scopes: "Push domain queries to named scopes. Controllers should read like prose, not SQL." Name them (`latest_first`, or `reverse_chronologically`).
  **Verified:** Read receipt lines 94 and 99; read `rules/models.mdc` § Scopes.

- [confidence: 0.8] `app/views/projects/index.html.erb` + `archived.html.erb`: Both templates hand-roll `@projects.each` loops with duplicated row markup instead of extracting a `_project` partial with strict locals and using `render @projects` (or `render(@projects) || tag.p(...)` for the empty state). `rules/views.mdc` § Collection Rendering and § Partials with Strict Locals; the anti-patterns table flags repeated hardcoded markup across templates.
  **Verified:** Read receipt lines 193–207 and 218–233 (identical `div#dom_id` row structure in both files); read `rules/views.mdc` § Collection Rendering, § Partials with Strict Locals, anti-patterns table.

- [confidence: 0.8] `app/views/**` + controller flashes: All user-facing copy is hardcoded English — "Archived", "No projects yet.", "Restore", "has been archived.", "by unknown". `rules/views.mdc`: "User-facing static copy — use `t()` / `I18n.t` and keys under `config/locales`, not raw strings scattered through ERB."
  **Verified:** Read receipt lines 108, 115 (controller flashes), 189, 197, 205, 222–226, 230 (views); read `rules/views.mdc` § Views Are HTML with Sprinkles (i18n paragraph).

- [confidence: 0.7] `app/views/**`: Styling uses semantic CSS classes (`projects-header`, `project-row`, `meta`) rather than Tailwind utilities in the markup. `rules/views.mdc` § Styling with Tailwind: "Utility classes go directly in the ERB markup." Interpretive — the receipt does not show the CSS setup — but the plugin's stack is Tailwind-utility-first.
  **Verified:** Read receipt lines 187, 195, 213, 219, 222; read `rules/views.mdc` § Styling with Tailwind.

- [confidence: 0.75] `spec/factories/projects.rb`: The `:archived` trait sets state columns directly (`archived_at { 1.day.ago }`, `archived_by { user }`) instead of going through the domain verb, as `rules/testing.mdc`'s factory example prescribes (`after(:create) { |article| article.publish(by: article.author) }`). Under the state-record shape this trait *must* change anyway — it will create the archival record via the verb.
  **Verified:** Read receipt lines 246–250; read `rules/testing.mdc` § FactoryBot example with the `:published` trait.

- [confidence: 0.7] `spec/requests/projects/archival_spec.rb`: The request spec "archives the project and records the archiver" re-asserts `project.archived_by` attribution that the model spec already owns ("records when and by whom the project was archived"). `rules/testing.mdc` § Each Behaviour Has One Home: request specs own the HTTP round-trip (status, redirect, record state flipped); the who/when attribution logic is the model spec's home. Drop the `archived_by` assertion from the request spec.
  **Verified:** Read receipt lines 377–382 against 274–286; read `rules/testing.mdc` § Ownership by Layer ("Domain logic → Model spec; System/request spec don't re-test the logic").

### Application-pattern violations

None — this is greenfield with no surrounding codebase, so there are no pre-existing application patterns to indict. All violations above are in the new code itself.

### Recommendations (non-blocking)

- [confidence: 0.6] `app/controllers/projects_controller.rb`: `before_action :authenticate_user!` assumes Devise (stated at receipt line 29). `rules/controllers.mdc` § Authentication documents the Rails 8 built-in generator (`include Authentication`, authenticate-by-default). If this app is genuinely greenfield Rails 8, use the built-in and drop the gem. Documented assumption, so non-blocking.
- [confidence: 0.6] `ApplicationController` is not shown; confirm `after_action :verify_authorized` and `verify_policy_scoped, only: :index` are in place per `rules/controllers.mdc` — the posture that would have caught the missing `index` authorize automatically.
- [confidence: 0.6] `spec/requests/projects/archival_spec.rb` line 390 asserts `redirect_to(root_path)` with the comment "or however you handle Pundit::NotAuthorizedError" — a spec keyed to unverified behavior. Pin it to the app's actual `rescue_from` handling before merge.

### Surroundings (pre-existing code in touched files)

**Boundary:** Entire submission is new (greenfield, per delegation). No surrounding code.

### Wiki capture candidates (optional)

- The archival-state decision itself: this feature is the canonical case for the plugin's state-as-record ladder (needs *who* + *when* → child record, not nullable columns). Worth a wiki entry once implemented correctly, so the next lifecycle feature (close, publish, lock) copies the right shape.
- The mass-assignment note at receipt line 134 (archival columns kept out of strong params) is a real security consideration — under the noun-resource shape it becomes structural (there are no archival columns on `projects` to mass-assign), which is the stronger version of the same guarantee and worth recording as rationale.

---

**Summary:** Competent mainstream Rails, but it misses the plugin's core architectural positions — Issues found: nullable timestamp+FK instead of an archival state record, RPC member verbs instead of a `Projects::Archivals` noun resource, custom policy verbs, bang domain verbs, `params.require`, and a missing `index` authorize, plus view/i18n/test-layer cleanups.
