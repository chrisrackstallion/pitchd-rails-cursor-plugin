---
name: writing-hotwire
description: >-
  Build Hotwire-first UIs — Turbo Drive, Frames, Streams, morphing,
  broadcasts, and Stimulus — with server-rendered HTML as the source of truth.
  Opinionated Rails best practice: redirect before frames before streams;
  small Stimulus controllers; no accidental SPA. Use when adding Turbo frames
  or streams, Stimulus behaviour, real-time updates, modal/inline-edit flows,
  or when front-end work drifts toward client-side routing or JSON-first CRUD
  for same-origin pages.
---

# Writing Hotwire (Turbo + Stimulus)

**Announce:** "I'm using the writing-hotwire skill."

Ship server-rendered Rails apps where Turbo handles navigation and partial updates and Stimulus handles focused DOM behaviour. The HTML the server sends is the contract — not a parallel data model in JavaScript. Progressive enhancement over client-side framework patterns.

**The rules — scope, the response hierarchy (redirect → frames → streams, 422 on failed saves), markup conventions, broadcasts, anti-patterns, and the verification checklist — live in `agent_harness_rails/rules/hotwire.mdc`.** Read it before writing or reviewing Hotwire work, and verify against its checklist.

| Task | Read |
|------|------|
| Any Hotwire change — rules and checklist | `agent_harness_rails/rules/hotwire.mdc` |
| Controller responses, frames, streams, Stimulus in ERB, morphing-friendly views, broadcasts vs synchronous responses, accidental-SPA anti-patterns | [references/patterns.md](references/patterns.md) |
| Model broadcast APIs (`broadcasts_refreshes_to`, `turbo_stream_from`, granular `broadcast_*`) | `agent_harness_rails/skills/writing-models/references/patterns.md` § Turbo Broadcasts |
| Importmap, bundlers, `application.js` wiring, Stimulus file layout | `agent_harness_rails/skills/writing-javascript/SKILL.md` |
| Tailwind / global CSS | `agent_harness_rails/skills/writing-css-tailwind/SKILL.md` |
