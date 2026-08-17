# rails-agent-harness — gem distribution + de-branding

**Status:** executed 2026-08-17. Phases 1–6 complete except the two items noted
below, which need your hand. Verification: `bin/check-references` clean (404
references, all canonical), 26 specs passing, RuboCop clean, `gem build` produces
77 files with nothing leaked.
**Date:** 2026-08-17

## Execution record — deviations from the plan as written

1. **Reference count was understated.** The plan said 214 occurrences / 51
   distinct paths, from a grep that missed `rules/` itself, the `references/`
   files, glob forms like `rules/*.mdc`, and sibling forms like
   `../writing-tests/SKILL.md`. Real scope: **404 references / 64 distinct paths**.
2. **A latent bug surfaced and was fixed.** `../../rules/testing.mdc` inside a
   skill's `references/` file resolved to `skills/rules/testing.mdc`, which never
   existed — the old resolution skill papered over it. All such forms are now
   canonical.
3. **`bin/check-references` verifies two things, not one:** that each reference
   *resolves*, and that it is *written canonically*. It classifies a path as a
   harness reference only when its first segment is `rules`/`skills`/`agents` or a
   real skill directory, so application paths like `docs/primitives/index.md` are
   correctly left alone.
4. **6.1 shipped no consumer `rubocop.yml`.** `rules/rubocop.mdc` is process
   (zero offences, never suppress), not cop configuration, and it names
   `rubocop-rails-omakase` as the ruleset source of truth — shipping a competing
   config pack would fight omakase. Instead this repo now inherits omakase for its
   own Ruby. Overrule if you want a pack shipped.
5. **An empty untracked `skills/reviewing-touched-surroundings/`** (from May) was
   removed; an empty directory under `skills/` is a loader hazard.
6. **6.4 and 6.5 left undone deliberately** — both touch things outside this repo
   (your editor config, the git remote). Commands are in the handover.

## Goal

Ship this repo as a Ruby gem named **`rails-agent-harness`** that vendors its
skills, rules, and agents into a consuming app under `rails-agent-harness/`, with
`.claude/` and `.cursor/` holding **nothing but symlinks**. Rename all
Pitchd-branded skills and agents to generic names on the way through.

Nothing the harness reads may live outside the application directory.

## Decisions taken

| # | Decision |
| --- | --- |
| D1 | Gem `rails-agent-harness`, module **`RailsAgentHarness`** in `lib/rails_agent_harness.rb` — avoids reopening the `Rails` namespace |
| D2 | **Marketplace channel removed.** Gem is the only distribution path |
| D4 | **Trust `.cursor/agents`.** No further probe; confirmed as the directory name from the Cursor app bundle |

### What D2 buys

Dropping the plugin channel removes the constraint that forced the payload to sit
at the repo root. So the payload **moves into `rails-agent-harness/` in this repo
as well**, and every internal reference gets that prefix permanently. One path
form is then correct in both places:

- in this repo: `rails-agent-harness/rules/models.mdc` resolves from the repo root
- in a consuming app: the same string resolves from the app root

That deletes, outright: the install-time rewriter, its URL-guard edge case, its
idempotency concern, `skills/resolving-plugin-root/`, both plugin manifests, both
marketplace manifests, `scripts/validate-template.mjs`, and `package.json`.
`install` becomes a copy plus five symlinks.

## Target layout in a consuming app

```
myapp/
  rails-agent-harness/
    skills/                    # FLAT — gem-owned and app-authored side by side
    rules/
    agents/
    .manifest.json             # version + sha256 of gem-owned paths
  .claude/skills        -> ../rails-agent-harness/skills
  .claude/agents        -> ../rails-agent-harness/agents
  .cursor/skills        -> ../rails-agent-harness/skills
  .cursor/agents        -> ../rails-agent-harness/agents
  .cursor/rules/harness -> ../../rails-agent-harness/rules
```

`rails-agent-harness/` is **visible, not dotted** — the app authors skills there too.

## Measured facts this plan depends on

| Fact | Status |
| --- | --- |
| `.claude/skills` + `.claude/agents` as directory symlinks | ✅ measured |
| `.cursor/skills` as a directory symlink | ✅ measured |
| `.cursor/rules/<dir>` symlink, glob attachment intact | ✅ measured |
| Cursor recurses into nested skill dirs | ✅ measured |
| **Claude Code does NOT recurse** — `<root>/<name>/SKILL.md`, one level | ✅ measured |
| Directory symlink carries a skill's `references/` | ✅ verified on disk |
| Symlinked leaf `SKILL.md` strands `references/` | ✅ verified on disk |
| `.cursor/agents` is the project agents dir | ⚠️ trusted per D4 |

