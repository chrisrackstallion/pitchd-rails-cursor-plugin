---
name: maintaining-harness
description: >-
  Change this harness repo itself — payload skills, rules and agents, the
  AgentHarnessRails cops, the installer, and what the gem ships. Use when
  editing anything under agent_harness_rails/, adding or changing a cop, or
  altering packaging. Not for Rails application work: the payload's own skills
  cover that.
---

# Maintaining the harness

**Announce:** "I'm using the maintaining-harness skill."

<objective>
Land a requested change to this repo so it is **discoverable** by both editors,
has **exactly one home**, and is held by a **check** rather than by prose.
</objective>

Not shipped: `AgentHarnessRails::DEV_ONLY` in `lib/agent_harness_rails.rb` drops
this skill from the gem and from `install`. A further dev-only path goes in that
list *and* in the gemspec's matching reject — `spec/gem_spec.rb` asserts the two
agree.

## Where the change goes

| Change | Home |
|---|---|
| A bar — what must be true of application code | `agent_harness_rails/rules/*.mdc` |
| A procedure for clearing a bar | `agent_harness_rails/skills/*/SKILL.md` |
| A commitment every workflow shares | `agent_harness_rails/rules/harness-contract.mdc` |
| Whether a solution shape is omakase at all | `agent_harness_rails/skills/rails-omakase-compass/SKILL.md` |
| A template, or an example too long to inline | `agent_harness_rails/skills/*/references/*.md` |
| A subagent's role, tools, and prompt contract | `agent_harness_rails/agents/*.md` |
| Machine-checkable enforcement of a bar | a cop — § Prefer a check to prose |
| Consumer-facing behaviour | `README.md`, and `CHANGELOG.md` under `## [Unreleased]` |

`lib/agent_harness_rails/version.rb` moves at release time, not per change:
`check` compares it against the version in a consuming app's manifest.

**One home, cited from everywhere else.** State a bar once in its rule file;
every skill that needs it links the path and keeps only its own role-specific
consequence (`agent_harness_rails/rules/harness-contract.mdc`). Two copies
diverge, and an agent reads the stale one. Before adding a paragraph, grep for
it — if it already exists, link it.

## Authoring constraints

- **Skills stay flat.** Claude Code discovers exactly `skills/<name>/SKILL.md`
  and does not recurse, so a skill one level deeper is silently invisible.
  Depth is what `references/` is for.
- **Frontmatter is the discovery surface.** `name` must equal the directory —
  or, for an agent, the filename — because a name that does not match is a name
  that cannot be invoked. A `description` carries both *what* and *when*; it is
  the only text loaded before the skill fires.
- **Rules are Cursor-shaped:** `description`, `globs` matching the application
  paths governed, and `alwaysApply: false`. Only `harness-contract.mdc` always
  applies.
- **References are root-relative from the app root** —
  `agent_harness_rails/rules/models.mdc`, never a `../` hop up from the citing
  file. The same string has to resolve in this repo and in a consuming app, and
  `bin/check-references` fails on the relative form.
- **Write to `agent_harness_rails/`, never through `.claude/` or `.cursor/`.**
  Those hold only symlinks, and git cannot stage a path through one.

## Prefer a check to prose

A rule a parser can settle belongs in a cop, not in a paragraph an agent may
skim. **A new cop touches four places:** the cop under
`lib/rubocop/cop/agent_harness_rails/`, its defaults in `config/default.yml`
(`Description`, `VersionAdded`, `Reference` naming the `.mdc` it enforces, and
`Include` scoping it by path rather than in Ruby), an entry in the matching
`rubocop-harness*.yml` layer, and coverage in `spec/cops/`. A cop needing
project-wide context belongs in `rubocop-harness-index.yml`.

When a cop cannot see the concern, take the next-cheapest gate before prose:

| Concern | Gate |
|---|---|
| An internal harness path is typo'd or not root-relative | `bin/check-references` |
| Payload frontmatter, naming, or layout is malformed | `spec/payload_spec.rb` |
| A new file must ship, or must not | `spec/gem_spec.rb` |
| Installer or CLI behaviour | `spec/installer_spec.rb`, `spec/cli_spec.rb` |
| A packaged install actually works | the fixture install in `.github/workflows/ci.yml` |

`.rubocop.yml` excludes `agent_harness_rails/**/*`, so the payload has no linter
and `spec/payload_spec.rb` is its only mechanical gate — widen that spec rather
than adding a second one.

Judgment stays prose: whether a bar is right, whether a paragraph duplicates
another. Name the judgment in the change instead of inventing a check that will
be noisy and then routed around.

## Ruby in this repo

A gem, not a Rails app — there is no `app/`, so most payload rules do not apply.
Those that do: `agent_harness_rails/rules/comments.mdc` (its globs include
`lib/**/*.rb`), `agent_harness_rails/rules/rubocop.mdc` for the linter bar, and
for specs `agent_harness_rails/rules/testing.mdc` § Where New Coverage Goes and
§ A task receipt is not a spec. `spec/spec_helper.rb` hands every example a
fresh project directory to install into.

## Verify

```bash
bin/check-references && bundle exec rake
```

`rake` runs the specs then RuboCop; both clean, no exceptions. Then read the
diff back: every new path resolves, every bar has one home, and the
`## [Unreleased]` entry says what a consumer gets.

## Related

- **Shared commitments (binding):** `agent_harness_rails/rules/harness-contract.mdc`
- **What the payload asks of application code:** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **An app's primitives tree, not this repo:** `agent_harness_rails/skills/maintaining-primitives/SKILL.md`
