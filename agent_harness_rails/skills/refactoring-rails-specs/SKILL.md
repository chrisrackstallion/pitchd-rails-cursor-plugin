---
name: refactoring-rails-specs
description: >-
  Refactor an existing RSpec suite — typically a batch of bloated system specs
  and their related request, model, policy, job, mailer, concern, and factory
  specs — into a Rails best-practice test suite per writing-tests and
  agent_harness_rails/rules/testing.mdc. Discover related specs, audit each test against the Five
  Gates and per-layer ownership, then move, merge, delete, or rewrite tests so
  each behaviour has exactly one home. Verify the suite is green and coverage
  is preserved. Use when the user mentions refactoring tests, rebalancing
  specs, "the system specs are too heavy", "we have too many browser tests",
  reducing test runtime, cleaning up a drifting test suite, or porting an
  older suite to current harness conventions. Not for writing new specs for
  untested code (use writing-tests) or for fixing failing specs unrelated to
  layering (debug them in writing-tests).
---

# Refactoring Rails Specs

<objective>
Take a list of existing specs — typically system specs the user wants to slim
— and produce a Rails best-practice test suite where every behaviour lives at
the correct layer per `writing-tests`. The work is bounded and auditable:
**discovery → audit → plan → execute → verify**. The end state has fewer,
faster, more focused specs with **no loss of meaningful coverage**.

This skill is **destructive** — it deletes and rewrites tests. Run the suite
before starting (capture the baseline) and after each batch (confirm green).
Never delete a test without confirming the assertion is owned at a lower
layer, either already or via a new spec written first.
</objective>

**Announce:** "I'm using the refactoring-rails-specs skill."

## When to use

- The user has a heavy system-spec suite and wants it slimmed against the budget in `agent_harness_rails/skills/writing-tests/references/system-specs.md`.
- A resource's specs are scattered across layers with duplication (same happy path in model + request + system).
- The user explicitly asks to "refactor", "rebalance", "clean up", or "audit" specs.
- A new harness version (or a fresh review) reveals layering violations across an existing suite.

**Do not use** for: writing new tests for untested code (`writing-tests`), debugging a single flaky spec, fixing a failing build, or any work that changes production code.

## Process

### 1. Pre-flight

Before touching any spec:

- **Read `agent_harness_rails/rules/testing.mdc`** if not already in context — the ownership table, anti-pattern table, Budget, and Five Gates are the rubric you will apply. **`agent_harness_rails/skills/writing-tests/references/system-specs.md`** has the gates' full rationale.
- **Capture a baseline.** Run the relevant slice (or the full suite if the batch is small):
  ```bash
  bin/rspec --format documentation > tmp/spec-baseline.txt
  ```
  Note the **total spec count**, the **system-spec count**, and **runtime**. You will compare against this at the end.
- **Confirm the suite is green.** Refactoring on top of a red suite hides regressions. If red, stop and report — the user must restore green first. Skip this only if the user has explicitly named the specs as failing and asked you to refactor them despite that.
- **Confirm scope.** The user should have named the input specs (file paths or feature names). If they said "refactor the test suite" without scope, ask which resource or feature to start with — this skill works one resource at a time.

### 2. Discovery — find related specs

For each input spec, locate every related spec across the codebase. **Read every related spec before changing any.**

For an input like `spec/system/articles_spec.rb`, expect to find and read:

