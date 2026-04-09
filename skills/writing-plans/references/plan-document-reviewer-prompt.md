# Plan document reviewer prompt

Use this template when dispatching a **plan document reviewer** (subagent or
colleague) **after** the implementation plan is written.

**Purpose:** Confirm the plan is complete, matches the spec, decomposes into
executable tasks, and does not bake in **Rails anti-patterns** this plugin
rejects.

**Inputs:** Plan file path, spec or requirements path.

```
Task tool (general-purpose) or human review:
  description: "Review Rails implementation plan"
  prompt: |
    You are reviewing an implementation plan for a Rails app that follows
    Pitchd Rails plugin conventions (DHH/37signals-style: fat models, REST,
    Pundit, Hotwire, RSpec/FactoryBot per writing-tests).

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to check

    | Category | What to look for |
    |----------|------------------|
    | Completeness | TODOs, placeholders, missing steps, undefined methods or policies |
    | Spec alignment | Requirements covered; no unjustified scope creep |
    | Task decomposition | Vertical slices, clear boundaries, runnable checkpoints |
    | Buildability | Could an implementer follow this without guessing paths or helpers? |
    | Rails / plugin fit | No unnecessary service layer; REST-first routes; Pundit where needed; Hotwire escalation order; one home per behaviour in tests (`rules/testing.mdc`, `skills/writing-tests/SKILL.md`) |
    | Test choice | System vs request vs model vs policy matches the writing-tests decision tree; no duplicate coverage across layers |

    ## Rails red flags (fail or request revision)

    - New `app/services/*` that only wrap Active Record without `rules/services.mdc`-level justification
    - RPC routes where a resource or `update` would suffice (`rules/routes.mdc`)
    - Missing `authorize` / `policy_scope` when controllers or records change (`rules/policies.mdc`)
    - Plans that jump to Turbo Streams before simpler redirect/frame options (`rules/hotwire.mdc`, `rules/controllers.mdc`)
    - Same behaviour tested in system + request + model without clear split of concerns

    ## Calibration

    **Only flag issues that would cause real problems during implementation** —
    wrong feature, stuck implementer, or likely regression. Minor wording or style
    alone is not enough to block.

    Approve unless there are serious gaps: missing requirements, contradictory
    steps, placeholder content, vague tasks, or plugin-convention violations that
    would force a rewrite mid-flight.

    ## Output format

    ## Plan review

    **Status:** Approved | Issues found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] — [why it matters]

    **Recommendations (advisory):**
    - [improvements that do not block approval]
```

**Reviewer returns:** Status, issues (if any), recommendations.
