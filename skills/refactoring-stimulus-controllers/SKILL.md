---
name: refactoring-stimulus-controllers
description: >-
  Audit and refactor an existing fleet of Stimulus controllers in a Rails app —
  discover every controller, score each against single-responsibility,
  DOM-derived state, lifecycle cleanup, and cross-controller coupling rules,
  then merge or split as appropriate. After the structural refactor, ensure
  each Stimulus behaviour has exactly one canonical system spec on the simplest
  page that exercises it, per writing-tests. Use when the user mentions
  refactoring Stimulus, "the Stimulus controllers are a mess", consolidating
  duplicate JS behaviour, splitting a god controller, or filling in Stimulus
  spec coverage. Not for writing brand-new controllers from scratch (use
  writing-javascript) or refactoring server-side specs (use
  refactoring-rails-specs).
---

# Refactoring Stimulus Controllers

<objective>
Take the existing Stimulus controllers in a Rails app and produce a clean,
plugin-compliant fleet: single-purpose controllers, DOM-derived state, proper
lifecycle cleanup, no global state, and exactly one canonical system spec per
behaviour. The work is bounded and auditable: **discovery → audit → plan →
execute → cover → verify**. Coverage is preserved; behaviour is preserved; the
suite is green; controllers are smaller, fewer overall (after merges and
splits net out), and each one earns its place.

This skill is **destructive** — it deletes controllers, rewrites attachments
in ERB, and touches specs. Run the suite before starting (capture the
baseline) and after each batch (confirm green). Never delete a controller
without confirming every `data-controller="…"` reference has been migrated.
</objective>

**Announce:** "I'm using the refactoring-stimulus-controllers skill."

## When to Use

- The user says the Stimulus fleet is messy, oversized, duplicated, or
  inconsistent.
- A controller has grown past ~100 lines or has more than one clear
  responsibility.
- The same behaviour is implemented twice under different names
  (`reveal_controller` and `disclosure_controller` both toggling a panel).
- Controllers leak listeners, hold state in closures, or break under Turbo
  morphing.
- The user wants Stimulus behaviours covered by system specs and currently has
  none — or has redundant Selenium specs hitting the same controller.

**Do not use** for:

- Writing brand-new controllers for a new feature (`../writing-javascript`).
- Refactoring server-side specs without touching JS
  (`../refactoring-rails-specs`).
- Replacing Stimulus with a SPA framework — out of scope, off-omakase
  (`../rails-omakase-compass`).
- Tailwind / CSS refactors (`../writing-css-tailwind`).

## Process

### 1. Pre-flight

Before touching any controller:

- **Read `../writing-javascript/SKILL.md` and
  `../writing-javascript/references/patterns.md`** for the controller anatomy
  and quality rules.
- **Read `../writing-hotwire/references/patterns.md`** § Stimulus for the
  ERB-side wiring conventions.
- **Read `../writing-tests/references/system-specs.md`** for the Five Gates
  and Budget rules — they govern which controllers get a system spec.
- **Skim `../../rules/javascript.mdc` and `../../rules/hotwire.mdc`** for the
  anti-pattern tables.
- **Capture a baseline.** Run the suite (or the relevant slice) and record:
  ```bash
  bin/rspec --format documentation > tmp/stimulus-spec-baseline.txt
  bin/rubocop > tmp/stimulus-rubocop-baseline.txt 2>&1 || true
  ```
  Note: total spec count, system-spec count, Selenium spec count, runtime,
  pass rate.
- **Confirm the suite is green.** Refactoring on top of red hides
  regressions. If red, stop and report.
- **Confirm scope.** Refactor in **batches by behaviour**, not "everything".
  If the user said "refactor Stimulus", ask which behaviour or page to start
  with — this skill works one cluster at a time (e.g. all disclosure /
  reveal-style controllers, then all dropdown-style, then all auto-submit).

### 2. Discovery

