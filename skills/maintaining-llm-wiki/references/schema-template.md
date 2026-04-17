# SCHEMA starter (copy to `docs/llm-wiki/SCHEMA.md`)

Edit this file with your human partner. The agent follows it for ingest, query,
and lint discipline.

## Layout (Pitchd default)

```
docs/llm-wiki/
  SCHEMA.md          # This contract (agent + human)
  index.md           # Catalog of wiki pages
  log.md             # Append-only activity log
  raw/               # Immutable sources (agent read-only)
  pages/             # Optional: topic/entity pages (or flat — pick one)
```

Adjust `pages/` vs flat files if you prefer; document the rule here.

## Conventions

- **Links:** `[visible text](relative-path.md)` — prefer relative links inside
  the wiki.
- **Entities:** One canonical page per notable entity (person, gem, concept)
  when it appears in multiple sources.
- **Contradictions:** Note conflicting claims on both pages and, if needed, a
  short `pages/contradictions.md` hub.

## Workflows (checklist)

**Ingest:** Read source → summarize in wiki → update entity/topic pages →
update `index.md` → append `log.md`.

**Query:** Read `index.md` → open relevant pages → answer with citations.

**Lint:** Scan for stale statements, orphans, missing cross-links; append lint
results to `log.md`.

## Optional

- YAML frontmatter on pages (`tags`, `source_count`, `updated`) if you use
  Obsidian Dataview or similar.
- Attachment path for clipped images under `raw/assets/` (see original LLM Wiki
  tips).
