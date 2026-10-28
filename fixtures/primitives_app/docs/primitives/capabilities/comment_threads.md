---
status: built
intent:
  - id: I1
    clause: A reader can reply to any comment.
    evaluations:
      - spec/system/comment_threads_spec.rb
  - id: I2
    clause: Replies show nested under their parent.
    evaluations:
      - spec/system/comment_threads_spec.rb
  - id: I3
    clause: Threads never nest deeper than 3 levels.
    superseded_by: [ I4 ]
    superseded_on: 2026-09-18
  - id: I4
    clause: A reader can reply at any depth.
    evaluations:
      - spec/system/comment_threads_spec.rb
---
# Comment threads

## Shape

- Replies are `Comment` records with a `parent_id`; there is no `Thread` model.

## Provenance

- 2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md.
- 2026-09-19 — amended: I3 superseded by I4; depth cap moved to view-layer disclosure.
