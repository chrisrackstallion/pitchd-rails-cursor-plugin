---
name: running-rubocop
description: >-
  Run RuboCop until zero offences: bin/rubocop green, fix code only (no inline
  or config disables). Block and escalate rare unfixable cases. Use when
  linting Ruby/Rake, verifying before review, or the user mentions RuboCop.
---

# Running RuboCop (Rails, omakase-aligned)

**Announce:** "I'm using the running-rubocop skill."

The bar — zero offences, no inline or config suppressions, the human-owned
carve-out, full-tree `bin/rubocop` green before DONE — is
**`agent_harness_rails/rules/rubocop.mdc`**. This skill is the procedure for
clearing it.

## 1. Read the repo baseline (do not weaken it)

In the **Rails app root**, understand:

| File | Why |
|------|-----|
| `.rubocop.yml` | Ruleset and `require:` for `rubocop-rails` etc. |
| `inherit_gem` | e.g. `rubocop-rails-omakase: rubocop.yml` — **pack** vs **`rubocop-rails`** plugin, not the same thing. |
| `agent_harness_rails: rubocop-harness.yml` | Present ⇒ the app opted into the **harness cop layer**; each `AgentHarnessRails/*` cop cites the `.mdc` it enforces (`rubocop --show-cops AgentHarnessRails/ServiceObject` prints the `Reference`) — read that rule, the fix is the rule's, not a guess from the message. |

If the app has **no** RuboCop setup, do not invent one unless the **task** asks
for it. A cop switched off in the app's own `.rubocop.yml` with a reason is a
human-owned standing decision — leave it exactly as it is
(`agent_harness_rails/rules/rubocop.mdc` § The one carve-out).

## 2. Fix loop

1. **`bin/rubocop`** from the app root (fallback **`bundle exec rubocop`** only if documented and `bin/rubocop` is absent).
2. Fix each offence **in code** — autocorrect, then refactor (extract method, simplify) until the cop passes. Autocorrect order (`-a` before `-A`), scoped-vs-full runs, and the completion bar: `agent_harness_rails/rules/rubocop.mdc`.
3. Run again. Repeat until **exit 0** with **no offences**.

**Fix the finding, not the message.** A cop that goes quiet while the thing it
named is still there is a worse outcome than the offence, because the offence was
at least visible. Two the harness has actually seen:

| Cop | The dodge | The fix |
|-----|-----------|---------|
| `AgentHarnessRails/NonRestfulAction` | Route the verbs through one `show` as `params[:id]` values | A controller per noun, singular `resource` routes (`agent_harness_rails/rules/controllers.mdc`) |
| `AgentHarnessRails/UnanchoredAbsence` | Rewrite `not_to have_http_status(:forbidden)` as `expect(response.status).to be < 403` | Keep the negation; anchor it with the status the request does return (`agent_harness_rails/rules/testing.mdc`) |
| `AgentHarnessRails/UnanchoredAbsence` | Add `expect(policy).to be_a(described_class)` so the example has a positive assertion | An anchor must be able to fail. This cop does not fire on a negation the unit answers directly — if it fired, the absence is over a page or a response, and that is what needs anchoring |

If the correct fix is larger than the branch can carry, report **BLOCKED** (§3).
Do not go looking for a spelling the parser cannot see.

## 3. Rare blocker: the worked message

When an offence needs a policy call
(`agent_harness_rails/rules/rubocop.mdc` § When you cannot fix), the escalation
looks like this:

> BLOCKED — `AgentHarnessRails/NonRestfulAction` fires on every action in
> `Admin::DashboardController`, which is an RPC-shaped internal tool by
> design. Proposed, for you to add if you agree:
>
> ```yaml
> AgentHarnessRails/NonRestfulAction:
>   Exclude: [ "app/controllers/admin/**/*" ]   # Admin tools are RPC by decision.
> ```

Propose it; do not apply it. The opt-out is the human's to make.

## Related

- **The bar (binding):** `agent_harness_rails/rules/rubocop.mdc`
- **Philosophy (not lint):** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **Implementation workflow:** `agent_harness_rails/skills/implementing-rails-task/SKILL.md`
