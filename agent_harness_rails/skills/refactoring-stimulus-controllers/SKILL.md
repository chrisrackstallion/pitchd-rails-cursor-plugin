---
name: refactoring-stimulus-controllers
description: >-
  Audit and refactor an existing Stimulus controller fleet in a Rails app —
  merge or split against single-responsibility and coupling rules, then ensure
  one canonical system spec per behaviour (writing-tests). Use for refactoring
  Stimulus, "the Stimulus controllers are a mess", duplicate JS behaviour,
  splitting a god controller, or Stimulus spec coverage. New controllers:
  writing-javascript; server-side specs: refactoring-rails-specs.
---

# Refactoring Stimulus Controllers

<objective>
Take the existing Stimulus controllers in a Rails app and produce a clean,
harness-compliant fleet: single-purpose controllers, DOM-derived state, proper
lifecycle cleanup, no global state, and exactly one canonical system spec per
behaviour. The work is bounded and auditable: **discovery → audit → plan →
execute → cover → verify**. Coverage and behaviour are preserved; the suite is
green; controllers are smaller and fewer overall (after merges and splits net
out).

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
- The same behaviour is implemented twice under different names.
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

- **Read `agent_harness_rails/skills/writing-javascript/SKILL.md` and
  `agent_harness_rails/skills/writing-javascript/references/patterns.md`** — controller anatomy
  and quality rules.
- **Read `agent_harness_rails/skills/writing-hotwire/references/patterns.md`** § Stimulus —
  ERB-side wiring conventions.
- **Read `agent_harness_rails/skills/writing-tests/references/system-specs.md`** — the Five Gates
  and Budget rules govern which controllers get a system spec.
- **Skim `agent_harness_rails/rules/javascript.mdc` and `agent_harness_rails/rules/hotwire.mdc`** for the
  anti-pattern tables.
- **Capture a baseline and confirm the suite is green** per
  `agent_harness_rails/skills/refactoring-rails-specs/SKILL.md` § Pre-flight —
  recording **controller count and total controller LOC** alongside the spec,
  Selenium, runtime, and pass-rate numbers.
- **Confirm scope.** Refactor in **batches by behaviour**, not "everything".
  If the user said "refactor Stimulus", ask which behaviour or page to start
  with — one cluster at a time (e.g. all disclosure / reveal-style
  controllers, then all dropdown-style, then all auto-submit).

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

**Output of discovery:** the controller map plus related system specs. Read
every controller file and every related spec before changing anything.

### 3. Audit — Score Every Controller

For each controller, answer the questions and assign verdicts.

#### Responsibility audit — what does it do?

Write a **one-sentence purpose** for each controller. If you can't, that's a
finding. Good purposes:

- "Toggle a panel open/closed with `aria-expanded` syncing."
- "Copy a value to the clipboard and flash a confirmation class."
- "Debounce a form submit and request a Turbo Stream response."

Bad purposes (each is a split candidate):

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
- **REWRITE** — keep the file but bring it to harness standards (add
  `static targets`, remove closure state, fix lifecycle, etc.).
- **DELETE** — controller is unused (no `data-controller` reference) or
  duplicated by a KEEP'd controller.

**Write the audit plan to a temp file** (e.g.
`tmp/refactor-stimulus-<cluster>-plan.md`): every controller, its purpose
sentence, quality findings, and verdict with rationale. This is the artifact
the user (or reviewer) checks the final result against.

### 4. Sequence the Changes

Execute in an order that keeps the page working and the diff reviewable:

