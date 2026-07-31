# Launch plan — drafts and sequence

*Working doc. Placeholders marked `[NUMBER]` need real Pitch'd figures before anything ships —
the production claim doesn't land without them. Suggested set: models/policies/spec counts,
months in production, and a rough "reviewer catches per week."*

---

## 1. Show HN title — 5 candidates, ranked

**#1 (recommended): `Show HN: Rails agent rules with a reviewer agent that enforces them`**
Leads with the differentiator (enforcement, not rules), reads plainly, no adjectives, no
claims to defend. "Reviewer agent that enforces them" is the one thing prior art doesn't have
— the title *is* the delta. Fits HN's 80-char norm with room to spare.

**#2: `Show HN: I encoded 37signals-style Rails into agent rules, with a review loop`**
"37signals-style" is the strongest audience hook (summons the vanilla-Rails crowd and the
Hotwire diaspora) and "review loop" carries the delta. Risk: invites "you're not 37signals"
pedantry and centres the rules over the pipeline.

**#3: `Show HN: A plan → implement → review agent pipeline for Rails (no service objects)`**
Pipeline-first framing with a deliberately provocative parenthetical. "(no service objects)"
guarantees comments — which is engagement but also derails toward the architecture flamewar
instead of the systems story. Use if you want maximum comment volume and accept the topic
drift.

**#4: `Show HN: The agent rules and review loop we use to build our Rails SaaS`**
The production claim in the title. Honest and concrete, but "our Rails SaaS" spends title
space on credibility that the first comment can carry better, and it's the claim HN can't
verify from outside — inviting "says who" as the top reply.

**#5: `Show HN: Vanilla Rails conventions as Cursor/Claude plugin, enforced by agents`**
Most descriptive of the artifact, weakest as a story — "as Cursor/Claude plugin" is packaging,
not substance. Safe fallback.

