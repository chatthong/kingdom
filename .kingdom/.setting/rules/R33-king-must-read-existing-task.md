### R33. King MUST read existing task state BEFORE dispatching new tasks — Tier 1 (v0.25.0+)

At session start (per R14) and at every `/kingdom:work` Step 4 dispatch round, King MUST scan existing task state and **resume in-flight work before opening any new task file**.

**Pre-scan (v0.31.0+ — mandatory before reading task files):** task files are frozen snapshots; if `origin` advanced overnight via merge or recovery PR, the resume queue built from disk alone will offer to "resume" work that's already shipped. Three commands run FIRST:

0.a. **`git -C <project> fetch origin --prune`** — pull all remote refs and prune deleted ones. Mandatory; cheap (~1s).
0.b. **`gh -R <repo> pr list --state merged --limit 30 --json number,headRefName,mergedAt`** — cache the recent merge log.
0.c. **For each lane worktree:** compare its branch's tip commit against `origin/${BASE}`. Three outcomes:
   - **Equivalent work merged** (lane's commit message subject or PR title appears in the merged-PR log, including `recovery/pr-<N>-*` recovery branches) → mark the task **obsolete (shipped)**, surface in the `resume-queue` card as a CLEANUP candidate, not a resume candidate. Lane needs `worktree remove` + branch FF to base, not re-dispatch.
   - **Lane base is an ancestor of `origin/${BASE}` but lane commit is NOT on develop** → genuine in-flight work; proceed to resume-queue classification below.
   - **Lane base diverged from `origin/${BASE}`** → flag as `needs rebase`, surface in decision queue.

Then proceed with the disk scan:

1. **`ls -t .kingdom/<project>/tasks/*.md`** — newest first.
2. For each task file: read `## Status` checkboxes. Classify:
   - `done` / `cancelled` → ignore.
   - `planning` / `executing` / `verifying` (no matching sentinel in `<LOGS>/done/`) → cross-reference with the 0.c outcome:
     - if lane marked **obsolete (shipped)** → move to **cleanup queue**, NOT resume queue.
     - otherwise → **resume queue**.
   - `blocked` → **decision queue** (lane needs user input or dependency resolution).
3. **Resume queue takes priority over new dispatch.** Lanes already in-flight get re-briefed with `[RESUME]` flag + same task ID + their last `## Progress notes` line. NEVER open a fresh task file for a lane that already has an in-flight one.
4. **Decision queue items get surfaced in the `suggested-task` card** with `→ Unblock <task-id>` as a candidate so the user can resolve before new work loads.
5. **Cleanup queue items** are surfaced with `→ Discard obsolete lane <lane>` (per R5 destructive-op rules) so the user can confirm before `worktree remove` + branch reset. NEVER auto-discard.
6. Only AFTER resume + decision + cleanup queues are addressed does Step 4 auto-dispatch reach for new tasks from the project ledger.

**Render** the `resume-queue` card (new in v0.25.0) right after `daily-status` if any in-flight task files exist.

**Anti-pattern (1):** King ignores `.kingdom/<project>/tasks/2026-05-19T0353Z__worker-1__FE-P0-FOUND.5.md` (status: discovery-complete, 2 soft blockers), starts drafting a fresh dispatch for worker-1 from scratch. Now worker-1 has TWO task files for overlapping work, the old one rots, sentinels mismatch, audit-trail corrupts.

**Anti-pattern (2 — v0.31.0):** King reads the on-disk task file, sees "executing — smoke test pending" on worker-1, builds a resume queue from disk alone, offers the user "resume worker-1 + run smoke test." Meanwhile `origin/develop` already shipped the work via `recovery/pr-262-consent-banner` 8 hours earlier. Re-running smoke + opening a new PR would create a duplicate of the merged commit → conflict → recovery-PR cycle #3. Skipping the 0.a/0.b/0.c pre-scan = repeating the same incident every morning until the user manually pulls.

**Why Tier 1:** ignoring in-flight task files = orphaning real work + duplicating effort + confusing the audit trail. Re-shipping already-merged work = conflict storm + recovery-PR cycle. This is correctness, not cosmetic.

**Incident #1 that motivated this rule (2026-05-19):** King session greeted user with "Suggested next tasks:" candidates pulled from the project ledger, while `.kingdom/bfg-swt/tasks/` had a worker-1 task file from the morning with Status=discovery-complete waiting on 2 user-decision blockers. The right behaviour: open with "Resume worker-1 FE-P0-FOUND.5? Two blockers need your call: A=<X> B=<Y>" — that's both decision-queue item + resume candidate in one prompt. King missed it entirely because R14 read-order didn't enforce reading task state, only meta-state (memory, watchman state, README).

**Incident #2 that motivated the v0.31.0 pre-scan addition (2026-05-20):** Morning `/kingdom:work bfg-swt cap=5` session. King read worker-1 + worker-3 task files (both `executing — smoke test pending`), built a resume queue, drafted a "ship the dependency chain" plan, asked for go. User asked "did you cross check task ledgers?" — that triggered a `git fetch` and the truth came out: both PRs had already shipped to `origin/develop` 8 hours earlier via `recovery/pr-262-consent-banner` and `recovery/pr-266-admin-activation`. Local kingdom was 9 commits behind. 0 jobs shipped that morning — entire session spent chasing ghosts. Root cause: R33 required reading task files but not fetching first. Fixed in v0.31.0 by adding 0.a/0.b/0.c pre-scan.
