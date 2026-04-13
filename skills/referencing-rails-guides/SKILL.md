---
name: referencing-rails-guides
description: >-
  Load specific topics from the official Rails guides (rails/rails on GitHub)
  via two fetches: first the GitHub API directory index to discover available
  filenames, then the raw markdown for the matched guide. Never invent or
  paraphrase content as if it came from the official docs. Use when you need
  authoritative Rails API or feature documentation beyond this plugin's rules.
---

# Referencing the official Rails guides

<objective>
Pull **only the guide you need** using **two verifiable fetches**: the GitHub
API directory index to discover filenames, then the raw markdown for the
matched guide. If **any** fetch **fails** or returns unusable content, **stop**,
report what failed, and **do not** fill in from memory as if it were official docs.
</objective>

**Announce:** "I'm using the referencing-rails-guides skill."

## When to use

- You need **authoritative** Rails documentation for a specific feature or API
  (routing DSL, Active Record querying, Action Cable, etc.).
- This plugin's `rules/` and `writing-*` skills do not already answer it.
- The user explicitly asks you to consult the official Rails guides.

**Prefer first:** relevant `writing-*` skills and `rules/*.mdc` — they are the
project contract. This skill is **supplementary** official reference.

## URLs (read-only)

**Step 1 — Directory index (JSON array of all guide filenames):**

`https://api.github.com/repos/rails/rails/contents/guides/source`

Parse the JSON to extract the `name` field for each `.md` file. These are the
only valid guide filenames. Do **not** guess or infer filenames from memory.

**Step 2 — Raw guide content (replace `<file-name>` with the exact `.md` name
from the index, e.g. `routing.md`, `active_record_querying.md`):**

`https://raw.githubusercontent.com/rails/rails/main/guides/source/<file-name>`

Do **not** use the GitHub HTML UI — use **raw** URLs only.

## Process

1. **Name the topic** (e.g. "query interface", "routing constraints", "callbacks").
2. **Fetch the directory index** (Step 1) to get the current list of `.md` files.
   Skip this fetch if the index was already retrieved earlier in this conversation.
3. **Match the topic** to the single best filename from the index.
4. **Fetch that guide** (Step 2). Fetch a second guide only if the task clearly
   spans two distinct topics. Do **not** bulk-fetch guides speculatively.
5. **Cite the fetched content** when you rely on it.

## If a fetch fails (mandatory)

If either fetch errors, times out, returns an empty body, a non-200 status, or
clearly wrong content (e.g. an HTML error page instead of JSON or markdown):

- **Stop** presenting specifics from the guide.
- **Report** plainly: which URL failed and why.
- **Do not** substitute invented content, vague memory, or third-party blog posts
  as a stand-in for official docs.

You may still help using other project rules, but must **not** attribute it to
the official Rails guides without a successful fetch.

## Relationship to other skills

| Skill / layer | Role |
|----------------|------|
| `rails-omakase-compass` | Pitchd-shaped defaults and tradeoffs — consult for "whether." |
| `writing-*`, `rules/*.mdc` | **How** we ship — primary project contract. |
| `referencing-unofficial-37signals-guide` | 37signals-derived patterns and philosophy. |
| This skill | **Authoritative** Rails feature docs fetched on demand. |
