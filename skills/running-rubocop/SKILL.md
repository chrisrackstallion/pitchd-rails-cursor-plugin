---
name: running-rubocop
description: >-
  Run RuboCop until zero offences: bin/rubocop green, fix code only (no inline
  or config disables). Block and escalate rare unfixable cases. Use when
  linting Ruby/Rake, verifying before review, or the user mentions RuboCop.
---

# Running RuboCop (Rails, omakase-aligned, DHH-shaped context)

<objective>
Make **`bin/rubocop`** pass with **no offences** — by **correct code changes**
only. Do not use **`# rubocop:disable`**, or cop
**`Enabled: false` / `Exclude:`** in config to paper over problems. Treat a
green run as a **gate** for completion (alongside tests), not as proof of
architecture — that stays in **`rails-omakase-compass`**.
</objective>

**Announce:** "I'm using the running-rubocop skill."

## When to use

- Whenever you touch Ruby/Rake and the app uses RuboCop.
- Before claiming **DONE** or **ready for review** — **full `bin/rubocop` green** (see below).
- When CI or the user reports RuboCop failures.

## 1. Read repo baseline (do not weaken it)

In the **Rails app root**, understand:

| File | Why |
|------|-----|
| `.rubocop.yml` | Ruleset and `require:` for `rubocop-rails` etc. |
| `inherit_gem` | e.g. `rubocop-rails-omakase: rubocop.yml` — **pack** vs **`rubocop-rails`** **plugin** gem. |

**Forbidden:** adding disables or excludes in YAML to avoid fixing your code. **Do not** use or maintain **`.rubocop_todo.yml`** — fix offences, then **delete** that file. **Allowed:** editing **application code** so cops pass.

If the app has **no** RuboCop setup, do not invent one unless the **task** asks for it.

## 2. Entrypoint (match CI)

- **`bin/rubocop`** from app root; fallback **`bundle exec rubocop`** only if documented and `bin/rubocop` is absent.

## 3. Completion bar: zero offences

- **Before DONE / ready for review:** run **`bin/rubocop`** so it exits **0** with **no offences** reported.
- Default: **full project** (`bin/rubocop` with no file list). If CI only lints a subset, match **that** documented command — when in doubt, **whole tree**.
- You may use **scoped** runs while iterating; the **completion** check is **green everywhere** the project requires.

## 4. Fix strategy

- **`bin/rubocop -a`** / **`--autocorrect`** first.
- **`-A`** / **`--autocorrect-all`** only when you review the diff and accept behaviour (some Rails cops need care).
- **Metrics** and similar: **refactor** (extract method, simplify) until the cop passes — do not disable the cop.
- **No** inline RuboCop directive comments. **No** config-based suppression for new work.

## 5. Rare blocker

- If a cop cannot be satisfied with a **correct** fix and needs product or policy input, report **BLOCKED** (see **`implementing-pitchd-rails`**) with cop name, offence, attempts, and what you need from the user. **Do not** merge or finish with offences or suppressions.

## 6. Verification pairing

- After RuboCop is green, run **tests** as the app documents — both are required for feature work.

## 7. What this skill does not decide

- **Architecture** (REST, fat models, etc.) — **`rails-omakase-compass`** — but **lint is still mandatory** before completion.

## Related

- **Rule (short):** `../../rules/rubocop.mdc`
- **Philosophy (not lint):** `../rails-omakase-compass/SKILL.md`
- **Implementation workflow:** `../implementing-pitchd-rails/SKILL.md`
