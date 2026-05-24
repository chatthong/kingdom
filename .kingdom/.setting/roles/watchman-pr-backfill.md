# watchman-pr-backfill.md — Watchman PR-number backfill duty

> Extracted from [`watchman.md`](watchman.md) (modular reorg). See [`watchman.md`](watchman.md) for the watchman role overview, the `/loop` body, and the read-only scans.

---

## PR-number backfill duty (every tick · v0.19.0+ · per [rules.md R27](../rules/R27-watchman-owns-pr-number-backfill.md))

The worker commits TODO/CSV close-suffix as `(PR #pending)` because the PR number doesn't exist at commit time. **Watchman backfills `(PR #pending) → (PR #<N>)` on every `/loop` tick** — King never does this work.

**Scan logic (parallel by default, per [rules.md R28](../rules/R28-parallel-by-default-for-scan.md)) — calls the `parallel_edit_fanout` helper from [`_primitives.md`](../_primitives.md):**

```bash
# Build feature/<topic> → PR #N map from King's master_agent.log
declare -A PR_MAP
while IFS= read -r line; do
  feat=$(echo "$line" | grep -oE 'feature/[a-z0-9-]+' | head -1)
  prn=$(echo  "$line" | grep -oE 'PR #[0-9]+'        | grep -oE '[0-9]+' | head -1)
  [ -n "$feat" ] && [ -n "$prn" ] && PR_MAP["$feat"]="$prn"
done < "$LOGS/master_agent.log"

# Build the lane=pr spec for the helper. Lane → feature → PR resolution is
# watchman's local concern; the helper just needs <lane>=<pr> tuples.
spec=""
for lane in worker-1 worker-2 worker-3 co-worker-1; do
  feat=$(jq -r ".dispatch.$lane.feature // empty" "$LOGS/state.json" 2>/dev/null)
  [ -z "$feat" ] && continue
  pr="${PR_MAP[$feat]}"
  [ -z "$pr" ] && continue
  spec="$spec $lane=$pr"
done

# One call — handles parallel-across-branches, MERGED/CLOSED skip, amend +
# --force-with-lease, and master_agent.log line. Per-lane stdout lines reach
# the WATCH_PR_BACKFILL.md report.
parallel_edit_fanout "(PR #pending)" "(PR #${pr})" "$spec" > "$LOGS/WATCH_PR_BACKFILL.md" 2>&1
```

**On per-lane `(PR #${pr})` expansion:** the helper does literal string replace, not shell expansion, so the second argument must already encode the lane's own PR number. The wrapper above is illustrative; in practice watchman calls `parallel_edit_fanout` **once per lane** when PR numbers differ across lanes, or once collectively when the search/replace is identical (e.g. a structural footer change). The library favours the latter — different PR numbers per lane is the watchman-specific edge.

For the common case (one PR per lane), watchman fans out per-lane:

```bash
FANOUT_PIDS=""
for unit in $spec; do
  lane="${unit%=*}"
  pr="${unit#*=}"
  parallel_edit_fanout "(PR #pending)" "(PR #$pr)" "$lane=$pr" '**/*.{md,csv}' &
  FANOUT_PIDS="$FANOUT_PIDS $!"
done
# R42: bounded wait — gh + sed + git commit + git push --force-with-lease can each
# stall on network or remote refs; 45s budget covers the slowest of those × parallelism.
_bounded_wait 45 $FANOUT_PIDS
```

This is still parallel **across** lanes, with a hard ceiling so a stuck `gh pr view` or `git push` can't block the watchman tick. The helper itself is no-op-fast when a lane has nothing to flip.

**Constraints:**

- **Skip merged PRs** — `gh pr view <N> --json state -q .state | grep -q MERGED` → no force-push to closed branches (memory rule `check_pr_state_before_force_push`). Watchman opens a separate `feature/post-<N>-cleanup` branch + new PR for the orphan flips.
- **Each lane writes only to its own worktree** — no cross-lane file contention.
- **`--force-with-lease` not `--force`** — bails if remote moved since fetch.

**Side duty — stale `.lane` claim sweep:** for every `<LOGS>/done/<UTC>__<sub>-<lane>__<id>.flag` sentinel, check `<LOGS>/claims/<lane>__<task-id>.lane` — if both exist, rm the claim. Lane is then free for next dispatch.

**Side duty — kingdom-task-file checkbox audit:** on each tick, walk `.kingdom/<project>/tasks/*.md` and flag any file whose `Status` is `verifying` but whose matching sentinel exists in `<LOGS>/done/` → write to `WATCH_TASK_AUDIT.md` for King (NOT auto-flip; status is worker's responsibility per R23/R24).

This duty IS Tier 2 maintenance — failure to backfill is cosmetic, not load-bearing. King carries on without it; the TODO files just stay ugly until next tick.
