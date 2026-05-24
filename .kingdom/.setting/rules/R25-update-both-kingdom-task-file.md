### R25. Update BOTH kingdom task file AND project task-ledger — Tier 2

When a sub-task completes (closer about to fire), the worker updates **TWO** files:

**A. Kingdom task file** (per R23/R24)
- `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`
- Kingdom audit-trail home — Status flipped to `done` or `blocked`, Final summary written, checkboxes flipped.

**B. Project task-ledger** (the project's OWN tracking file)
- `TODO_*.md`, `TODO_Master.csv`, `STEP.md`, `ROADMAP.md`, or whatever the project uses as its public task source
- The sub-task's acceptance-criteria checkboxes get flipped here too
- The heading gets a close-suffix

```diff
- ### FE-P0-FOUND.7  Per-app SEO metadata
- - [ ] AC: title + description per app
- - [ ] AC: canonical URL
+ ### FE-P0-FOUND.7  Per-app SEO metadata — ✅ closed 2026-05-18 (PR #pending)
+ - [x] AC: title + description per app → 15c41f0
+ - [x] AC: canonical URL → 15c41f0
```

The project task-ledger is what the LEAD + other devs see during review; the kingdom task file is what King + the user see for orchestration. **Both must reflect the new state.**

Worker commits BOTH updates as part of its single task commit, so the kingdom task file + project-ledger flip + actual code change all land in one `worker-N` commit. Then `feature/<topic>` is carved from that tip (R9 byte-for-byte). This way the PR shows the project task-ledger flip alongside the code change, and reviewers see what got closed.

**Why both:**

| File | Audience | Purpose |
|---|---|---|
| `.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md` | King + the user + future-King | Audit-trail — multi-layer plan, progress notes, final summary |
| Project's `TODO_*.md` / CSV / `STEP.md` | Lead + team + PR reviewers | Public task source — what's claimable, what's done, what shipped |

Reading both gives complete context: kingdom file says HOW the work happened (layers, sub-agents, decisions); project file says WHAT is officially done in the team's accounting.