1. **One behaviour cluster per batch.** Disclosure / reveal in one pass;
   debounce + submit in another. Do not interleave.
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
   bin/rspec spec/system/articles_spec.rb  # the specs for this behaviour only
   ```
   Only the specs exercising this batch's controllers — not all of
   `spec/system/`, the slowest directory in the suite
   (`agent_harness_rails/rules/testing.mdc` § Running Specs). Green before the
   next step; if red, fix immediately.
5. **Run RuboCop on touched Ruby files** (`bin/rubocop`) — controllers are
   JS but ERB partials and spec files often co-change.

### 5. Execute the Verdicts

#### KEEP

No action; confirm tests still pass at the end.

#### REWRITE

Bring the controller to harness standards without changing public behaviour:

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

Two controllers with the same behaviour collapse into one canonical name:

1. Pick the canonical name (the one matching harness conventions; if neither,
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

A controller doing two things splits into two named controllers:

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
**`agent_harness_rails/skills/writing-tests/references/system-specs.md`** § Budget. Other usages of
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
  page; **delete** the duplicates per `agent_harness_rails/skills/writing-tests/references/system-specs.md`
  (Stimulus controllers earn at most one spec across the suite).
- **Has no spec** — write one. The simplest representative page that
  exercises the controller is the home.

#### Writing a canonical Stimulus system spec

Apply the **Five Gates** — interaction, uniqueness, JS-necessity, single-home,
one-story (`agent_harness_rails/rules/testing.mdc` § The Five Gates for System
Specs):

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
feature-rich.

#### Deleting redundant Stimulus system specs

If the same controller is exercised in three system specs, keep one and
delete the other two: the controller is canonically covered elsewhere
(single-home), and the rest of each page's behaviour belongs in lower-layer
specs (request, model, policy).

Apply the existing **`../refactoring-rails-specs`** verdicts (KEEP / MOVE /
MERGE / DELETE / REWRITE) per spec — this skill defers to that one for
non-Stimulus spec work surfaced during the audit.

### 7. Verify the End State

After all verdicts in the batch are executed:

- **`bin/rspec`** — fully green.
- **`bin/rubocop`** — zero offences.
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

Use the single-screen scaffold in
`agent_harness_rails/skills/refactoring-rails-specs/SKILL.md` § Report, with
the fleet substitutions: files touched lists **controllers (with their
verdicts), ERB partials updated, and specs**; the counts table compares
**Stimulus controllers, total controller LOC, Selenium specs, and runtime**;
verdicts include **SPLIT**; verification adds **eslint (if configured)** and
**"No ERB references to deleted controller names remain"**; the coverage
statement is "Every Stimulus behaviour has exactly one canonical system spec
on the simplest representative page."

End with one line: **"Stimulus refactor complete. Suite is green and the
fleet is harness-compliant."**

## Boundaries

- **One behaviour cluster per session.** Fleet-wide audit plans become
  unreviewable.
- **Never delete a controller without scanning every attachment.** ERB,
  view helpers that emit `data-controller`, mailers (rare), JSON responses
  embedding HTML — all candidates.
- **Selenium budget is a ceiling, not a target.** If a behaviour can be
  proved by a request spec asserting `Content-Type: text/vnd.turbo-stream.html`
  and the rendered fragment, do that — only Selenium when JS is truly
  necessary.
- **Everything else follows the session protocol** in
  `agent_harness_rails/skills/refactoring-rails-specs/SKILL.md` § Boundaries —
  never reduce coverage (an uncovered controller gets its canonical system spec
  **before** refactoring), do not change production/server-side code (a bad
  route, a missing Turbo Stream, a JSON endpoint that should be HTML: flag and
  stop), do not skip the audit plan, and stop if the suite goes red — with
  "cluster" standing in for "resource" throughout.

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
- [ ] Every controller passes the per-controller boxes of `agent_harness_rails/rules/javascript.mdc` § Verification (size, static declarations, DOM-derived state, lifecycle teardown, DOM safety, CSRF'd network calls, focus/`aria-*`, one canonical system spec per behaviour)
- [ ] Cross-controller wiring uses outlets or `this.dispatch` — no globals
- [ ] No ERB still references a deleted controller name, target, value, class, or outlet
- [ ] Redundant per-page Stimulus system specs deleted; behaviour-level coverage preserved
- [ ] `bin/rspec` is green (no new skipped/pending)
- [ ] `bin/rubocop` is green; JS lint (if configured) is green
- [ ] Selenium spec count is lower or unchanged
- [ ] Total controller LOC is lower
- [ ] Report written: counts, verdicts, coverage statement, verification status

## Subagent (optional)

Delegation follows `agent_harness_rails/skills/refactoring-rails-specs/SKILL.md`
§ Subagent, with a single behaviour **cluster** as the scope unit and the
parent passing the cluster, the **controller map**, baseline expectations, and
a pointer to this skill in the task prompt.

## Related

- **Writing controllers from scratch:** `agent_harness_rails/skills/writing-javascript/SKILL.md`
  (`references/patterns.md`)
- **Hotwire wiring in templates:** `agent_harness_rails/skills/writing-hotwire/SKILL.md`
  (`references/patterns.md`)
- **Test-writing conventions:** `agent_harness_rails/skills/writing-tests/SKILL.md`
  (`references/system-specs.md` — Five Gates, Budget)
- **Rebalancing spec layers:** `agent_harness_rails/skills/refactoring-rails-specs/SKILL.md`
- **Rules:** `agent_harness_rails/rules/javascript.mdc`, `agent_harness_rails/rules/hotwire.mdc`,
  `agent_harness_rails/rules/testing.mdc`
- **RuboCop:** `agent_harness_rails/skills/running-rubocop/SKILL.md`
- **Implementor subagent:** `agent_harness_rails/agents/rails-implementor.md`
- **Reviewer skill / subagent:** `agent_harness_rails/skills/reviewing-rails-work/SKILL.md`
- **Compass (only if a philosophy question surfaces):**
  `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
