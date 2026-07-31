# Launch audit — pitchd-rails plugin

*Prepared 2026-07-31 on branch `claude/rails-plugin-launch-audit-zqig2o`. Working note for the
launch — probably don't merge this directory to `main` as-is (it contains positioning strategy).*

## 1. Structure map — what's actually in the open-source plugin

| Component | Contents | Size |
|-----------|----------|------|
| `rules/` | 17 `.mdc` rules: models, controllers, routes, policies, services, testing, hotwire, views, javascript, css-tailwind, i18n, mailers, jobs, migrations, naming, rubocop, llm-wiki | ~1,830 lines |
| `skills/` | 28 skills: 16 `writing-*`/tactical skills (with 20 `references/patterns.md` deep-dives), 4 workflow skills (brainstorm → plan → execute → review), compass, 2 fetch-reference skills, refactoring skills (specs, Stimulus), wiki, rubocop, plugin-root resolution | ~5,180 lines SKILL.md + ~9,900 lines references |
| `agents/` | 4 subagent definitions: `pitchd-rails-implementor`, `pitchd-rails-reviewer`, `pitchd-rails-query`, `pitchd-rails-wiki-maintainer` | ~380 lines |
| Manifests | `.cursor-plugin/` + `.claude-plugin/` pointing at the same directories; passes cursor/plugin-template validation | — |

**Total: ~17,000 lines of conventions, workflow, and agent definitions. All of it is in the
open-source repo.** The Show HN claim is supported: the pipeline is not a private add-on — the
agent definitions, the orchestration skill, the review loop, and the report formats are all
shipped.

### The pipeline, precisely

The loop as implemented: `brainstorming-rails-omakase` (spec) → `writing-pitchd-rails-plans`
(plan, with a hard requirements gate, then a two-pass plan review **by the reviewer agent**) →
`executing-pitchd-rails-plan` (orchestrator: delegates each task to the **implementor
subagent**, then the **reviewer subagent**, loops on `Issues found` until `Status: Approved`,
then user sign-off) → optional wiki capture.

**⚠️ Wording caveat for all launch copy:** "a pipeline of four agents (planning, orchestrating,
implementing, reviewing)" is not literally what the repo ships. Planning and orchestration are
**skills executed by the main agent**; implementation and review run as **isolated subagents**
(fresh context, no chat history, `readonly: true` for the reviewer). HN will check. Say instead:
**"a four-role pipeline — plan, orchestrate, implement, review — where implementation and review
run as isolated subagents and every role loads the same rules."** That's accurate and arguably a
*better* systems story: the reviewer can't be contaminated by the implementor's context.

Also note: the four files in `agents/` are implementor, reviewer, **query**, and
**wiki-maintainer** — not planner/orchestrator. Don't let a diagram imply otherwise.

## 2. Rule depth and coherence

**Verdict: the rules genuinely encode the vanilla-Rails position; they are not vibes.** The
distinguishing test — "could a generic Rails style guide have produced this line?" — fails (in
the good sense) all over the repo:

- **State as records, not booleans** (`models.mdc`): a four-rung decision ladder (enum → state
  record → history table → state-machine gem) with the record's *existence as the state* and
  REST alignment spelled out. This is the deepest single encoding of the 37signals position in
  the repo.
- **Everything maps to CRUD** (`controllers.mdc`, `routes.mdc`, `naming.mdc`, `policies.mdc`):
  the noun-resource extraction is enforced *consistently across four layers* — routes
  (`resource :closure`), controllers (`Cards::ClosuresController#create`), policies
  (`Cards::ClosurePolicy#create?` — custom verb methods like `publish?` are explicitly banned),
  and naming. Cross-layer coherence is the plugin's strongest property.
- **Testing** (`testing.mdc` + `writing-tests` + 5 reference files): the Five Gates for system
  specs, a numeric system-spec budget table, and an "each behaviour has one home" ownership
  matrix. Falsifiable, checkable rules — exactly what an agent (and a reviewer agent) can
  enforce. The Minitest→RSpec adaptation is declared in a tooling note rather than hidden.
- **Rails 8-current**: `params.expect`, `:unprocessable_content` (not `_entity`), the Rails 8
  auth generator, Solid Queue's `config/recurring.yml` (with the "not `whenever`" call-out),
  Turbo 8 morphing nuance, strict-locals partials, `normalizes`, `Current` attributes.
- **Anti-hallucination design**: the reviewer's verification mandate (open the file, read the
  rule, drop unverifiable findings), per-finding confidence scores, and the fetch-reference
  skills' "no fetch → no citation" rule. This is the part systems-design people will respect.
- **Enforcement mechanics**: rules carry `globs` so they fire on the files being touched —
  including `services.mdc` firing on `app/services/**` (the rule against a directory activates
  when an agent tries to create it — nice touch worth a line in the essay). The implementing
  skill has a hard gate: "do not write code for a layer before reading that layer's rule."

### Weak spots found (fix or accept before launch)

1. **Phrasing tension on system specs.** `writing-pitchd-rails-plans` philosophy says "System
   spec for user-visible flows when possible" while `testing.mdc` says "the default answer to
   'add another system spec?' is no." Both defer to the budget, but a planning agent reading
   only the philosophy bullet could over-provision system specs. One-line fix in the plans
   skill ("within the writing-tests budget").
