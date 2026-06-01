#!/usr/bin/env bash
# kingdom function: kingdom_resync_after_merge

kingdom_resync_after_merge () {
  local merged_pr="$1" merged_lane="$2"   # e.g. 246, worker-3
  local before after

  before=$(git -C "$WORKTREE" rev-parse origin/"$BASE")

  # Step 1: clean overlay state on kingdom (drop any uncommitted overlay)
  git -C "$WORKTREE" switch kingdom 2>/dev/null
  git -C "$WORKTREE" reset --hard HEAD
  git -C "$WORKTREE" clean -fd

  # Step 2: fetch + fast-forward base
  git -C "$WORKTREE" fetch origin
  git -C "$WORKTREE" switch "$BASE"
  git -C "$WORKTREE" merge --ff-only "origin/$BASE" || {
    echo "❌ $BASE diverged from origin/$BASE — manual recovery needed"
    return 1
  }
  after=$(git -C "$WORKTREE" rev-parse origin/"$BASE")

  # Step 3: reset kingdom onto fresh base
  git -C "$WORKTREE" branch -f kingdom "$BASE"
  git -C "$WORKTREE" switch kingdom

  # Step 4: free the merged lane (its commit just landed)
  git -C "$WORKTREE" branch -f "$merged_lane" "$BASE"

  # Step 5: rebase remaining active lanes onto new base.
  # Rebase INSIDE each lane's own worktree. `git -C "$WORKTREE" switch <lane>`
  # fails (rc=128 "already used by worktree at …") when that branch is checked
  # out in a .worktrees/<lane> linked worktree — the normal kingdom layout — and
  # the unguarded switch would then leave the main worktree rebasing the WRONG
  # branch (silently corrupting kingdom). Operate on the lane's worktree directly.
  local lanes_freed="$merged_lane" lane lane_wt
  for lane in $(git -C "$WORKTREE" branch --list 'worker-*' | tr -d ' *'); do
    [ "$lane" = "$merged_lane" ] && continue
    [ -z "$(git -C "$WORKTREE" log "$BASE..$lane" 2>/dev/null)" ] && {
      git -C "$WORKTREE" branch -f "$lane" "$BASE"
      lanes_freed="$lanes_freed,$lane"
      continue
    }
    lane_wt="$WORKTREE/.worktrees/$lane"
    if [ -d "$lane_wt" ]; then
      git -C "$lane_wt" rebase "origin/$BASE" || {
        echo "⚠️ rebase conflict on $lane (in $lane_wt) — resolve manually, then re-run resync"
        return 1
      }
    else
      # No linked worktree for this lane → safe to switch + rebase in main worktree.
      git -C "$WORKTREE" switch "$lane" && git -C "$WORKTREE" rebase "origin/$BASE" || {
        echo "⚠️ rebase conflict on $lane — resolve manually, then re-run resync"
        return 1
      }
    fi
  done

  # Step 6: verify kingdom shows ONLY open-lane commits
  git -C "$WORKTREE" switch kingdom
  echo "📋 kingdom..origin/$BASE delta (should be empty — no duplicates):"
  git -C "$WORKTREE" log --oneline "origin/$BASE..kingdom" || true

  # Step 7: log resync line
  printf '%s  KINGDOM_RESYNC  merged_pr=#%s  base_advanced=%s..%s  lanes_freed=%s\n' \
    "$(date -u +%FT%TZ)" "$merged_pr" "${before:0:7}" "${after:0:7}" "$lanes_freed" \
    >> "$LOGS/master_agent.log"
}