Non-recursion is why vendored `skills/` is **flat**, and why `install` needs a
checksum manifest rather than a subtree it can `rm -rf`.

---

# Phase 1 — Reference checker first

Build the verifier before the refactors, so both refactors are checkable.

- [x] **1.1 `bin/check-references`** (plain Ruby, no gem skeleton yet). Scans
  `skills/`, `agents/`, `rules/` for `(\.\./)*(rules|skills|agents)/…\.(md|mdc)`,
  normalises leading `../`, and asserts each path exists. Skips any match preceded
  by a scheme or host.
  *Verify:* clean on the repo as it stands today — audited, 51 distinct paths all
  resolve. The single apparent miss is a URL fragment
  (`…/37signals-skills/main/README.md` in `referencing-unofficial-37signals-guide`),
  which is what the URL guard exists for. Break one reference deliberately; it must
  exit non-zero.

Nothing verifies this today — a typo'd reference in any of the 30 skills fails
silently at runtime.

---

# Phase 2 — Rename and de-brand

## Rename map (D3 — proposed)

Skills:

| From | To |
| --- | --- |
| `writing-pitchd-rails-plans` | `writing-rails-plans` |
| `executing-pitchd-rails-plan` | `executing-rails-plan` |
| `implementing-pitchd-rails` | `implementing-rails-task` |
| `reviewing-pitchd-rails` | `reviewing-rails-work` |

Agents:

| From | To |
| --- | --- |
| `pitchd-rails-implementor` | `rails-implementor` |
| `pitchd-rails-reviewer` | `rails-reviewer` |
| `pitchd-rails-query` | `rails-query` |
| `pitchd-rails-primitives-maintainer` | `rails-primitives-maintainer` |

Rules keep their names — already generic.

**Author metadata stays.** `author`, `email`, `homepage` are genuine attribution.

## Tasks

- [x] **2.1** Rename the four skill directories; update `name:` in each
  `SKILL.md`; sweep every `skills/<old>/` reference.
  *Verify:* `bin/check-references` clean.

- [x] **2.2** Rename the four agent files; update `name:` frontmatter; sweep
  `subagent_type` values and the 17 `agents/*.md` references.
  *Verify:* `bin/check-references` clean; no `pitchd-` remains in any
  `subagent_type`.

