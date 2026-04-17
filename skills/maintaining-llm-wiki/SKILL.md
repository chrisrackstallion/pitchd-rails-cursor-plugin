---
name: maintaining-llm-wiki
description: >-
  Use when curating immutable raw sources and a persistent agent-written
  markdown wiki, incremental ingest, querying compiled cross-linked knowledge,
  or wiki health passes — especially in a Rails repo where git-backed docs and
  YAGNI beat premature search infrastructure.
---

# Maintaining an LLM wiki (compounding knowledge)

<objective>
Structured markdown the agent **owns** (link, reconcile, refresh) sits between
immutable **raw** sources and chat — **plain git + markdown** in-repo until scale
demands search. Same **boring-defaults** instinct as omakase Rails, applied to
knowledge tooling.
</objective>

**Announce:** "I'm using the maintaining-llm-wiki skill."

Inspired by Andrej Karpathy's LLM wiki pattern.

## When to use

- Folding **curated sources** into a **linked wiki** (not one-shot RAG only).
- **Querying** with citations to wiki paths; **linting** contradictions, staleness, orphans.
- Choosing **index + grep** (then optional local search) before embeddings-heavy stacks.

**When not to use:** One-off summaries with no durable wiki; product specs that belong in **`writing-plans`** / app code.

## Rails + Pitchd alignment

| Idea | Reading |
|------|---------|
| Single repo | **`docs/llm-wiki/`** beside the app — versioned like code. |
| YAGNI | **`index.md`** + **`log.md`** first; add hybrid search (e.g. [qmd](https://github.com/tobi/qmd)) only when needed. |
| Boundaries | **`raw/`** agent-read-only; wiki pages agent-maintained; **`SCHEMA.md`** / **`AGENTS.md`** hold conventions. |

Rule **`rules/llm-wiki.mdc`** applies automatically when paths are under `docs/llm-wiki/`. For "where should this live?" vs app code, skim **`rails-omakase-compass`**.

## Three layers

1. **Raw** — Provenance; agent does not edit.
2. **Wiki** — Entity/topic/synthesis pages; agent updates links and contradiction notes.
3. **Schema** — Layout and workflows; co-evolve with the human. Starter: **`references/schema-template.md`**.

## Operations

| Op | Intent |
|----|--------|
| **Ingest** | Read source → update pages → refresh **`index.md`** → append **`log.md`**. |
| **Query** | Start from **`index.md`**; cite paths; file durable answers as new pages when valuable. |
| **Lint** | Stale claims, orphans, missing hubs; append notable lint to **`log.md`**. |

**`index.md`** — Catalog with one-line summaries per page. **`log.md`** — Append-only; greppable headers (e.g. `## [`).

## Quick reference

| Do | Avoid |
|----|--------|
| Edit wiki; leave **`raw/`** alone | Mutate raw to “fix” the wiki |
| Note contradictions | Silent overwrites |
| Append **`log.md`** | Knowledge only in chat |

## Common mistakes

- **RAG-only** — No wiki updates → no compounding structure.
- **Chat-only answers** — Synthesis never filed as pages.
- **Schema drift** — Moving files without updating **`SCHEMA.md`** / links.

## Delegation

Focused ingest/lint without Rails code: **`pitchd-rails-wiki-maintainer`** + paths/goals; this skill stays canonical.
