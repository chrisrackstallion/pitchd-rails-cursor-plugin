# Prior art survey (2026-07-31)

*Research for the essay's opening section and HN defence. URLs verified at research time; star
counts approximate. This is a working doc — condense before publishing.*

## The one-paragraph version (for the essay opening)

Rails rules files are not new — the most-copied one on the internet
([cursor.directory's Rails entry](https://cursor.directory/rules/rails), ~50 lines) tells the
model to "implement service objects for complex business logic," and
[awesome-cursorrules](https://github.com/PatrickJS/awesome-cursorrules) ships a ~12-line Rails
entry saying the same. Deep encodings of the vanilla-Rails position exist exactly once:
[37signals-skills](https://github.com/marckohlbrugge/37signals-skills) (~693★), LLM-extracted
from Fizzy PRs, Minitest/fixtures-flavoured, and disclaimed by its own README as possibly
hallucinated. Rails agent teams exist:
[claude-on-rails](https://github.com/obie/claude-on-rails) (~809★) is a layer-specialist swarm
with a first-class *Services* agent and **no reviewer**;
[rails_ai_agents](https://github.com/ThibautBaissac/rails_ai_agents) (~639★) has 19 agents and
an SDD pipeline on a **layered** (service/query/presenter) architecture. And review-loop
pipelines exist generically — [Superpowers](https://github.com/obra/superpowers) and Every's
[compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) (the
latter proven on Cora, a production Rails SaaS). What doesn't exist — the gap this plugin
fills — is all four at once: a first-hand vanilla-Rails rulebook on the mainstream production
stack (RSpec + Pundit), a plan → implement → review pipeline where **the reviewer enforces the
same rulebook the implementer was given** and loops until approved, extracted from and used
daily on the author's own production SaaS, shipping as both a Cursor and Claude Code plugin.

## Claims table — what survives HN

| Claim | Verdict |
|---|---|
| "Most Rails rules files are shallow and pro-service-objects" | **Defensible** — quote cursor.directory / awesome-cursorrules verbatim |
| "First to encode vanilla-Rails philosophy for agents" | **Contestable** — 37signals-skills et al. predate. Never say it. |
| "First Rails multi-agent system" | **Indefensible** — claude-on-rails, June 2025. Never say it. |
| "First plan/implement/review loop plugin" | **Indefensible** — Superpowers, compound-engineering. Never say it. |
| "Only one proven on a production SaaS" | **Contestable** — Every's plugin built Cora. Say "extracted from and used daily on ours, with receipts." |
| "Reviewer enforces the same architectural rulebook as the implementer, in a loop, for Rails" | **Defensible** — nothing found does exactly this. This is the headline. |

**Name the neighbours preemptively** (essay + HN first comment): 37signals-skills,
claude-on-rails, rails_ai_agents, Superpowers, compound-engineering. Two are already in the
repo's credits. The deltas, precisely:

- vs **37signals-skills**: first-hand vs LLM-extracted from someone else's PRs; RSpec/Pundit
  production stack vs Minitest/fixtures purism; enforced by agents vs reference-only.
- vs **claude-on-rails**: pipeline stages vs directory-layer swarm; has a reviewer + loop vs
  none; anti-service-layer vs a first-class Services agent.
- vs **rails_ai_agents**: one opinionated architecture enforced by review vs layered
  architecture by default with vanilla as a bolt-on pack; named production app vs
  "production-ready".
- vs **Superpowers / compound-engineering**: those encode *process*, not Rails architecture —
  and this plugin credits both as ancestors. The delta is the rulebook the loop enforces.

---

## Full survey

### 1. cursor.directory Rails rules

- **URL:** https://cursor.directory/rules/rails (mirrors: cursorrules.io/rails-ruby-cursor-rules, cursorrule.com/posts/rails-ruby-cursor-rules)
- Single ~50-line "You are an expert in Ruby on Rails…" prompt by Theo Vararu. snake_case,
  "use concerns for shared behavior," "RSpec or Minitest," and **"Implement service objects
  for complex business logic."**
- Depth: shallow. Production proof: none. Pipeline: none.

### 2. PatrickJS/awesome-cursorrules

- **URL:** https://github.com/PatrickJS/awesome-cursorrules — one Rails entry
  (`rules/rails-cursorrules-prompt-file.mdc`), ~12 lines: generators, `bin/dev`, Solid suite,
  Kamal, Minitest, and *"use service objects for complex business logic."* Open issue #63 asks
  for real Rails rules.
- Other standalone repos, all shallow-to-moderate, no agents:
  [wintermeyer/cursor-rails-rules](https://github.com/wintermeyer/cursor-rails-rules) (37★),
  [cuneyter/rails_cursor_rules](https://github.com/cuneyter/rails_cursor_rules) (11 .mdc files
  incl. a services.mdc that *documents* service objects, 2★),
  [nduartex/cursor-rules-ruby-api](https://github.com/nduartex/cursor-rules-ruby-api).

### 3. HN context

- Simon Willison, "Claude Skills are awesome, maybe a bigger deal than MCP" (Oct 2025) —
  https://news.ycombinator.com/item?id=45619537 — legitimized skills-as-files; thread themes:
  skills beat prompts, **verification is the bottleneck** (our review loop speaks directly to
  this).
- "Skills are quietly becoming the unit of agent knowledge" — https://news.ycombinator.com/item?id=47475832
- cursor.directory's own Show HN (Aug 2024) — https://news.ycombinator.com/item?id=41346156 —
  pushback then: "these rules are generic."
- No dedicated HN thread found for claude-on-rails, 37signals-skills, or rails_ai_agents — the
  Rails-specific space has not had its HN moment. (Caveat: hn.algolia.com API was blocked
  during research; a low-traffic thread could exist.)

### 4. Anthropic Agent Skills ecosystem

- [anthropics/skills](https://github.com/anthropics/skills) — no Rails/Ruby skills.
- [thoughtbot/rails-audit-thoughtbot](https://github.com/thoughtbot/rails-audit-thoughtbot) —
  audit-only skill (Ruby Science / Testing Rails), no generation rules, no pipeline.
- [ombulabs/claude-code_rails-upgrade-skill](https://github.com/ombulabs/claude-code_rails-upgrade-skill) — narrow task skill.
- Marketplace singles: "Vanilla Rails Style" (mcpmarket), pproenca/dot-skills "37signals
  Rails", sergiodxa, jeffallan "rails-expert", edgarMeinart, Kavin-Kannan, Shoebtamboli,
  cole-robertson/inertia-rails-skills — all single-skill knowledge packs.

### 5. The serious prior art

**5a. marckohlbrugge/37signals-skills** (~693★, Dec 2025) — closest on *rules*. 7 skills +
`/dhh` command + ~35-topic guide extracted by Claude from 265 Fizzy PRs and 100+ DHH reviews.
Genuinely deep vanilla-Rails encoding. Deltas: LLM-extracted/second-hand with a hallucination
disclaimer in its own README; Minitest + fixtures, no RSpec/Pundit; zero agents/pipeline; no
production claim. (Also: this plugin already fetches it as a supplemental reference and
credits it.)

**5b. obie/claude-on-rails** (~809★, June 2025) — closest on *agents*. Swarm of 7
layer-specialists (Architect, Models, Controllers, Views, **Services**, Tests, DevOps) on
Shopify's claude-swarm. Deltas: no reviewer agent, no loop; layer-split not pipeline-split;
ships a Services agent with `app/services/`; no rulebook, no production claims. (Obie's
*Patterns of Application Development Using AI* book is about LLMs inside apps at runtime —
different problem, don't conflate.)

**5c. ThibautBaissac/rails_ai_agents** (~639★) — closest *composite*. 19 agents, 26 commands
incl. SDD kit (`/sdd:specify` → `/sdd:plan` → `/sdd:tasks` → `/sdd:implement` →
`/sdd:validate`), 18 skills, 14 rules, hooks. Deltas: default architecture is **layered**
(services, query objects, presenters) with 37signals conventions as an alternate bolt-on pack
(`.claude_37signals/`); review is spec-scoring + generic SOLID review, not an
implementer↔reviewer loop against one rulebook; "production-ready" ≠ named production app.
**This is the repo most likely to be pasted under the HN post — address preemptively.**

**5d. zerobearing2/rails-ai** (~41★) — Superpowers-based, 37signals philosophy, Minitest,
self-labeled EXPERIMENTAL, review inherited from Superpowers (not Rails-specific).

**5e. lucianghinda/superpowers-ruby** (~350★) — Ruby/Rails fork of Superpowers, ~30 skills,
full 7-phase pipeline with two-stage review. Deltas: explicitly Minitest/fixtures, no RSpec;
review checks plan-compliance and generic quality, not an architecture rulebook; no production
claims.

**5f. Philosophy sources:** Manrubia's "Vanilla Rails is plenty"
(https://dev.37signals.com/vanilla-rails-is-plenty/) and "A vanilla Rails stack is plenty" —
canonical texts, engage directly in the X thread. Dementyev's *Layered Design for Rails* — the
articulate counter-position; no rules artifact found from him. Evil Martians ship
[agent skills](https://evilmartians.com/agent-skills) (task packs, not an architecture
rulebook) and the "2 Martians, greenfield to MVP in 4 weeks" agentic-Rails chronicle. Rails
itself ships an AGENTS.md but DHH has said a default agents.md in generated apps would already
be outdated — the framework deliberately isn't shipping opinions here. That's the gap.

### 6. Generic review-loop pipelines

- **obra/superpowers** — 7-phase workflow, two-stage review after each task, "critical issues
  block progress." Language-agnostic. Very popular (verify star count before citing).
  Credited ancestor.
- **EveryInc/compound-engineering-plugin** (~21k★) — Plan → Work → Assess (security /
  architecture / quality review agents) → Compound. **Battle-tested on Cora, a production
  Rails SaaS** — so never claim sole production proof. Framework-agnostic process, not Rails
  architecture. Credited ancestor.
- **wshobson/agents** — subagent collection incl. code-reviewer; no enforced pipeline, no
  shared rulebook.

### 7. Ruby community coverage channels

Ruby AI News (RoboRuby, covered claude-on-rails July 2025), Short Ruby (author ships
superpowers-ruby — friendly but conflicted), RubyFlow (covered thoughtbot audit skill),
Robby on Rails, On Rails podcast (DHH on vibe coding). Ruby Weekly archives weren't directly
accessible during research — check manually before the submission.