Map every Stimulus controller and every place it is attached.

```bash
# All controllers
find app/javascript/controllers -name "*_controller.js"

# All attachments in ERB (controllers, actions, targets, values, classes, outlets)
grep -rEn 'data-(controller|action|[a-z][a-z0-9-]*-(target|value|class|outlet))' app/views

# Cross-controller wiring (outlets and dispatched events)
grep -rEn 'static outlets|this\.dispatch\(' app/javascript/controllers
```

Build a **controller map** — one row per controller:

| Controller | File | Pages / partials that attach it | Targets | Values | Outlets | Dispatched events | Listeners attached in `connect` |
|------------|------|---------------------------------|---------|--------|---------|--------------------|---------------------------------|

Also locate **system specs** that exercise each controller:

```bash
grep -rEn 'driven_by\(:selenium' spec/system
grep -rEn 'visit .*<page-that-uses-controller>' spec/system
```

**Output of discovery:** the controller map plus a list of related system
specs. Read every controller file and every related spec before changing
anything.

### 3. Audit — Score Every Controller

For each controller, answer the questions and assign verdicts.

#### Responsibility audit — what does it do?

Write a **one-sentence purpose** for each controller. If you can't, that's a
finding. Examples of good purposes:

- "Toggle a panel open/closed with `aria-expanded` syncing."
- "Copy a value to the clipboard and flash a confirmation class."
- "Debounce a form submit and request a Turbo Stream response."

Examples of bad purposes (each is a split candidate):

- "Handles the article form." (vague — what does it actually do?)
- "Toggles the panel **and** debounces search **and** posts a fetch." (three
  controllers in one)
- "Mostly a dropdown but also closes a modal when clicked outside." (two
  unrelated behaviours)

#### Quality audit — does it follow the rules?

| Dimension | Pass if… | Fail signal |
|-----------|----------|-------------|
| Single responsibility | One verb in the name; one behaviour in the file | God-controller; "Manager"/"Helper" in the name |
| Size | ≤ ~100 lines; reads top-to-bottom | Long, scrolls past one screen; nested conditionals |
| `static` declarations | Uses `targets`, `values`, `classes`, `outlets` | `querySelector` calls; hard-coded class strings |
| DOM-derived state | Reads from targets/values/attributes each time | `this.foo = …` in `connect()` and never re-read |
| Lifecycle hygiene | Every `addEventListener` in `connect` has a `removeEventListener` in `disconnect`; observers/timers torn down | Leaked listeners; observers not disconnected |
| Cross-controller coupling | Uses outlets or `this.dispatch` | Reaches into other controllers via `document.querySelector` or `window.MyApp` |
| Accessibility | Toggles `aria-*` and `hidden` alongside classes; manages focus on overlays | CSS-only state changes; focus left dangling |
| Network | Goes through `@rails/request.js` or hand-rolled `fetch` with CSRF | `XMLHttpRequest`; missing CSRF; `alert()` on error |
| DOM safety | `textContent` for user input; no `eval`/`new Function` | `innerHTML = userInput`; `eval` |

#### Duplication audit — is this behaviour already implemented?

Walk the controller map for behaviour overlaps:

- `reveal_controller` and `disclosure_controller` both toggling a panel
- `autosubmit_controller` and `debounce_form_controller` doing the same job
- `clipboard_controller` and `copy_controller` with one extra feature each
- Two "modal" controllers, one global and one per-page

Mark each cluster of duplicates — they're MERGE candidates.

#### Split audit — does this controller hold two behaviours?

If the purpose sentence has "**and**" in it, the controller is two
controllers. Common splits:

- Form **debounce** + form **submit** with a fetch → `debounce_controller`
  + `autosubmit_controller`
- Panel **toggle** + **click-outside-to-close** → `reveal_controller`
  + `dismiss_controller`
- **Clipboard copy** + **success flash** is *one* behaviour — don't split
  every method; split when behaviours are independently useful.

