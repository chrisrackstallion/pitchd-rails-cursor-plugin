---
name: referencing-unofficial-37signals-guide
description: >-
  Load specific topics from marckohlbrugge/unofficial-37signals-coding-style-guide
  via HTTP fetch of raw GitHub markdown only — use the README table of contents
  to choose filenames; fetch the minimum needed; if a fetch fails, stop and report
  (never invent or paraphrase from memory as if it were the guide). Use when
  you need external Fizzy-derived patterns beyond this plugin’s rules and skills.
---

# Referencing the unofficial 37signals coding style guide

<objective>
Pull **only the guide files you need** from upstream using **verifiable fetches**.
Use the **README table of contents** to map a topic to a **filename** (e.g.
`controllers.md`). If **any** requested fetch **fails** or returns unusable
content, **stop**, say what failed, and **do not** fill in with guesses,
general Rails advice, or remembered text **as if** it came from this repo.
</objective>

**Announce:** "I'm using the referencing-unofficial-37signals-guide skill."

## When to use

- You need a **specific** pattern or narrative from the unofficial guide (routing,
  jobs, testing philosophy, etc.) and this plugin’s `rules/` and `writing-*`
  skills do not already answer it.
- The user explicitly points you at **this** upstream reference.

**Prefer first:** `rails-omakase-compass`, relevant `writing-*` skills, and
`rules/*.mdc` — they are the **project** contract. This skill is **optional
supplementary** reading from a third-party digest.

## URLs (read-only)

**README (table of contents and “Quick Start”):**

`https://raw.githubusercontent.com/marckohlbrugge/unofficial-37signals-coding-style-guide/refs/heads/main/README.md`

**One topic file (replace `<file-name>` with the exact name from the README TOC,
e.g. `background-jobs.md`, `controllers.md`):**

`https://raw.githubusercontent.com/marckohlbrugge/unofficial-37signals-coding-style-guide/refs/heads/main/<file-name>`

Do **not** use the GitHub HTML UI for agents — use **raw** URLs only.

## Process

1. **Name the topic** (e.g. “Solid Queue job patterns”, “thin controllers”).
2. **Open the README** (one fetch) **or** use an already-fetched TOC in the
   conversation — map the topic to the **exact** `.md` filename listed there.
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

The [README](https://raw.githubusercontent.com/marckohlbrugge/unofficial-37signals-coding-style-guide/refs/heads/main/README.md)
states the guide is **unofficial**, partly **LLM-generated**, and may contain
inaccuracies. **Code** snippets trace to Fizzy and may be under the
[O’Saasy License](https://osaasy.dev); analysis/commentary is **MIT**. This is
**not** 37signals canon — verify important claims against real code or official
docs when it matters.

## Relationship to other skills

| Skill / layer | Role |
|----------------|------|
| `rails-omakase-compass` | Pitchd-shaped **defaults** and tradeoffs — read first for “whether.” |
| `writing-*`, `rules/*.mdc` | **How** we ship in this plugin — primary. |
| This skill | **Optional** single-topic fetches from the unofficial guide when needed. |
