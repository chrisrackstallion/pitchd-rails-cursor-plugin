# Receipts

Claims about AI coding conventions are cheap; here are reproducible demonstrations. Each file
contains the exact prompt used, an honest note on how it was staged, and the unedited model
output.

| # | File | What it shows |
|---|------|---------------|
| 1a | [`01-before-no-rules.md`](01-before-no-rules.md) | Baseline: a feature request implemented by the same model with **no rules loaded**. Competent, mainstream Rails — timestamp+FK columns, `patch :archive` member routes, bang verbs, custom policy verbs. |
| 1b | [`02-after-with-rules.md`](02-after-with-rules.md) | **Same prompt, rules loaded**: state record, `Projects::ArchivalsController` noun-resource CRUD, non-bang domain verbs, CRUD-only policy, budgeted test layering — with a decision-by-decision diff table. |
| 2 | [`03-review-catch.md`](03-review-catch.md) | The **reviewer agent's unedited report** on the baseline: 14 findings, each citing the exact rule section it violates, with confidence scores and "what I read to verify this" notes — including catches beyond the headline violations (missing `index` authorize, double authorization gate, cross-layer test duplication). |
| 3 | [`04-generalisation-test.md`](04-generalisation-test.md) | **Generalisation**: a feature the rules never mention ("spotlight"). The agent transfers the principles — state record, singleton noun resource, DB-level at-most-one-row constraint — rather than pattern-matching examples. |

## How to reproduce

Every receipt includes its full prompt. Run it against any capable model twice — once bare,
once after loading `skills/rails-omakase-compass/SKILL.md` and the relevant `rules/*.mdc` —
and diff the structural decisions. To reproduce the review catch, hand any implementation to
an agent primed with `agents/pitchd-rails-reviewer.md` + `skills/reviewing-pitchd-rails/SKILL.md`.

## What these are not

Single-shot demonstrations, not a benchmark. Outputs will vary run to run — that variance is
exactly why the pipeline pairs generation rules with a review loop instead of trusting either
alone.