**Avoid in any title:** "first", "production-proven" (unqualified), "complete", "opinionated"
(show, don't label), and model names.

## 2. First comment (posted by author immediately after submission)

> Author here. Pitch'd (pitchd.ai) is a Rails 8 B2B marketplace; I'm the technical co-founder.
> This plugin is the extracted, open-sourced version of how we actually build it — [NUMBER]
> models, [NUMBER] Pundit policies, [NUMBER] specs, in production since [DATE].
>
> The short version: rules files are the commodity, the loop is the point. The repo has ~1,800
> lines of glob-scoped rules (models, controllers, routes, policies, testing, Hotwire, …) and
> ~15k lines of skills, but no model attends to all of that at once — and the design doesn't
> ask it to. The implementor agent loads only the rules for the layers it's touching, with a
> hard gate ("don't write code for a layer before reading that layer's rule this session").
> Then a separate reviewer agent — readonly, fresh context, no shared chat history — re-derives
> violations from the rules: it has to open the cited code, re-read the rule it's citing,
> attach a confidence score, and drop anything it can't verify. `Issues found` loops back to
> the implementor until `Approved`. The claim isn't "the model remembers everything"; it's
> "violations don't survive the loop."
>
> "Show me it works" — docs/receipts/ in the repo has three reproducible demos with full
> prompts and unedited output:
> (1) the same feature request run bare vs. with rules loaded — bare gets you competent
> mainstream Rails (timestamp+FK columns, `patch :archive` member routes, custom policy
> verbs); with rules you get a state record, a noun-resource `Projects::ArchivalsController`,
> and CRUD-only policies, each decision citing its rule;
> (2) the reviewer's unedited report on the bare version — 14 findings with rule citations and
> confidence scores;
> (3) a generalisation test on a feature the rules never mention, where the principles
> transfer rather than the examples.
> These are single-shot demos, not a benchmark — the variance between runs is exactly why
> there's a review loop.
>
> Prior art, so nobody has to paste it: marckohlbrugge/37signals-skills is the deepest pure
> rules encoding (LLM-extracted from Fizzy PRs, Minitest-flavoured, no agents);
> obie/claude-on-rails is a layer-specialist swarm (no reviewer, ships a Services agent);
> ThibautBaissac/rails_ai_agents has 19 agents on a layered service-object architecture;
> Superpowers and Every's compound-engineering plugin pioneered the generic
> plan→implement→review shape and are credited in the README as ancestors. What I couldn't
> find anywhere: a reviewer that enforces the same architectural rulebook the implementer was
> given, for Rails, extracted first-hand from a production app.
>
> The stack is deliberately what we ship, not what's maximally vanilla: RSpec and Pundit with
> the 37signals testing philosophy adapted onto them. Yes, I see the irony of a vanilla-Rails
> plugin with non-vanilla test tooling — the principle is that I only publish rules I
> battle-test, and this is the stack I battle-test on. Rules for caching, Active Storage, and
> the AI features are on the bench until they'd survive the same scrutiny.
>
> Happy to answer anything — especially skeptical questions about whether agents actually
> follow rules, cost of the loop, and where it still fails.

*(Keep the "where it still fails" invitation — it pre-empts the gotcha hunt and you have real
answers from daily use. Have 2–3 failure anecdotes ready.)*

## 3. Substack essay outline

**Working title:** *Taste, enforced: encoding Rails architecture into agent rules — and making
them stick with a review loop*
**Thesis:** You can now encode Rails architectural taste into agent rules precisely enough for
a machine to apply it — but rules alone regress to the training-data mean. A reviewer agent
that enforces the same rulebook, in a loop, is what makes taste stick.

1. **Cold open — the diff.** Two implementations of "archive a project," same model, same
   prompt. Timestamp+FK+member-verbs vs. state record+noun resource+CRUD policy. "The only
   variable was 1,800 lines of markdown. Here's why that's not the interesting part."
2. **Prior art, honestly.** The commodity tier (cursor.directory recommending service objects
   in ~50 lines); the deep-rules tier (37signals-skills — genuinely good, second-hand, no
   enforcement); the agent-team tier (claude-on-rails, rails_ai_agents); the process tier
   (Superpowers, compound-engineering — credited ancestors). The empty cell in the matrix:
   *rulebook × enforcement × first-hand production use*.
3. **Why rules alone don't hold.** Training-distribution gravity: the model's prior is the
   average Rails codebase, and the average Rails codebase has a service layer. Attention
   dilution over 17k lines. Anecdotes from daily use: what the implementor still gets wrong
   *with* the rules loaded. (This section is the credibility engine — be specific.)
4. **The pipeline (the spine).** Plan (requirements gate, plan reviewed by the reviewer before
   code exists) → orchestrate (writes no code, carries context between isolated agents) →
   implement (scoped rule loading, read-before-write gate, plugin-rules-beat-app-patterns with
   a NEEDS_CONTEXT escape hatch) → review (readonly, fresh context, verification mandate,
   confidence scores, scoped re-review loop until Approved). Design principle: *violations
   don't survive the loop* — the same shape as tests + CI, applied to architectural taste.
5. **What the rules actually encode.** State-as-records ladder; everything-maps-to-CRUD across
   four layers; the system-spec budget and Five Gates; one-home-per-behaviour. Short — link
   the repo for depth. One self-aware paragraph on RSpec/Pundit.
6. **Receipts.** The before/after, the reviewer's 14-finding report, the generalisation test.
   Include the honest caveats verbatim — single-shot demos, model-graded confidence.
7. **The feedback loop eats its own tail.** Reviewer catches → rules amendments (cite real
   commits: policy gate discipline, requirements gate). The rules are downstream of the loop,
   not upstream. Pitch'd numbers here.
8. **Open problems.** Cost/latency of looping; reviewer false positives; taste vs. dogma
   (documented-exception mechanism); what happens on codebases that already violate the rules
   (application-pattern violations report); the bench (caching, AI patterns).
9. **Close:** the interesting frontier isn't better rules, it's better *enforcement
   structures*. Invitation to steal the shape for other frameworks.

## 4. Ruby Weekly submission blurb

> pitchd-rails is an open-source Cursor + Claude Code plugin encoding vanilla-Rails
> architecture — rich models, no service layer, REST noun-resources, a system-spec budget —
> as ~1,800 lines of glob-scoped rules plus a plan → implement → review agent pipeline in
> which a readonly reviewer agent enforces the same rules the implementor was given, looping
> until approved. Extracted from the codebase of Pitch'd, a production Rails 8 SaaS, and
> shipped with reproducible before/after receipts rather than claims.

## 5. r/rails post

**Title:** `I encoded "vanilla Rails" (rich models, no service layer) into agent rules — and
added a reviewer agent because rules alone kept drifting`

> Long-time lurker on the service-objects debates here. I'm CTO of a Rails 8 B2B marketplace,
> and over the past [TIMEFRAME] I extracted our conventions into an open-source Cursor/Claude
> plugin: ~1,800 lines of rules (state-as-records instead of boolean soup, everything-maps-to-
> CRUD, Pundit policies with CRUD-only methods, a hard budget on system specs) plus the agent
> pipeline that enforces them.
>
> The honest finding: **the rules file is the less interesting half.** With rules loaded, the
> implementing agent still drifts — training gravity pulls toward the average Rails codebase,
> and the average Rails codebase has `app/services/` and `post :publish`. What actually holds
> the line is a second agent: readonly, fresh context, required to re-read the rule it cites
> and attach a confidence score, looping the implementor until Approved. In the repo there's
> an unedited review report catching 14 violations in a baseline generation, with rule
> citations — plus a same-prompt before/after and a generalisation test on a feature the rules
> never mention.
>
> Stack disclosure: RSpec + Pundit, not Minitest + hand-rolled auth — I ship what I
> battle-test, and I'm aware of the irony. If you're on the Dementyev/layered side of the
> debate: the pipeline shape is architecture-agnostic — you could swap the rulebook and keep
> the loop, and honestly I'd love to see someone do it.
>
> Repo: [link]. Receipts with full prompts in docs/receipts/. Tear it apart — especially
> interested in where you think the rules are wrong, since reviewer catches literally become
> rule amendments.

*(r/rails etiquette: flair as open-source/show-and-tell, reply to every top-level comment in
the first day, don't link the Substack in the post body — someone will ask, answer in
comments.)*

## 6. X thread (vanilla-Rails debate angle)

1/ Everyone's arguing about whether vanilla Rails scales. Meanwhile I did something weirder: I
wrote the vanilla-Rails position down precisely enough that a machine can be *fired* for
violating it. Open-sourced the whole thing 🧵

2/ @jorgemanru's "Vanilla Rails is plenty" is usually read as a vibe. It's actually a spec.
"Business logic lives on models and obvious collaborators" compiles to: no `app/services/`,
state as records not booleans, custom actions become noun resources with CRUD.

3/ So that's what the rules say. Not "prefer clean code" — but "a `publish` action is
`create` on a `PublicationsController`, the policy method is `Publications#create?`, never
`publish?`, and here's the migration shape." 1,800 lines of that, glob-scoped per file type.

4/ Here's the thing nobody tells you about rules files: the model *still drifts*. Its prior is
the average Rails codebase, and the average Rails codebase has a service layer. Rules bend the
distribution; they don't pin it.

5/ What pins it: a second agent. Readonly, fresh context, one job — re-derive violations from
the rulebook. It must open the code, re-read the rule it's citing, score its own confidence,
and drop anything it can't verify. Implementor loops until Approved.

6/ Receipt: same prompt, same model. Bare → `archived_at` + `archived_by` columns,
`patch :archive` member routes, `archive?` policy verbs. Rules loaded → an `Archival` record
whose existence *is* the state, `Projects::ArchivalsController#create/#destroy`, CRUD-only
policy. [screenshot]

7/ Receipt 2: the reviewer's unedited report on the bare version. 14 findings, every one
citing the rule section it violates. Including the ones I'd have missed in code review:
`authorize` missing on `index`, a double authorization gate. [screenshot]

8/ To the layered-architecture camp (@palkan_tula's book is the best statement of it): the
pipeline doesn't care whose taste it enforces. Swap the rulebook, keep the loop. The
interesting fight isn't models-vs-services anymore — it's whether your architecture is
written down precisely enough to be enforceable.

9/ It builds our production app daily. RSpec + Pundit because that's what we ship — vanilla
architecture, non-vanilla tooling, I know, I know. Repo + receipts: [link]

*(Tag Manrubia/Dementyev handles only if genuinely engaging their published positions — done
above. Don't tag DHH; that reads as bait. 37signals diaspora will find it organically.)*

## 7. LinkedIn version (run ~3–4 days after HN)

> Our AI coding setup got torn apart on Hacker News last week — in the good way. [Or: "Last
> week I open-sourced…" if HN underperforms.]
>
> The background: at Pitch'd we build our Rails product with AI agents daily. Early on I
> learned the expensive lesson everyone learns — AI writes *average* code. Average code for
> Rails means patterns my team would reject in review. So we stopped treating code review as
> the place where taste gets applied, and made taste machine-enforceable instead:
>
> → Our architecture conventions live in ~1,800 lines of rules an agent loads per file type
> → An implementing agent builds each task under those rules
> → A separate reviewing agent — no shared context, read-only — audits the work against the
> same rules, citing chapter and verse, and the implementor loops until it's approved
>
> The result isn't "AI writes our app." It's that the *floor* of what ships rose to the level
> of our conventions, and violations get caught by a process, not by whoever's tired at 5pm.
> The reviewer catches real violations every week — and every catch becomes a rule amendment.
> The system compounds.
>
> We open-sourced the whole thing — rules, agents, pipeline, and reproducible before/after
> receipts (MIT): [link]
>
> The meta-lesson for founders: AI coding quality is a systems-design problem, not a prompt
> problem. If your standards aren't written down precisely enough for a machine to enforce,
> they were never really standards — they were habits.

## 8. One-week launch sequence

*Anchor: Show HN on **Tuesday or Wednesday, 8:30–10:00am US Eastern** (best submission window;
avoid Monday news pile-up and Friday dead zone). Calendar cleared for the day — author
comments in the first 2 hours decide the thread.*

| Day | Action |
|-----|--------|
| **T-4 to T-2 (Thu–Fri prior)** | Freeze the repo: README merged, receipts in place, `[NUMBER]` placeholders filled with real Pitch'd figures, `docs/launch/` **removed from main** (strategy docs shouldn't be public at launch). Publish the Substack essay as *unlisted/draft* so the URL exists. Dry-run both plugin installs from clean checkouts (Cursor + Claude Code) — install friction is the #2 HN complaint after unproven claims. |
| **T-1 (Mon)** | Final pass on first comment (it should read fresh, not canned). Prepare 6–8 answer stubs: cost of the loop, "agents don't follow rules", RSpec/Pundit irony, rails_ai_agents delta, 37signals-skills delta, "this is an ad", reviewer false positives, "where does it fail". Screenshot the receipts for X. |
| **Day 0 (Tue or Wed, ~9am ET)** | Submit Show HN (title #1). Post first comment immediately. Stay in-thread all day; answer everything technical, concede honest hits and log them in `objections.md`. **Do not** cross-post anywhere else today — HN punishes visible promotion loops. |
| **Day 0 evening** | Log every objection. If the thread surfaced a factual repo error, fix it same-day and say so in-thread — "fixed, commit here" is the best possible look. |
| **Day 1** | Publish the Substack essay publicly (now enriched with "what HN said" if the thread was lively). Submit to Ruby Weekly (blurb above) and Ruby AI News. Reply to any HN stragglers. |
| **Day 2** | r/rails post (draft above — adjusted for anything HN taught you). Same rule: live in the comments for the day. |
| **Day 3** | X thread, with receipt screenshots. Engage the vanilla-Rails orbit replies; quote-tweet substantive pushback rather than dunking. |
| **Day 4–5** | LinkedIn post (draft above). Founder-angle, links to essay not repo-first. |
| **Day 5–7** | Synthesis: update `objections.md` with everything collected; pick the top 2 objections and outline the follow-up essay ("What HN got right about my Rails agent pipeline"). Ship the highest-value quick fix the threads surfaced (likely: caching rule, or the plans-skill system-spec phrasing) and mention it in a follow-up tweet — visible responsiveness compounds. |

**Fallback:** if the Show HN doesn't front-page by ~2pm ET, don't resubmit the same day; a
second attempt is allowed after ~1 week with a different title (use #2). The rest of the
sequence proceeds regardless — Ruby Weekly and r/rails are the more reliable channels for this
audience anyway.