#### Verdict

Assign one verdict per controller:

- **KEEP** — single-purpose, clean, in good shape. No action.
- **MERGE** — combine with another controller (same behaviour duplicated, or
  two trivial controllers that always appear together and share state).
- **SPLIT** — break into two or more focused controllers. ERB attachments
  fan out (`data-controller="reveal dismiss"`).
- **REWRITE** — keep the file but bring it to plugin standards (add
  `static targets`, remove closure state, fix lifecycle, etc.).
- **DELETE** — controller is unused (no `data-controller` reference) or
  duplicated by a KEEP'd controller.

**Write the audit plan to a temp file** (e.g.
`tmp/refactor-stimulus-<cluster>-plan.md`) listing every controller, its
purpose sentence, its quality findings, and its verdict with rationale.
This is the artifact the user (or reviewer) checks the final result against.

### 4. Sequence the Changes

Execute in an order that keeps the page working and the diff reviewable:

1. **One behaviour cluster per batch.** Refactor disclosure / reveal in one
   pass; debounce + submit in another. Do not interleave.
2. **Add before deleting.** When MERGE-ing into a target controller, write
   or extend the target first, migrate every ERB attachment, then delete the
   source.
3. **Migrate ERB attachments in lockstep with controller changes.** A
   renamed controller (`reveal` → `disclosure`) needs every
   `data-controller="reveal"`, `data-reveal-target`, `data-reveal-*-value`,
   `data-reveal-*-class`, and `reveal:` action / event listener updated in
   the same commit / batch.
4. **Run the focused slice after each step:**
   ```bash
   bin/rspec spec/system  # or the relevant subset
   ```
   Green before the next step. If red, fix immediately.
5. **Run RuboCop on touched Ruby files** (`bin/rubocop`) — controllers are
   JS but ERB partials and spec files often co-change.

### 5. Execute the Verdicts

#### KEEP

No action; confirm tests still pass at the end.

#### REWRITE

Bring the controller to plugin standards without changing public behaviour:

```js
// Before — closure state, hard-coded classes, querySelector
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.open = false
    this.panel = this.element.querySelector(".panel")
    this.button = this.element.querySelector(".trigger")
    this.button.addEventListener("click", () => this.toggle())
  }

  toggle() {
    this.open = !this.open
    this.panel.classList.toggle("hidden", !this.open)
  }
}

// After — DOM-derived state, static declarations, data-action
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle"]
  static values  = { open: { type: Boolean, default: false } }
  static classes = ["hidden"]

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.panelTarget.classList.toggle(this.hiddenClass, !this.openValue)
    this.toggleTarget.setAttribute("aria-expanded", this.openValue)
  }
}
```

Update ERB to match:

```erb
<div data-controller="reveal" data-reveal-hidden-class="hidden">
  <button type="button"
          data-reveal-target="toggle"
          data-action="reveal#toggle"
          aria-expanded="false">
    Details
  </button>
  <div data-reveal-target="panel" class="hidden">…</div>
</div>
```

#### MERGE

Two controllers with the same behaviour collapse into one canonical name.
Steps:

1. Pick the canonical name (the one matching plugin conventions; if neither,
   rename).
2. Extend the canonical controller to cover any features only the loser had.
3. Update every ERB reference: `data-controller="loser"` →
   `data-controller="canonical"`; `data-loser-*-value` → `data-canonical-*-value`;
   `data-action="loser#…"` → `data-action="canonical#…"`.
4. Update any outlets / dispatched events that referenced the loser.
5. Run the focused spec slice — green.
6. Delete the loser file.
7. Update or remove specs that were exercising the loser.

If two controllers reasonably stand alone but always appear together, you
**don't merge** — leave them as outlets-coupled siblings.

#### SPLIT

A controller doing two things splits into two named controllers. Steps:

1. Name each new behaviour with a verb (`debounce_controller`,
   `autosubmit_controller`).
