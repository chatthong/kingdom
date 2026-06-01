#!/usr/bin/env bash
# kingdom function: guard_commit_branch

guard_commit_branch () {
  # Inputs:
  #   $1 = worktree path (defaults to $PWD)
  # Returns:
  #   0  — current branch is acceptable for committing here
  #   1  — R4 or R9 violation; commit MUST NOT proceed
  local wt="${1:-$PWD}"
  local current=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
  local wt_name=$(basename "$wt")

  # Case A: kingdom branch — R4 absolute ban
  if [ "$current" = "kingdom" ]; then
    echo "❌ R4 VIOLATION: commits forbidden on \`kingdom\` branch. It's a dirty working-tree overlay; never advances past origin/develop. Fix: git stash → git switch <worker-N> → git stash pop → re-commit." >&2
    return 1
  fi

  # Case B: feature/* branch in any worktree — R9 absolute ban
  case "$current" in
    feature/*)
      echo "❌ R9 VIOLATION: commits forbidden on \`$current\`. feature branches are CARVED from worker-N tips at push time (byte-for-byte). Fix: git branch -f $wt_name HEAD && git switch $wt_name && git branch -D $current → re-commit." >&2
      return 1
      ;;
  esac

  # Case C: worker-N / co-worker-N / watchman-N worktree but branch name doesn't match
  case "$wt_name" in
    worker-*|co-worker-*|watchman-*)
      if [ "$current" != "$wt_name" ]; then
        echo "❌ R21 + R9 VIOLATION: worktree \`$wt_name\` but current branch \`$current\` ≠ lane branch. Each worktree commits ONLY on its matching lane branch. Fix: git switch $wt_name (creates if missing from base)." >&2
        return 1
      fi
      ;;
  esac

  return 0
}
