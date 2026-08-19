---
name: running-rubocop
description: >-
  Run RuboCop until zero offences: bin/rubocop green, fix code only (no inline
  or config disables). Block and escalate rare unfixable cases. Use when
  linting Ruby/Rake, verifying before review, or the user mentions RuboCop.
---

# Running RuboCop (Rails, omakase-aligned)

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
| `inherit_gem` | e.g. `rubocop-rails-omakase: rubocop.yml` — **pack** vs **`rubocop-rails`** **harness** gem. |
| `agent_harness_rails: rubocop-harness.yml` | Present ⇒ the app opted into the **harness cop layer** (below). |

**Forbidden:** adding disables or excludes in YAML to avoid fixing your code. **Do not** use or maintain **`.rubocop_todo.yml`** — fix offences, then **delete** that file. **Allowed:** editing **application code** so cops pass.

If the app has **no** RuboCop setup, do not invent one unless the **task** asks for it.

### Harness cops, and the opt-outs you must not touch

If `rubocop-harness.yml` is inherited, `AgentHarnessRails/*` offences are harness
**rule violations with a citation** — each cop names the `.mdc` it enforces
(`rubocop --show-cops AgentHarnessRails/ServiceObject` prints the `Reference`).
Read that rule; the fix is the rule's, not a guess from the message.

You may also find a cop switched **off** in the app's own `.rubocop.yml`:

```yaml
Layout/ClassStructure:
  Enabled: false            # We order models by reading flow, not macro type.
```

That is a **human-owned standing decision** (`agent_harness_rails/rules/rubocop.mdc`
§ The one carve-out). **Leave it exactly as it is** — do not re-enable it, do not
work around it, do not report it as a finding, and do not add one of your own.
If you think it is wrong, say so as a review observation and let the human decide.

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

**Fix the finding, not the message.** A cop that goes quiet while the thing it
named is still there is a worse outcome than the offence, because the offence was
at least visible. Two the harness has actually seen:

| Cop | The dodge | The fix |
|-----|-----------|---------|
| `AgentHarnessRails/NonRestfulAction` | Route the verbs through one `show` as `params[:id]` values | A controller per noun, singular `resource` routes (`agent_harness_rails/rules/controllers.mdc`) |
| `AgentHarnessRails/UnanchoredAbsence` | Rewrite `not_to have_http_status(:forbidden)` as `expect(response.status).to be < 403` | Keep the negation; anchor it with the status the request does return (`agent_harness_rails/rules/testing.mdc`) |
| `AgentHarnessRails/UnanchoredAbsence` | Add `expect(policy).to be_a(described_class)` so the example has a positive assertion | An anchor must be able to fail. This cop does not fire on a negation the unit answers directly — if it fired, the absence is over a page or a response, and that is what needs anchoring |

If the correct fix is larger than the branch can carry, report **BLOCKED** (§5).
Do not go looking for a spelling the parser cannot see.

## 5. Rare blocker

- If a cop cannot be satisfied with a **correct** fix and needs product or policy input, report **BLOCKED** (see **`implementing-rails-task`**) with cop name, offence, attempts, and what you need from the user. **Do not** merge or finish with offences or suppressions.
- When the blocker is a **harness cop that is genuinely wrong for this app** —
  not wrong for this branch — the escalation is the same **BLOCKED**, plus the
  opt-out you would propose:

  > BLOCKED — `AgentHarnessRails/NonRestfulAction` fires on every action in
  > `Admin::DashboardController`, which is an RPC-shaped internal tool by
  > design. Proposed, for you to add if you agree:
  >
  > ```yaml
  > AgentHarnessRails/NonRestfulAction:
  >   Exclude: [ "app/controllers/admin/**/*" ]   # Admin tools are RPC by decision.
  > ```

  Propose it; do not apply it. The opt-out is the human's to make.

## 6. Verification pairing

- After RuboCop is green, run **tests** as the app documents — both are required for feature work.

## 7. What this skill does not decide

- **Architecture** (REST, fat models, etc.) — **`rails-omakase-compass`** — but **lint is still mandatory** before completion.

## Related

- **Rule (short):** `agent_harness_rails/rules/rubocop.mdc`
- **Philosophy (not lint):** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **Implementation workflow:** `agent_harness_rails/skills/implementing-rails-task/SKILL.md`
