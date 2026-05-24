### R27. Watchman owns PR-number backfill + close-suffix maintenance — Tier 2 (v0.19.0+)

The worker commits TODO/CSV close-suffix as `— ✅ closed YYYY-MM-DD (PR #pending)` because the PR number doesn't exist until `gh pr create` returns. **Backfilling `(PR #pending) → (PR #<N>)` is watchman's job, not King's, and runs in parallel.**

**Triggers (watchman /loop body):**

1. **Pre-merge backfill** — feature branch pushed + PR exists + content still says `(PR #pending)`:
   - Resolve mapping `feature/<topic> → PR #N` from `master_agent.log` (King logs this at push time)
   - Fan out parallel `sed -i ''` (or `rg --replace`) across ALL files containing `(PR #pending)` in the lane's worktree
   - Amend lane's tip commit + force-push (lane is the watchman's own short-lived worktree — `worker-N` itself is untouched)
   - **Skip if PR state = `MERGED`** (per memory rule `check_pr_state_before_force_push` — wasted work, branch closed)

2. **Post-merge cleanup** — `(PR #pending)` survived past merge (worker forgot, or PR number wasn't ready):
   - Open a new `feature/post-<original-pr>-cleanup` branch
   - Apply the `(PR #pending) → (PR #N)` flip + any orphaned close-suffix fixes
   - Open a "post-#N cleanup" PR (NOT amending the merged PR's already-closed branch)

3. **Stale `.lane` claim sweep** — sentinel exists in `<LOGS>/done/` + matching `.lane` claim in `<LOGS>/claims/` → release the claim (rm the file). Lane is free for next dispatch.

**Why watchman not King:** King's loop is dispatch + gate + push-approval — synchronous and sequential per-lane. Watchman's `/loop` is event-driven + read-mostly; PR-number backfill is exactly the "scan many files, flip a string, no novel decision" work it's designed for. Letting King do it sequentially while it should be planning next-round dispatch wastes the parallelism.

**Why Tier 2:** Skipping leaves cosmetic `(PR #pending)` strings in TODO files — readable but ugly. Doesn't lose data or break gates. Watchman fixes on its next tick automatically.

Helper: `watchman_backfill_pr_numbers` in [`_primitives.md`](_primitives.md) — fans out per file in parallel. See [`watchmans.md`](watchmans.md) § PR-number backfill duty.
