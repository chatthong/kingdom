### R43. Job-done closing actions are agent-owned — Tier 2 (v0.31.0+)

The closing checklist at task completion is **wholly the lane's responsibility**, never the user's:

1. Flip acceptance-criteria checkboxes in the project task-ledger (`TODO_Webshop.md` / `TODO_Backend.md` / `TODO_Master.csv` / `STEP.md`).
2. Update the sub-task heading suffix: append `— ✅ closed YYYY-MM-DD (PR #N)` (or `(PR #pending)` — watchman backfills the number per R27).
3. Write the task file's `## Final summary` section.
4. Run the 4-step closer (raw → curated → `master_agent.log` → sentinel).

All four land in the lane's single task commit, alongside the code change. The user's hand is on **push approval (R1)** and **dispatch decisions (R44)** — NEVER on the audit-trail flips that prove the work is done.

**King's dispatch brief MUST NOT annotate any of these as user-owned.** Forbidden brief fields:

| Forbidden text | What it really means | Fix |
|---|---|---|
| `TODO_*.md AC flip held on kingdom branch — Ter's hand` (or any `<user>'s hand` variant) | "King is leaving this for the user" | Drop the field. Worker flips at job-done. |
| `(user will tick box after merge)` | Same — passing audit-trail work to user | Drop. Watchman handles post-merge per R27. |
| `Ledger update: manual` / `manual mirror` | User is being assigned ledger maintenance | Drop. R25 says agent-owned. |
| `(human flip)` in any AC checklist | Same | Drop. |

**If a lane receives such a brief, the lane MUST reject it.** Reject template:

```
R43 violation: brief field "<exact text>" annotates agent-owned closing action as user-owned.
Re-brief required. The closing checklist (AC flip / heading suffix / Final summary / closer)
is wholly lane-owned per R43. Please re-dispatch with the annotation removed.
```

**Anti-pattern (2026-05-19 worker-1 incident):** task file header line `TODO_Webshop.md AC flip held on kingdom branch — Ter's hand`. Result: the AC flip never happened in worker-1's commit, leaked into the kingdom branch as unstaged drift, and the King later (2026-05-20 morning) read the same field and pre-emptively asked the user to "decide how to ship the AC flip" — burning 15 minutes of user time on a step that should have been silent + automatic.

**Why Tier 2 (not Tier 1):** correctness, not irreversibility. A lane that ships code but leaves the AC unflipped reads as "in progress" in the ledger even though the work merged — confusing but recoverable. The user can spot it and tell the agent to flip it. Demoted from the original Tier-1 draft per the v0.31.0 Tier-1-cap legend.

**Cross-references:** R22 (closer fires on EVERY task completion), R25 (update BOTH files in the same commit), R32 (workers don't wait — they pull; "Ter's hand" is the inverse failure where King stages user-blocking when it shouldn't).
