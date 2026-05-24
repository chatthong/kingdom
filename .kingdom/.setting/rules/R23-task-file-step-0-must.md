### R23. Task file (Step 0) MUST exist BEFORE any sub-agent dispatch or code edit — Tier 1

Path: `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`

Lane master writes the file IMMEDIATELY after receiving a dispatch brief from King — **BEFORE** spawning any sub-agent, touching project source, or running Layer-1 grep.

Required schema:

```text
## Status        (checkboxes — planning → executing → verifying → done|blocked)
## Brief         (2-4 lines from King's dispatch)
## Plan (multi-layer)
  ### Layer 1 — Discovery       (grep + read existing patterns; R8 mandatory)
  ### Layer 2 — Strategy
  ### Layer 3 — Execution
  ### Layer 4 — Verification
## Progress notes
## Final summary  (written before closer Step 1)
```

No code edit, no sub-agent spawn, no Layer-1 grep happens before this file exists. The task file IS the audit-trail home for the task's "how it happened" narrative — without it, the work is invisible to future-King + future orchestrators.