- [x] **2.3** De-brand prose: `rules/primitives.mdc:13` ("the **Pitchd default**
  primitives tree"), `skills/rails-omakase-compass/SKILL.md:4` ("in the Pitchd
  plugin tradition" → "in the 37signals tradition"), and the 26 files carrying the
  225 `pitchd` occurrences.
  *Verify:* `grep -ric pitchd . --include='*.md' --include='*.mdc'` returns only
  author/homepage lines.

- [x] **2.4 Delete the plugin channel.** `.claude-plugin/`, `.cursor-plugin/`,
  `scripts/validate-template.mjs`, `package.json`. Keep `assets/logo.svg` for the
  README.
  *Verify:* no JSON manifest remains outside `.claude/settings.local.json`.

- [x] **2.5 Delete `skills/resolving-plugin-root/`** and strip its 19 referencing
  preambles. With one channel and one path form there is nothing to resolve.
  *Verify:* `grep -rn resolving-plugin-root .` returns nothing;
  `bin/check-references` clean.

---

# Phase 3 — Restructure the payload

- [x] **3.1** `git mv skills rules agents rails-agent-harness/`.
  *Verify:* `bin/check-references` now fails loudly on all 214 references — that
  failure is the to-do list for 3.2.

- [x] **3.2** Prefix every internal reference with `rails-agent-harness/`,
  normalising the 12 `../../rules/…` forms to the same shape. 214 occurrences,
  51 distinct paths, four source forms collapsing to one.
  *Verify:* `bin/check-references` clean from the repo root. Update the checker's
  own scan roots in the same commit.

- [x] **3.3 Dogfood it.** Add this repo's own `.claude/skills`, `.claude/agents`,
  `.cursor/skills`, `.cursor/agents`, `.cursor/rules/harness` symlinks — the same
  five `install` will create. The repo becomes its own fixture.
  *Verify:* open this repo in both editors; every skill and agent lists, and a
  skill can open `rails-agent-harness/rules/*.mdc` with no resolution step.

Keep 3.1/3.2 as their own commits, separate from Phase 2 — a combined rename plus
move produces an unreviewable diff.

---

# Phase 4 — Gem skeleton

| File | Responsibility |
| --- | --- |
| `rails-agent-harness.gemspec` | packaging |
| `lib/rails_agent_harness.rb` | `VERSION`, `.root` |
| `lib/rails_agent_harness/cli.rb` | subcommand dispatch |
| `lib/rails_agent_harness/installer.rb` | vendor, link, manifest |
| `exe/rails-agent-harness` | executable shim |
| `Gemfile` | rspec, rubocop |

- [x] **4.1 Gemspec.** `files` includes `rails-agent-harness/**` — now a single
  visible directory with no dotfile-glob trap, since `.claude-plugin/` is gone.
  *Verify:* `gem build`, then `tar tzf` the `.gem` and confirm a `references/`
  file and a `rules/*.mdc` are both present.

- [x] **4.2 Version.** `RailsAgentHarness::VERSION` is the only version. No
  `plugin.json` parity spec — that requirement died with D2.

- [x] **4.3 Executable** with `root`, `install`, `check`, `update`, `version`.
  No Railtie — the gem must work in non-Rails repos.
  *Verify:* `bundle exec rails-agent-harness root` prints the gem's
  `full_gem_path`.

- [x] **4.4** Document consuming apps adding it to `group :development` with
  `require: false` — a tool, not a runtime dependency.

---

# Phase 5 — install / check / update

## Manifest

`rails-agent-harness/.manifest.json`, keyed by installer so a second convention
gem could vendor alongside:

```json
{ "rails-agent-harness": {
    "version": "0.2.0",
    "owns": {
      "skills/writing-models/SKILL.md": "sha256:…",
      "rules/models.mdc": "sha256:…" } } }
```

## Tasks

- [x] **5.1 `install`** — idempotent. Copies the gem's `rails-agent-harness/`
  into the app, flat under `skills/`; writes the manifest; creates the five
  relative symlinks only when absent or already correct.
  *Verify:* run twice; the second run reports no changes.

- [x] **5.2 Ownership rules.**
  - in manifest, hash matches → replace
  - in manifest, hash differs → **leave it**, report as a local override
  - absent from manifest, present on disk → **never touch**
  - about to write a path that exists and is unowned → **hard error** naming the
    collision (flat namespace, so `writing-models` can genuinely clash)
  *Verify:* a spec per branch.

- [x] **5.3 `check`** — classifies each owned path unmodified / overridden /
  missing; compares vendored version against the gem. Non-zero on missing or
  mismatch, warn on override.
  *Verify:* must catch the drift already observed in the wild — the stale
  `~/.cursor/plugins/local/pitchd-rails-cursor-plugin` clone sat at commit
  `6cd7904` while the repo was at `5e61eed`, silently serving old conventions.

- [x] **5.4 `update`** — re-vendor, print a diff summary.

- [x] **5.5 `--mode=copy`** — Windows and symlink-less filesystems get real
  directories instead of the five links. Default `link`.
  *Verify:* re-run the probe prompts against a copy-mode fixture.

---

# Phase 6 — CI and docs

- [ ] **6.1 Ship `rubocop.yml`** — SKIPPED, see execution record 4. so `rails-agent-harness/rules/rubocop.mdc`
  becomes executable: consumers add
  `inherit_gem: { rails-agent-harness: rubocop.yml }`.
- [x] **6.2 CI** — `bin/check-references`, rspec, rubocop, `gem build`, and
  `check` against a fixture app.
- [x] **6.3 README** — gem install, `install`, the five symlinks, the flat-skills
  constraint, and the **editor-explorer caveat**: both editors expand the
  symlinked container inline, so the harness appears twice in the file tree.
  Someone will try to "remove the duplicates" — document that they are one inode.
- [ ] **6.4 (yours)** Remove the stale local clone at
  `~/.cursor/plugins/local/pitchd-rails-cursor-plugin`, and uninstall the Claude
  Code plugin + its `extraKnownMarketplaces` entry, so neither editor keeps
  serving conventions from the retired channel.
- [ ] **6.5 Optional (yours):** rename the repo — `pitchd-rails-cursor-plugin` is wrong on
  both counts once this lands. Affects remotes and clone paths; your call.

---

# Open decision

**D3 — the rename map.** Phase 2's skill and agent names are my proposal, not your
instruction. Cheap now, expensive after publication. Everything else is settled.

# Verification summary

```
bin/check-references
bundle exec rspec
bundle exec rubocop
gem build rails-agent-harness.gemspec
bundle exec rails-agent-harness install --mode=link
bundle exec rails-agent-harness check
grep -ric pitchd . --include='*.md' --include='*.mdc'
```

Final acceptance: the probe prompts run against a real fixture app — both editors
list every skill and agent, and a skill can open `rails-agent-harness/rules/*.mdc`
and its own `references/` with no resolution step.