2. Create the new files; move the relevant methods, targets, values, classes.
3. Update ERB attachments: `data-controller="form"` becomes
   `data-controller="debounce autosubmit"`; targets and values fan out to
   their owning controller (`data-debounce-delay-value`,
   `data-autosubmit-url-value`).
4. Re-wire cross-controller communication via outlets or
   `this.dispatch("submit-requested")`.
5. Run the focused spec slice — green.
6. Delete the original controller.

#### DELETE

Required preconditions, **all** must be true:

- No `data-controller="<name>"` reference anywhere in `app/views` or
  rendered HTML (check helpers and Ruby code that emits
  `tag.div(data: { controller: "…" })`).
- No other controller declares it as an outlet.
- No system spec drives behaviour that depends on it.

If any of those are false, do **not** delete — migrate or MERGE first.

### 6. Ensure Spec Coverage

After the structural refactor, each Stimulus behaviour gets **exactly one
canonical system spec on the simplest page that exercises it**, per
**`../writing-tests/references/system-specs.md`** § Budget. Other usages of
the same controller across the suite **assume it works** — no second spec
per page.

#### Build the controller-to-spec map

For each KEEP'd / REWROTE / merged-into-canonical / split controller, find
its existing spec:

```bash
grep -rEn 'driven_by\(:selenium' spec/system | sort
grep -rEn 'visit ' spec/system | head
```

For each controller, one of three is true:

- **Has a canonical spec already** — confirm it still passes after the
  refactor; trim drive-by assertions.
- **Has multiple specs across pages** — pick the simplest representative
  page; **delete** the duplicates per `../writing-tests/references/system-specs.md`
  (Stimulus controllers earn at most one spec across the suite).
- **Has no spec** — write one. The simplest representative page that
  exercises the controller is the home.

#### Writing a canonical Stimulus system spec

Apply the Five Gates from `../writing-tests/references/system-specs.md`:

1. **Interaction gate** — the spec calls a real action (`click_button`,
   `fill_in`, `select`, etc.).
2. **Uniqueness gate** — no other system spec already proves this behaviour.
3. **JavaScript-necessity gate** — the behaviour cannot be proven by a
   request spec asserting Turbo Stream content or by trusting lower layers.
   Selenium is justified.
4. **Single-home gate** — the assertion is not owned by a model, request,
   or policy spec.
5. **One-story gate** — one behaviour, one story, no drive-by assertions.

```ruby
RSpec.describe "Disclosure", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "user expands a collapsed disclosure" do
    user = create(:user)
    article = create(:article, :with_details, author: user)
    sign_in user

    visit article_path(article)

    expect(page).to have_selector("button[aria-expanded='false']", text: "Details")
    click_button "Details"
    expect(page).to have_selector("button[aria-expanded='true']", text: "Details")
    expect(page).to have_content(article.details.summary)
  end
end
```

Pick the **simplest page** the controller appears on, not the most
feature-rich. Other pages that use `data-controller="reveal"` assume it
works.

#### Deleting redundant Stimulus system specs

If the same controller is exercised in three system specs (article page,
comment page, settings page), keep one and delete the other two. The deleted
ones go because:

- the controller is canonically covered elsewhere (single-home), and
- the rest of each page's behaviour belongs in lower-layer specs (request,
  model, policy).

Apply the existing **`../refactoring-rails-specs`** verdicts (KEEP / MOVE /
MERGE / DELETE / REWRITE) per spec — this skill defers to that one for
non-Stimulus spec work surfaced during the audit.

### 7. Verify the End State

After all verdicts in the batch are executed:

- **`bin/rspec`** — fully green.
- **`bin/rubocop`** — zero offences (controllers may be JS but ERB and spec
  files often co-changed).
- **Lint JS** if a linter is configured (`bin/eslint`, `npx eslint`); fix all
  offences.
