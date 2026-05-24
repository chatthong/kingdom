### R32. "Staged / waiting / dormant" is co-worker-ONLY — workers auto-claim — Tier 2 (v0.24.0+)

Per-role idle behaviour:

| Role | Idle behaviour |
|---|---|
| 👷 **Worker** | **Auto-claim** from queue per `king.md` § Lane utilisation. If queue empty, lane shows `🐾 Idle` but King keeps polling for new pending tasks (Step 5c of `/kingdom:work` poll loop). Worker NEVER sits "awaiting your dictation". |
| 🧑‍💼 **Co-worker** | **Dormant by default.** Activates only when user says `pair on co-worker-N`. Shows `💤 staged · awaiting pair-on signal`. This is the ONLY role where "waiting for user input" is correct. |
| 🕵️ **Watchman** | **Always runs `/loop`.** Never idle, never waiting. Dynamic-pacing (5-15 min) means it's "asleep until next tick" — that's different from "waiting on user." |

**Anti-pattern:** chat shows `worker-1 awaiting your dictation` or `worker-2 staged · waiting for direction`. Both are bugs. Workers don't wait — they pull. If no task fits worker-1's slot, dispatch it the next-best one, or mark it `🐾 idle (no claimable task)` and re-poll on the next cycle.

**The morning of 2026-05-19 incident:** King treated worker-1 like a co-worker, "pausing" for user direction on scope decisions instead of dispatching it the task with the brief and letting Layer-2 Strategy happen inside the lane. That's R32 violation + R30 violation simultaneously.
