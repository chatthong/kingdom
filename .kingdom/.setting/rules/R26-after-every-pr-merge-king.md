### R26. After every PR merge, King resyncs kingdom from base — Tier 2 (v0.19.0+)

When `feature/<topic>` squash-merges to `develop` (or whatever `base` is in `kingdom.json`), kingdom is **stale by one commit** — King runs the resync sequence BEFORE the next dispatch round.

Post-merge state = "everything done, checked, kingdom matches develop, ready for next task." Until that resync runs, kingdom is lying about reality.

1. **Detect the merge** — `gh pr view <N> --json state -q .state` flips to `MERGED`. Log the squash SHA from `mergeCommit.oid`.

2. **Clean overlay state** — discard any uncommitted overlay on `kingdom`:
   ```bash
   git -C "$WORKTREE" switch kingdom
   git -C "$WORKTREE" reset --hard HEAD
   git -C "$WORKTREE" clean -fd
   ```

3. **Fetch + fast-forward base** — pull the new develop tip including the just-merged squash commit:
   ```bash
   git fetch origin
   git -C "$WORKTREE" switch develop
   git -C "$WORKTREE" merge --ff-only origin/develop
   ```

4. **Reset kingdom onto fresh base** — kingdom is a throwaway overlay branch; rebuild from develop tip:
   ```bash
   git -C "$WORKTREE" branch -f kingdom develop
   git -C "$WORKTREE" switch kingdom
   ```

5. **Free the merged lane + rebase remaining lanes onto new develop** — the lane whose commit JUST merged is reset to develop tip (free for new dispatch); other active `worker-N` branches get rebased:
   ```bash
   git -C "$WORKTREE" branch -f worker-<merged> develop
   # for each remaining lane with un-merged commits:
   git -C "$WORKTREE" switch worker-N
   git -C "$WORKTREE" rebase origin/develop
   ```

6. **Verify** — `git log --oneline origin/develop..kingdom` should show ONLY commits from still-open lanes, no duplicates of the merged PR. If duplicates appear, abort + investigate before re-overlaying.

7. **Log the resync** — single line appended to `<LOGS>/master_agent.log`:
   ```text
   <UTC>  KINGDOM_RESYNC  merged_pr=#246  base_advanced=abc1234..def5678  lanes_freed=worker-3
   ```

**Why Tier 2 not Tier 1:** Skipping this doesn't lose data (worktrees + branches are local), but the next overlay round starts from a stale base → King replays already-merged commits, conflicts on the next merge, wastes a gate cycle. Trigger condition: any time `gh pr view <N>` flips to `MERGED` while kingdom still points at the pre-merge develop SHA.

Helper: `kingdom_resync_after_merge` in [`functions/index.md`](../functions/index.md) wraps steps 2-7 — King calls it once per merged PR.