- **Compare against the baseline:**
  - Controller count: **lower** (merges + deletes outweigh splits in
    typical refactors; splits can raise the count for one cluster — that's
    fine if responsibility is now clean).
  - Total controller LOC: **lower** (god controllers shrink).
  - Selenium spec count: **lower or unchanged** (never higher).
  - Suite runtime: **lower or roughly unchanged**.
  - Pass rate: **100%**. No new pending / skipped.
- **Cross-check coverage.** Every Stimulus behaviour from the audit map has
  exactly one canonical system spec, on the simplest page. Walk the map.
- **Cross-check attachments.** No ERB still references a deleted controller
  name, target, value, class, or outlet:
  ```bash
  grep -rEn 'data-(<deleted-name>|<deleted-name>-)' app/views || true
  ```

### 8. Report

Single-screen summary the user can scan:

```markdown
## Refactored Stimulus: <cluster name>

### Controllers touched
- app/javascript/controllers/reveal_controller.js (REWRITE)
- app/javascript/controllers/disclosure_controller.js (DELETE, merged into reveal)
- app/javascript/controllers/dropdown_controller.js (SPLIT into dropdown + dismiss)

### ERB partials updated
- app/views/articles/_details.html.erb
- app/views/layouts/_nav.html.erb
- …

### Specs
- spec/system/disclosure_spec.rb (NEW canonical spec)
- spec/system/dropdown_menu_spec.rb (KEEP)
- spec/system/article_navigation_spec.rb (DELETED — duplicated disclosure coverage)

### Counts
                        Before   After
Stimulus controllers     14        9
Total controller LOC     1,820     980
Selenium specs           7         4
Suite runtime            42s       28s

### Verdicts applied
- KEEP: 4
- REWRITE: 3
- MERGE: 2 → 1 canonical
- SPLIT: 1 → 2
- DELETE: 2 (1 unused, 1 merged)

### Coverage
Every Stimulus behaviour has exactly one canonical system spec on the simplest
representative page. Audit plan: tmp/refactor-stimulus-disclosure-plan.md

### Verification
- bin/rspec: green (N examples, 0 failures, 0 pending)
- bin/rubocop: green
- eslint (if configured): green
- No ERB references to deleted controller names remain
```

End with one line: **"Stimulus refactor complete. Suite is green and the
fleet is plugin-compliant."**

## Boundaries

- **One behaviour cluster per session.** Disclosure today; debounce-submit
  next session. Audit plans for the whole fleet become unreviewable.
- **Never reduce behavioural coverage.** If a controller's behaviour is
  currently uncovered by any spec, write the canonical system spec **before**
  refactoring; refactor against a green spec.
- **Never delete a controller without scanning every attachment.** ERB,
  view helpers that emit `data-controller`, mailers (rare), JSON responses
  embedding HTML — all candidates.
- **Do not change server-side behaviour.** If the audit surfaces a controller
  shape (a bad route, a missing Turbo Stream, a JSON endpoint that should be
  HTML), flag it in the report and stop. Server refactors run in a separate
  session per **`../implementing-pitchd-rails/SKILL.md`**.
- **Do not skip the audit plan.** The plan is the reviewer's checklist.
  Writing it to a temp file or printing it before executing is mandatory.
- **Selenium budget is a ceiling, not a target.** If a behaviour can be
  proved by a request spec asserting `Content-Type: text/vnd.turbo-stream.html`
  and the rendered fragment, do that — only Selenium when JS is truly
  necessary.
- **Stop if the suite goes red and you cannot immediately restore it.** Roll
  back the last verdict and report.

## Anti-Patterns

