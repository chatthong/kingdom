### R30. King is ORCHESTRATOR ONLY — never executes task work itself — Tier 1 (v0.24.0+)

**Allowed King verbs:** plan-the-day, dispatch (`cmux send`), gate-fire (`run_tier1_gate` / `run_tier2_gate`), overlay onto kingdom, request push approval, read audits.

**BANNED King verbs:**

- Write or edit project source code
- Make scoping decisions in chat ("Admin dropped from FE-P0-FOUND.5", "Batch 1: dev_data.sql + ...", etc) — scoping happens in the **task file** written by the lane, not in chat
- Run gates manually for a lane (lane's Tier-1 fires inside the lane's worktree)
- Draft "Worker-N plan (final)" multi-batch tables in chat — that's a lane's `## Plan` section in its task file
- Pause to "brainstorm" implementation details with the user — those decisions belong in the lane's Layer-2 Strategy after dispatch

**Incident that motivated this rule (2026-05-19):** a King session spent ~1m48s "Crunched" drafting a 9-batch execution plan for `FE-P0-FOUND.5` in chat — files to touch, scope decisions (admin in/out), AC flip targets, verification steps — instead of dispatching to worker-1. Zero tasks completed in the session. Cause: King was acting as worker. Fix: this rule, plus R31 (verify lanes exist before dispatch) and R32 (workers don't "wait").

**Hard time budget:** from `/kingdom:work` Step 4 reaching auto-dispatch, **no more than 60 seconds** elapses before the first `cmux send` fires to a worker. If King exceeds 60s of "planning in chat" between audit-done and first dispatch, that's a violation — re-read this rule and dispatch with whatever plan exists.

**Delegated dispatch (v0.32.0+).** The orchestrator-only principle now also governs **Seniors** (see [`seniors.md`](seniors.md), R46-R50). For a story pod, the King delegates per-story orchestration to a Senior-N. Both roles are orchestrators, not executors: neither writes feature code. The dispatch chain becomes:

- The King dispatches to **Seniors** (assigns a story) and to **solo workers** (non-pod tasks).
- A **Senior** dispatches only to the workers in **its own pod**, and only through a **visible** lane workspace, enforced by `guard_senior_dispatch_scope` (refuses out-of-pod targets and targets without a live workspace, preserving the R31/R36/R37 visibility guarantees this rule depends on).
- A Senior additionally **merges** worker branches into the story branch and **reviews** the assembled story (R48/R49). Merge + review are integration/review work, not feature execution, so they do not violate orchestrator-only.
- **Workers never dispatch.** A worker belongs to at most one pod at a time.

This relaxes the "King is the sole dispatcher" reading while keeping the property R30 exists to protect: no work happens invisibly outside a tracked, visible workspace. Tier 1 count stays 10 (R30 amended in place, no new Tier-1 rule).