| Layer | Likely location | What it should own |
|-------|----------------|---------------------|
| Model | `spec/models/article_spec.rb` | Domain logic, scopes, callbacks, business-rule validations |
| Concerns | `spec/models/concerns/<concern>_spec.rb` | The concern's whole contract — single home; including-model specs re-test overrides only |
| POROs | `spec/models/<model>/<object>_spec.rb` | The PORO's behaviour, at the path mirroring `app/models/` |
| Request | `spec/requests/articles_spec.rb` | HTTP layer, auth gates, rendering smoke, non-canonical CRUD |
| Policy | `spec/policies/article_policy_spec.rb` | Role × action matrix |
| State-change policies | `spec/policies/articles/*_policy_spec.rb` | Closure, publication policies |
| Jobs | `spec/jobs/*article*_spec.rb` | What the job does (not whether callers enqueue it) |
| Mailers | `spec/mailers/*article*_spec.rb` | Mail content (recipient, subject, body) |
| View (legacy) | `spec/views/articles/**` | Nothing — view specs are never written; any found are MOVE-to-request-spec candidates |
| Factory | `spec/factories/articles.rb` | Test-data shape |
| Support | `spec/support/*.rb` | Sign-in helpers, shared modules |
| Production code | `app/models/article.rb`, `app/controllers/articles_controller.rb`, `app/policies/article_policy.rb` | Read so you know what the specs cover |

Use `Bash` with `find` and `Grep` to locate related files. For multi-resource journeys (signup, onboarding, checkout), the related specs span multiple resources — map them all before starting work.

**Output of discovery:** a list of files. Read every one. Do not start auditing until the map is complete.

### 3. Audit — score every test

Build a structured plan. For each `it` / `scenario` block across the discovered specs, answer four questions and assign a verdict.

#### Layer audit — is it in the right file?