| Anti-Pattern | Instead |
|--------------|---------|
| Deleting a controller without first migrating every `data-controller` reference | Migrate ERB in lockstep; grep before delete |
| Splitting every controller for its own sake | Split only when responsibilities are independently useful |
| Merging two controllers that share a name but not a behaviour | Keep separate; rename one if the collision is the only issue |
| Writing one system spec per page that uses a Stimulus controller | One canonical spec on the simplest page; trust the rest |
| Refactoring controllers without running the system specs | The suite is the safety net — green before each batch |
| Rewriting production server code to make a controller test pass | Server refactors are a separate session |
| Marking specs `pending` or `skip` to stay green | Fix or revert |
| Refactoring multiple clusters in one session | One cluster per session; commit between |
| Adding new behaviour during refactor | Flag for follow-up; refactor preserves behaviour |
| Inventing a "core" controller other controllers inherit from | Stimulus is composition; use outlets and events |
| Caching `querySelector` lookups in `connect()` | `static targets` are the contract |
| Hardcoding Tailwind class strings in JS during the refactor | `static classes`; designers edit ERB |

## Verification Checklist

Before declaring done:

- [ ] Baseline captured: controller count, controller LOC, Selenium spec count, runtime, pass rate
- [ ] Controller map written: every controller, purpose sentence, attachments, targets/values/outlets, listeners
- [ ] Quality audit complete per the dimensions table
- [ ] Audit plan written with one verdict per controller and rationale
- [ ] Every controller passing audit has a one-sentence purpose
- [ ] No controller exceeds ~100 lines without justification
- [ ] All controllers use `static targets / values / classes / outlets`; no `querySelector` for the controller's own elements
- [ ] State is derived from the DOM in every controller (no stranded closure variables)
- [ ] Every `connect()` listener / timer / observer has a matching `disconnect()` teardown
- [ ] Cross-controller wiring uses outlets or `this.dispatch` — no globals
- [ ] No `innerHTML = userInput`, no `eval`, no `alert()`
- [ ] Network calls use `@rails/request.js` or hand-rolled `fetch` with CSRF
- [ ] Overlay/modal controllers manage focus and toggle `aria-*`
- [ ] No ERB still references a deleted controller name, target, value, class, or outlet
- [ ] Each Stimulus behaviour has **exactly one** canonical system spec on the simplest representative page
- [ ] Redundant per-page Stimulus system specs deleted; behaviour-level coverage preserved
- [ ] `bin/rspec` is green (no new skipped/pending)
- [ ] `bin/rubocop` is green; JS lint (if configured) is green
- [ ] Selenium spec count is lower or unchanged
- [ ] Total controller LOC is lower
- [ ] Report written: counts, verdicts, coverage statement, verification status

## Subagent (optional)

This skill can be delegated to the **`pitchd-rails-implementor`** subagent at
`agents/pitchd-rails-implementor.md` when the work is scoped to a
single behaviour cluster and the parent wants to keep the main context clean.
The implementor has the writing-javascript and writing-tests skills and the
tooling to execute verdicts and verify; the parent passes the cluster, the
controller map, baseline expectations, and a pointer to this skill in the task
prompt.

For larger fleets, prefer running this skill one cluster at a time in the main
session — audit plans stay reviewable when diffs are small.

## Related

- **Writing controllers from scratch:** `../writing-javascript/SKILL.md`
  (`references/patterns.md`)
- **Hotwire wiring in templates:** `../writing-hotwire/SKILL.md`
  (`references/patterns.md`)
- **Test-writing conventions:** `../writing-tests/SKILL.md`
  (`references/system-specs.md` — Five Gates, Budget)
- **Rebalancing spec layers:** `../refactoring-rails-specs/SKILL.md`
- **Rules:** `../../rules/javascript.mdc`, `../../rules/hotwire.mdc`,
  `../../rules/testing.mdc`
- **RuboCop:** `../running-rubocop/SKILL.md`
- **Implementor subagent:** `agents/pitchd-rails-implementor.md`
- **Reviewer skill / subagent:** `../reviewing-pitchd-rails/SKILL.md`
- **Compass (only if a philosophy question surfaces):**
  `../rails-omakase-compass/SKILL.md`
