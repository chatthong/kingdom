#!/usr/bin/env bash
# kingdom function: kingdom_overlay_lane

kingdom_overlay_lane () {
  # Inputs:
  #   $1 = project directory (the worktree on kingdom branch)
  #   $2 = lane name (worker-1, worker-2, etc.)
  #   $3 = base branch (default: develop)
  # Returns:
  #   0 — overlay applied as dirty changes; kingdom HEAD unchanged
  #   1 — overlay refused (R4 guard, or git apply conflict)
  local proj="$1" lane="$2" base="${3:-develop}"

  # Guard 1: kingdom branch must be currently checked out in proj
  local current=$(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$current" != "kingdom" ]; then
    echo "❌ R4 GUARD: kingdom_overlay_lane called but $proj is on $current, not kingdom. Refusing." >&2
    return 1
  fi

  # Guard 2: kingdom HEAD must equal origin/$base (no rogue commits per R4)
  local king_sha=$(git -C "$proj" rev-parse HEAD)
  local base_sha=$(git -C "$proj" rev-parse "origin/$base")
  if [ "$king_sha" != "$base_sha" ]; then
    echo "❌ R4 GUARD: kingdom HEAD ($king_sha) ≠ origin/$base ($base_sha). Run \`git reset --hard origin/$base && git clean -fd\` first." >&2
    return 1
  fi

  # Apply lane's diff as dirty working-tree changes
  if ! git -C "$proj" diff "origin/$base..$lane" | git -C "$proj" apply --3way; then
    echo "❌ overlay failed: git apply --3way returned non-zero for $lane → kingdom" >&2
    return 1
  fi

  echo "✅ overlay applied: $lane diff is now dirty on kingdom (HEAD still $base_sha)" >&2
  return 0
}