2. **Two sanctioned index-authorization styles.** `policies.mdc` allows `authorize Article` or
   `authorize @articles` ("pick one and stay consistent") — an agent has no way to know which
   was picked. The plugin's own examples consistently use `authorize Article`; consider making
   that the rule and demoting the alternative to a note.
3. **README overpromise, agent list.** README's "What's inside" says agents cover
   "implementation, review, and focused wiki maintenance" — omits `pitchd-rails-query`. Trivial;
   fixed in the README pass.
4. **Numeric thresholds as pseudo-gates.** Concern sizing ("50–150 lines", "extract at ~300
   lines") reads as hard limits to a literal-minded agent. Acceptable — but expect an HN nit.

**No blocking contradictions found.** The conflict-resolution rules (compass wins on *whether*,
tactics win on *how*; plugin rules beat application patterns, with a NEEDS_CONTEXT escape hatch
instead of silent compliance) are stated identically in the four places they appear.

### Gaps (things HN or Rails people will notice are missing)

| Gap | Severity | Note |
|-----|----------|------|
| **Caching** — no rule/skill for fragment/russian-doll caching or Solid Cache | **High** | This is *the* canonical DHH performance topic; an "omakase" plugin without a caching rule is a visible hole. Worth writing before launch, or explicitly listing as "not yet battle-tested" in the README scope note. |
| **Solid Cable / broadcasts** | Medium | Broadcasts are covered in `writing-models` references + hotwire patterns, but Solid Cable never named; jobs rule names Solid Queue only. |
| **pgvector / AI-feature patterns** | Medium | Pitch'd is an AI matching product — "where are the rules for the AI parts?" is a predictable question. Honest answer: not yet extracted/battle-tested enough to ship. Say that. |
| Active Storage, Action Text, Kamal/deploy | Low | Defensible scope cut; declare it. |

The README pass adds a scope note: *"Rules ship when they've been battle-tested in production —
caching, Active Storage, and AI-feature patterns are on the bench until then."* That converts
every gap from a hole into evidence of the shipping bar.

## 3. Red-team: the skeptical HN read

**Predicted top comment:** *"This is 17k lines of markdown telling an LLM to be DHH. Models
already trained on DHH's entire blog. Show me one example where output actually differs, and
explain why I should believe an agent follows rule 4,000 of 17,000."*

The answer has to be receipts + the scoped-loading architecture, both of which now exist —
see `docs/receipts/` and the README's pipeline section.

### The five hardest questions, and current answers

1. **"Show me it works."**
   *Answered after this branch:* `docs/receipts/` contains a same-prompt before/after (the
   baseline is competent generic Rails, which makes the diff about taste, not strawmen), a
   reviewer report catching the baseline's violations with rule citations, and a
   generalisation test on a feature the rules never mention. All prompts included,
   reproducible. Weakness to acknowledge: they're single-shot demos, not a benchmark.

2. **"An agent can't attend to 17k lines. How does this actually bind?"**
   *Answerable now, must be foregrounded:* rules attach by glob to the files being touched;
   skills load per topic via routing tables; the implementor has a hard read-before-write gate
   per layer; and the reviewer re-derives violations *from the rules* after the fact with a
   verification mandate. The claim is not "the model remembers everything" — it's "violations
   don't survive the loop." That's the essay's thesis in one line.

3. **"Vanilla Rails™ but you use RSpec and Pundit? DHH uses Minitest and hand-rolls auth."**
   *Answered in-repo* (`testing.mdc` tooling note, `policies.mdc` "Why Pundit" + dependency
   note). README pass adds the one self-aware line. Do not apologise; declare.

4. **"Production-proven — says who? I can't see Pitch'd's codebase."**
   *Currently the weakest claim.* Mitigations: (a) publish concrete numbers — resources,
   policies, spec counts, how many review-loop catches per week — even without code; (b) the
   git history of *this plugin* shows the loop feeding back into the rules
   (e.g. commit `4f39b1a`, "Incorporate plugin-usage feedback: policy gate discipline…") — cite
   it; (c) never say "production-proven" unqualified — say "extracted from and used daily to
   build a production app." **Needs real Pitch'd numbers from Chris before launch.**

5. **"Why is the review agent trustworthy? LLM judges rubber-stamp / hallucinate violations."**
   *Answered in-repo, must be surfaced:* verification mandate (read the code, read the rule,
   drop unverifiable findings), confidence scores on every finding, readonly isolation, scoped
   re-review on fix loops so it doesn't re-litigate. The review-catch receipt demonstrates the
   report format doing exactly this.

Also prepare for: "the plugin marketing a startup" (tone: builder-first, MIT, credits section
already generous), "why not just AGENTS.md" (answer: rules alone are the commodity — the
loop is the product), and "skills/rules split is confusing" (answer: rules = always-on
constraints by glob; skills = workflows loaded on demand; agents = isolated executors).

## 4. Positioning check against the repo

- **"Don't claim first" — safe.** Credits section already names Compound Engineering,
  Superpowers, and 37signals-skills as ancestors. Prior-art section of the essay does the rest.
- **"Pipeline is the headline" — supported**, with the role-vs-agent wording fix above.
- **"Real rules from a real app" — supported** by depth and by Pitchd-specific fingerprints
  (Solid Queue recurring.yml gotcha, Tailwind v3/v4 config trap, parallel_tests caveat — these
  read like scars, not blog posts). Needs the production numbers to fully land.
