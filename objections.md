# Objection log

Critical feedback from launch threads (HN / r/rails / X / LinkedIn), logged as fuel for future
content and rule amendments. One entry per objection — dedupe by argument, not by commenter.

**Workflow:** capture fast during launch week (source + link + strongest phrasing), triage
within a week (verdict + response), harvest monthly (essay/rule/receipt).

**Verdicts:** `CONCEDED` (they're right — fix the repo/claim) · `PARTIAL` (right about a case,
wrong about the rule) · `REBUTTED` (answered with evidence) · `OPEN` (needs work to answer —
these are the future essays).

---

## Template

### OBJ-NNN: <one-line statement of the objection, in its strongest form>

- **Source:** HN | r/rails | X | LinkedIn | other — link, date, commenter (handle only)
- **Their strongest phrasing:** > quote verbatim — steelman, don't strawman
- **Category:** proof / architecture-taste / pipeline-design / cost / stack-choice / prior-art / marketing
- **Verdict:** CONCEDED | PARTIAL | REBUTTED | OPEN
- **Response given:** link to the reply, or "none — didn't engage because …"
- **Action:** rule amendment (link commit) | new receipt | essay topic | README fix | none
- **Content potential:** none | tweet | essay section | standalone essay

---

## Pre-logged (anticipated during launch prep — confirm or retire against real threads)

### OBJ-001: "No evidence the rules change anything; models already know DHH"

- **Source:** anticipated (audit red-team)
- **Category:** proof
- **Verdict:** OPEN until receipts survive contact
- **Response given:** `docs/receipts/` — same-prompt before/after, reviewer catch report, generalisation test
- **Content potential:** essay section (receipts methodology)

### OBJ-002: "An agent can't follow 17k lines; context dilutes"

- **Source:** anticipated
- **Category:** pipeline-design
- **Verdict:** REBUTTED (by design, not by memory): glob-scoped rules, per-layer read gates, reviewer re-derives violations post-hoc
- **Content potential:** essay section — "violations don't survive the loop"

### OBJ-003: "rails_ai_agents / claude-on-rails / 37signals-skills already exist"

- **Source:** anticipated
- **Category:** prior-art
- **Verdict:** PARTIAL — they exist and are named in README/essay; the delta is reviewer-enforces-the-same-rulebook + first-hand production extraction + RSpec/Pundit stack
- **Content potential:** prior-art section already written

### OBJ-004: "Vanilla-Rails purism with RSpec and Pundit is incoherent"

- **Source:** anticipated
- **Category:** stack-choice
- **Verdict:** REBUTTED — philosophy vs tooling distinction is declared in `rules/testing.mdc` and the README; ship-what-you-battle-test
- **Content potential:** tweet-sized; already one line in README

### OBJ-005: "Production-proven is unverifiable — pitchd.ai could be a landing page"

- **Source:** anticipated
- **Category:** proof
- **Verdict:** OPEN — needs real numbers (models/policies/specs/months/catch-rate) in the HN first comment; plugin git history shows usage-feedback commits
- **Action:** fill `[NUMBER]` placeholders before launch

### OBJ-006: "The review loop is expensive theatre — what's the catch rate and token cost?"

- **Source:** anticipated
- **Category:** cost
- **Verdict:** OPEN — no measured data. Start logging: catches per task, loop iterations per task, rough token cost. Best candidate for the follow-up essay.
- **Content potential:** standalone essay ("what a week of agent review actually costs and catches")

### OBJ-007: "Where's caching / Solid Cache? Some omakase plugin"

- **Source:** anticipated (audit gap analysis)
- **Category:** architecture-taste
- **Verdict:** CONCEDED as a gap; scoped honestly in README ("on the bench")
- **Action:** write `rules/caching.mdc` + skill once battle-tested — highest-value post-launch rule