| Spec type | Belongs here if… | Move it if… |
|-----------|------------------|-------------|
| System | Passes all Five Gates (interaction, uniqueness, JS-necessity, single-home, one-story) | `visit` + assert only, per-field, CRUD parity, repeats a JS pattern, drives by on unrelated UI, asserts model internals |
| Request | Tests status code, redirect, auth gate, params, rendering smoke, or non-canonical CRUD round-trip | Re-asserts `article.publish` (model spec), re-walks policy matrix (policy spec), duplicates canonical happy path (system spec) |
| Model | Tests a domain verb, scope, callback, normalization, or business-rule validation | Asserts `validates :title, presence: true` (Rails framework), asserts HTTP, asserts UI |
| Policy | Tests `Policy.new(user, record).action?` returning true/false for each role | Makes HTTP requests, asserts UI, signs in via the form |
| Job | Tests what `perform_now(id)` does, including idempotency | Re-tests the model method the job calls, asserts mail content (that's the mailer spec) |
| Mailer | Tests recipient/subject/body of the generated mail object | Tests delivery (callers do that with `have_enqueued_mail`) |

#### Intent audit — does this `it` block carry an `intent:` tag?

**Only when the app has a `docs/primitives/` tree.** A tagged example is a
capability doc's evaluation, so a verdict on it is a verdict on the record too:

- **MOVE** — the tag travels with the example, and the clause's `evaluations:`
  gains the new path and loses the old one.
- **MERGE** — the surviving example carries the union of the tags. Check the
  merge did not swallow the half that proved a quantifier: two examples proving
  *"only the author can edit"* — one permitting, one denying — cannot become one
  example without the clause losing a side
  (`agent_harness_rails/rules/intent-tags.mdc` § What counts as proving a clause).
- **DELETE** — a tagged example is only deletable if its clause is still proven
  elsewhere afterwards. If it is the last proof, the deletion is out of scope for
  a refactor: it removes coverage, not duplication. Flag it and leave it.
- **REWRITE** — re-read the clause against the rewritten example. A rewrite that
  drops to a lower layer for speed can quietly turn an outcome assertion into an
  affordance assertion.

Take **`agent_harness_rails proofs '<capability>#I<n>'`** before and after each
touched clause: it lists each evaluation file's tagged examples with a count,
so a tag dropped in a merge or a split shows as a number that went down. `evals` cannot see it — one surviving tag makes the whole file a
carrier — and `guard`'s `proof/removed` only fires when a tagged example is gone,
not when a surviving one lost its tag.

Never resolve a tag by deleting it from the example — that silently unproves a
clause while keeping the suite green, and `agent_harness_rails evals` will then
fail on the doc rather than on the spec that caused it. Finish the session with
`agent_harness_rails evals` green.

Then run **`agent_harness_rails guard --base <the commit this session started
from>`**. A spec refactor is the single largest legitimate source of its notices,
which is exactly why it is worth reading here: `guard` lists every tagged example
that lost assertions (`proof/weakened`), disappeared (`proof/removed`), or moved
to another layer (`evaluation/relayered`) — the audit-plan verdicts, read back off
what actually happened rather than off what the plan intended. Reconcile each
notice against its MERGE / DELETE / REWRITE verdict. One with no verdict behind it
is coverage this session dropped by accident; restore it. Notices about **intent**
(`intent/rewritten`, `intent/vanished`) mean the session edited promises, which a
spec refactor never does — stop and surface those.

#### Duplication audit — is this assertion already proven elsewhere?

Walk every assertion and check the other layers for the same claim — the owner
for each is settled by `agent_harness_rails/rules/testing.mdc` § Ownership by
Layer. Common duplications:

- **Happy-path triplets:** same create flow in model, request, and system specs. Keep the system spec for the canonical journey only; trim the request spec to status/auth/422 and the model spec to domain logic.
- **Stimulus controllers tested across files:** the same `data-controller="counter"` exercised in five system specs. Keep one, on the simplest page.
- **Field round-tripping:** persistence-via-UI tested as a system spec when the model and request specs already prove it. Drop the system spec.
- **Validation rules in two places:** `validates :title, presence: true` tested in both the model spec (deletion candidate — that's Rails) and the system spec ("user sees can't be blank" — keep as the canonical validation-error system spec for the form).

#### Anti-pattern audit — flag specifically

Mark any of these and assign verdicts:

| Anti-pattern | Default verdict |
|--------------|----------------|
| `visit` + assert with no interaction | **MOVE** to request spec with `response.body.include?` |
| View spec (`spec/views/`, `type: :view`) | **MOVE** the rendering assertion to a request spec (`response.body.include?`), then delete the file — view specs are never kept |
| `not_to` as the only assertion, read off a page or response | **REWRITE** — add an anchor that goes red when the request breaks (the status, or a landmark); keep the `not_to`. **DELETE** only if no behaviour is behind it at all |
| `not_to` as the only assertion, answered directly by the unit (`not_to permit`, `not_to be_published`, `not_to raise_error`) | **KEEP** — nothing can fail into its passing side. Optionally **REWRITE** to the positive spelling (`expect(policy.destroy?).to be false`) |
| One system spec per field/attribute | **MERGE** into the canonical create flow |
| CRUD parity: separate system specs for show / edit / delete with identical shape | **MOVE** show/edit/delete to request specs; keep the create as canonical |
| Selenium driver where `rack_test` passes | **REWRITE** to use `rack_test` |
| Repeated JS-behaviour tests across files | **DELETE** the duplicates; keep one on the simplest page |
| Drive-by assertions (nav, footer, sidebar inside a feature spec) | **DELETE** drive-bys; assert them in a layout/helper test if at all |
| Flash copy as the primary success signal | **REWRITE** to assert resource state on the page; flash becomes secondary |
| System spec asserting `article.reload.publication` | **MOVE** the assertion to the model spec |
| Request spec asserting `article.published?` | **MOVE** to the model spec |
| Request spec walking the policy matrix | **MOVE** matrix branches to the policy spec; keep one authorized + one unauthorized in the request spec |
| Job spec calling `article.publish` directly | **MOVE** the model assertion to the model spec; the job spec asserts what the job orchestrates |
| Model spec testing `belongs_to :author` | **DELETE** (Rails framework) |

#### Verdict

For every `it` block, assign one of:

- **KEEP** — correct layer, no duplication, useful coverage. No action.
- **MOVE** — the assertion belongs at a different layer. Write the new test at the destination first; verify it passes; then delete the source.
- **MERGE** — collapse into another test (same setup/action, or fold a per-field spec into the canonical flow).
- **DELETE** — the test is testing Rails, is a removal receipt, or duplicates an assertion already correctly placed elsewhere.
- **REWRITE** — keep the intent but rewrite to match harness patterns (e.g. `rack_test` instead of Selenium, inline setup instead of nested `let`).

**Write the audit plan to a temporary file** (e.g. `tmp/refactor-articles-plan.md`) or print it to the user before executing. The plan should list every `it` block by file and line, with the verdict and one-line rationale. This is the artifact the user (or a reviewer) checks against the final result.

### 4. Sequence the changes

Execute in an order that keeps the suite green and the diff reviewable:

1. **Add before deleting.** When MOVE-ing an assertion, write the destination spec first and run it green. Only then delete the source. This guarantees no behavioural gap.
2. **One resource at a time.** Do not interleave changes across articles + comments + users in a single batch — the diff becomes unreviewable and regressions hide.
3. **Group by destination within a resource.** When you have several MOVEs into `spec/models/article_spec.rb`, do them together so the file's diff is coherent.
4. **Run the focused slice after each step.**
   ```bash
   bin/rspec spec/system/articles_spec.rb spec/requests/articles_spec.rb \
             spec/models/article_spec.rb spec/policies/article_policy_spec.rb
   ```
   Green before the next change. If red, fix immediately — do not accumulate broken state.
5. **Run RuboCop on touched files.** `bin/rubocop spec/system/articles_spec.rb spec/requests/articles_spec.rb …` — fix all offences before continuing per `agent_harness_rails/skills/running-rubocop/SKILL.md`.

### 5. Execute the verdicts

For each item in the plan:

**KEEP** — no action. Confirm it's still passing at the end.

**MOVE** — write the equivalent assertion at the destination layer. Patterns:

- Visit-only system spec → request spec asserting `response.body.include?`:
  ```ruby
  # Before (spec/system/articles_spec.rb)
  it "shows the article" do
    article = create(:article, :published, title: "Hello")
    visit article_path(article)
    expect(page).to have_content("Hello")
  end

  # After (spec/requests/articles_spec.rb)
  it "renders the article title" do
    sign_in create(:user)
    article = create(:article, :published, title: "Hello")
    get article_path(article)
    expect(response.body).to include("Hello")
  end
  ```

- Domain assertion in request spec → model spec:
  ```ruby
  # Before (spec/requests/articles_spec.rb)
  it "publishes" do
    post article_publication_path(article)
    expect(article.reload).to be_published
  end

  # After
  # spec/models/article_spec.rb gains the domain assertion if missing.
  # spec/requests/articles_spec.rb keeps only the HTTP shape:
  it "redirects after publishing" do
    sign_in author
    post article_publication_path(article)
    expect(response).to redirect_to(article_path(article))
  end
  ```

- Policy matrix branch in request spec → policy spec context:
  ```ruby
  # Before — request spec walks the matrix
  it "admin can destroy" / "member cannot destroy" / "owner can destroy" / ...

  # After — request spec keeps one authorized + one unauthorized
  # Policy spec gains the full matrix:
  describe ArticlePolicy do
    context "as admin"    { it "permits destroy" }
    context "as member"   { it "forbids destroy" }
    context "as the owner" { it "permits destroy" }
    # ...etc
  end
  ```

**MERGE** — collapse `it` blocks with identical setup/action into one with multiple `expect`s. Or fold a per-field spec into the canonical create flow's assertions.

**DELETE** — remove the test. Required preconditions, **all** must be true:

- The behaviour is already covered at the correct layer, **OR** the test asserts Rails framework behaviour, **OR** the test is a removal receipt — a `not_to` with no behaviour behind it, written to record that a feature is gone. A `not_to` the unit answers directly is **not** a removal receipt and is never deleted for lacking a positive assertion.
- The test is not the only place the behaviour is asserted.

If neither applies, **do NOT delete**. Write the missing lower-layer test first; then delete.

**REWRITE** — keep the file and intent but bring it to harness patterns:

- Selenium → `rack_test` when the spec passes without JS
- `is_expected.to` with implicit subject → explicit setup
- Deep `let` chains → inline setup in each test
- `allow_any_instance_of` → real path or dependency injection
- `before(:all)` for records → `create` inline

### 6. Verify the end state

After all verdicts in the batch are executed:

- **Run the full suite, not just the touched slice.** `bin/rspec` — fully green. A
  spec-refactor session is one of the cases where a full run is earned. **If it comes
  back red, work the failures, not the run:** fix, re-run just those examples or files
  (`--only-failures` where the app persists example status), and re-run the suite bare
  **once** at the end when they are green — not after every fix
  (`agent_harness_rails/rules/testing.mdc` § When a Run Comes Back Red).
- **Compare against the baseline:**
  - Spec count: should be **lower** (moves/merges/deletes net down).
  - System-spec count: should be **significantly lower** — this is the primary goal.
  - Selenium-driven spec count: should be **lower or unchanged** (never up).
  - Runtime: should be **lower** (system specs are expensive).
  - Pass rate: must be **100%**. Do not introduce skipped or pending.
- **Cross-check coverage against the audit plan.** Walk every assertion in the original input specs and confirm it is asserted somewhere in the post-refactor suite. Use the plan as the checklist. If anything was silently dropped, **stop** — restore it or write the missing lower-layer coverage.
- **Run RuboCop.** `bin/rubocop` — zero offences per `agent_harness_rails/skills/running-rubocop/SKILL.md`.

### 7. Report

Produce a single-screen summary the user can scan:

```markdown
## Refactored: <feature or resource>

### Files touched
- spec/system/articles_spec.rb
- spec/requests/articles_spec.rb
- spec/models/article_spec.rb
- spec/policies/article_policy_spec.rb

### Counts
                        Before   After
Total specs              48       32
System specs             12        2
Selenium specs            5        1
Runtime (full suite)     24s       7s

### Verdicts applied
- MOVE: 7  (5 system → request, 2 request → model)
- MERGE: 4 (CRUD parity collapsed; per-field assertions folded into create)
- DELETE: 3 (2 visit-only system specs, 1 not_to-only removal receipt)
- REWRITE: 2 (Selenium → rack_test)
- KEEP: 16

### Coverage
Every behaviour from the original suite is asserted at exactly one layer in
the new suite. Audit plan: tmp/refactor-articles-plan.md

### Verification
- bin/rspec: green (32 examples, 0 failures, 0 pending)
- bin/rubocop: green
```

End with one line: **"Refactor complete. Suite is green and budget-compliant."**

## Boundaries

- **One resource per session.** Refactor articles, verify, commit, then start a new session for comments. Do not attempt the whole suite in one pass — the audit plan becomes unwieldy and regressions hide.
- **Never reduce coverage to meet the budget.** If a system spec is the only place a behaviour is currently tested, write the lower-layer spec **first**, then refactor. Coverage preservation is non-negotiable.
- **Do not introduce coverage for untested code.** If you spot an untested code path during discovery, flag it for a follow-up but do not write the tests here. That's `writing-tests` work.
- **Do not change production code.** If a test reveals a bug or an awkward model API, name it in the report and stop. Production refactors run in a separate session per `agent_harness_rails/skills/implementing-rails-task/SKILL.md`.
- **Do not skip the audit plan.** The plan is the artifact that lets the user (and a reviewer) trust nothing was silently dropped. Writing it to a temp file or printing it before executing is mandatory.
- **Stop if the suite goes red and you cannot immediately restore it.** Roll back the last verdict and report. Do not pile changes on a broken suite.

## Anti-patterns

| Anti-pattern | Instead |
|--------------|---------|
| Deleting a system spec without first proving the assertion at a lower layer | Add the lower-layer spec, verify it passes, then delete the source |
| Refactoring multiple resources in one session | One resource per session; commit between |
| Skipping the audit plan because "I can hold it in my head" | Write the plan; the user needs to trust the diff |
| Rewriting production code to make a test pass after the move | Production refactors are a separate session |
| Marking specs `pending` or `skip` to bring the suite green | Fix or revert; pending hides regressions |
| Deleting tests that look redundant without checking the other layers | Discovery and audit are mandatory; no shortcuts |
| Letting the system-spec count drop below the budget | Budget is a typical default, not a floor; multi-step journeys legitimately need more — justify in the report |
| Adding new behavioural coverage during refactor | Out of scope; flag for a follow-up session |
| Deleting an `intent:` tag, or the last example proving a clause | Unproves a capability while the suite stays green; flag it and leave the example |
| Changing factories to make moved tests pass without verifying other specs still work | Factory changes are cross-cutting; run the full suite after any factory edit |
| Re-running the whole suite after each fix for a handful of failures | The other results still stand — re-run the failing examples, then the suite once at the end (`agent_harness_rails/rules/testing.mdc` § When a Run Comes Back Red) |

## Verification Checklist

Before declaring done:

- [ ] Baseline captured: total spec count, system-spec count, Selenium count, runtime, pass rate
- [ ] All related specs for each input discovered (model / request / policy / job / mailer / concern / factory / support) and read
- [ ] Audit plan written, one verdict per `it` block
- [ ] The refactored files pass the layering items of the writing-tests checklist (`agent_harness_rails/skills/writing-tests/SKILL.md` § Verification): Five Gates, no `visit`-only or view specs, no Selenium that passes under `rack_test`, no per-field or CRUD-parity system specs, no repeated Stimulus/Turbo coverage, anchored absences, no removal receipts
- [ ] System-spec count per resource is within budget (typically 1 canonical journey; up to a few for multi-step journeys)
- [ ] No duplicate happy-path coverage across model + request + system
- [ ] Each assertion from the original suite is reachable at exactly one layer in the new suite
- [ ] Every `intent:` tag moved with its example, still sits on an `it` block, and its clause's `evaluations:` paths were updated; no tag was deleted to resolve a verdict
- [ ] `agent_harness_rails evals` is green (only when the app has a `docs/primitives/` tree)
- [ ] Every `agent_harness_rails guard` notice reconciles to an audit-plan verdict; no intent notices
- [ ] `bin/rspec` is green (no new skipped/pending)
- [ ] `bin/rubocop` is green
- [ ] System-spec count materially reduced; runtime materially reduced
- [ ] Report written: counts, verdicts, coverage statement, verification status

## Subagent (optional)

This skill can be delegated to the **`rails-implementor`** subagent at `agent_harness_rails/agents/rails-implementor.md` when the work is scoped to a single resource and the parent wants to keep the main context clean; the parent passes the input spec list, baseline expectations, and a pointer to this skill in the task prompt.

For larger refactors spanning multiple resources, prefer running this skill one resource at a time in the main session — smaller diffs, easier audit-plan review.

## Related

- **Test-writing conventions:** `agent_harness_rails/skills/writing-tests/SKILL.md` (`references/system-specs.md`, `references/request-specs.md`, `references/model-specs.md`, `references/support-specs.md`, `references/factory-patterns.md`)
- **Testing rule:** `agent_harness_rails/rules/testing.mdc` (ownership table, anti-patterns, budget, Five Gates)
- **Intent tags:** `agent_harness_rails/rules/intent-tags.mdc` (tag placement, what counts as proving a clause)
- **Primitives rule:** `agent_harness_rails/rules/primitives.mdc` — read only when the app has a `docs/primitives/` tree and the refactor touches tagged examples
- **RuboCop:** `agent_harness_rails/skills/running-rubocop/SKILL.md` — run after every refactor batch
- **Implementor subagent:** `agent_harness_rails/agents/rails-implementor.md` — optional delegation
- **Reviewer skill / subagent:** `agent_harness_rails/skills/reviewing-rails-work/SKILL.md` — run after a large refactor to confirm harness fit
- **Compass:** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md` — read only if the refactor surfaces a philosophy question (HTML vs API, server vs client truth); usually not needed
