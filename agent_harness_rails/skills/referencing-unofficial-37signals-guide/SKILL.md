---
name: referencing-unofficial-37signals-guide
description: >-
  Load specific topics from marckohlbrugge/37signals-skills (formerly
  unofficial-37signals-coding-style-guide) via HTTP fetch of raw GitHub
  markdown only — use the README table of contents to choose paths (guide
  topics live under guide/, agent skills under skills/); fetch the minimum
  needed; if a fetch fails, stop and report (never invent or paraphrase from
  memory as if it were the guide). Use when you need external Fizzy-derived
  patterns beyond this harness’s rules and skills.
---

# Referencing the unofficial 37signals coding style guide

<objective>
Pull **only the guide files you need** from upstream using **verifiable fetches**.
Use the **README table of contents** to map a topic to a **repo-relative path**
(e.g. `guide/controllers.md`). If **any** requested fetch **fails** or returns
unusable content, **stop**, say what failed, and **do not** fill in with guesses,
general Rails advice, or remembered text **as if** it came from this repo.

> **Upstream rename:** the repo is now **`marckohlbrugge/37signals-skills`**
> (formerly `unofficial-37signals-coding-style-guide` — the old name still
> redirects). Guide topics live under **`guide/`**; it also ships agent skills
> under **`skills/*/SKILL.md`**. This harness's own rules and skills remain the
> project contract either way.
</objective>

**Announce:** "I'm using the referencing-unofficial-37signals-guide skill."

## When to use

- You need a **specific** pattern or narrative from the unofficial guide (routing,
  jobs, testing philosophy, etc.) and this harness’s `rules/` and `writing-*`
  skills do not already answer it.
- The user explicitly points you at **this** upstream reference.

**Prefer first:** `rails-omakase-compass`, relevant `writing-*` skills, and
`agent_harness_rails/rules/*.mdc` — they are the **project** contract. This skill is **optional
supplementary** reading from a third-party digest.

## URLs (read-only)

**README (table of contents for both `guide/` topics and `skills/`):**

`https://raw.githubusercontent.com/marckohlbrugge/37signals-skills/main/README.md`

**One topic file (replace `<path>` with the exact repo-relative path linked in
the README TOC — guide topics are under `guide/`, e.g. `guide/controllers.md`,
`guide/background-jobs.md`; agent skills are `skills/<name>/SKILL.md`):**

`https://raw.githubusercontent.com/marckohlbrugge/37signals-skills/main/<path>`

The former repo name (`unofficial-37signals-coding-style-guide`) still
redirects on raw URLs, but use the current name; files do **not** live at the
repo root — a root-level `controllers.md` fetch 404s.

Do **not** use the GitHub HTML UI for agents — use **raw** URLs only.

## Process

1. **Name the topic** (e.g. “Solid Queue job patterns”, “thin controllers”).
2. **Open the README** (one fetch) **or** use an already-fetched TOC in the
   conversation — map the topic to the **exact repo-relative path** the TOC
   links (`guide/<file>.md` or `skills/<name>/SKILL.md`). Do not guess paths;
   copy them from the TOC.
3. **Fetch only** that file (and **only** additional files if the task clearly
   requires a second linked topic). Do **not** bulk-fetch every file in the
   guide “just in case.”
4. **Cite behavior** from the fetched text when you rely on it; treat the
   guide as **non-authoritative** input (see Caveats below).

## If fetch fails (mandatory)

If the tool errors, times out, returns empty body, non-200 status, or clearly
wrong content (HTML error page, not markdown):

- **Stop** presenting specifics from “the guide.”
- **Report** plainly: what URL you tried, and that the content could not be loaded.
- **Do not** substitute invented guide content, vague memory, or unrelated blog
  posts as a stand-in.

You may still help with **general Rails** using other project rules — but you
must **not** claim it is from this repo without a successful fetch.

## Caveats (upstream)

The [README](https://raw.githubusercontent.com/marckohlbrugge/37signals-skills/main/README.md)
states the project is **unofficial** — derived from 37signals' public code
(Fizzy, Campfire) and discussions, not affiliated with or endorsed by
37signals — and may contain inaccuracies. **Code** snippets extracted from
Fizzy are under the [O’Saasy License](https://osaasy.dev); analysis,
commentary, and skills are **MIT**. This is **not** 37signals canon — verify
important claims against real code or official docs when it matters.

## Relationship to other skills

| Skill / layer | Role |
|----------------|------|
| `rails-omakase-compass` | omakase-shaped **defaults** and tradeoffs — read first for “whether.” |
| `writing-*`, `agent_harness_rails/rules/*.mdc` | **How** we ship in this harness — primary. |
| This skill | **Optional** single-topic fetches from the unofficial guide when needed. |
