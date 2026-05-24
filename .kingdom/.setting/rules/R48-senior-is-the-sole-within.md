### R48. Senior is the SOLE within-story reviewer; King never re-reviews story internals — Tier 2 (v0.32.0+)

The Senior-N that owns a story is the **only** role that reviews that story's code internals. It runs an autonomous review loop: fan out Sonnet/Haiku reviewers per touched area, synthesize as Opus, route any fix back to the owning worker, re-merge, re-review. The loop is capped at `integration.reviewLoopCap` (default 3); on exhaustion the Senior escalates the story to the human with outstanding findings rather than looping forever.

The King MUST NOT re-review the story's internals. Re-review is redundant work that adds latency and creates a "someone else caught it" gap. The King's quality concern is cross-story only (R50). This specialization is what makes pods both fast (no double-review) and high-quality (no unowned concern).
