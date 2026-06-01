#!/usr/bin/env bash
# kingdom function: guard_no_worktree_cd

guard_no_worktree_cd () {
  # Inputs:
  #   $1 = target path being cd'd into
  #   $2 = optional caller role (defaults to whatever $KINGDOM_ROLE is set to; "king" if unset)
  # Returns:
  #   0  — cd is allowed (not King, or target isn't a lane worktree)
  #   1  — R30/R37 violation; cd MUST NOT proceed
  local target="$1"
  local role="${2:-${KINGDOM_ROLE:-king}}"

  # Non-king roles (lanes themselves) cd freely
  [ "$role" != "king" ] && return 0

  # Resolve target to absolute path
  local abs=$(cd "$target" 2>/dev/null && pwd)
  [ -z "$abs" ] && return 0  # target doesn't exist; let the cd fail naturally

  # Detect: is target inside a .worktrees/<lane>/ directory?
  case "$abs" in
    */.worktrees/worker-*|*/.worktrees/co-worker-*|*/.worktrees/watchman-*)
      local lane=$(basename "$abs")
      echo "❌ R30 + R37 VIOLATION: King session attempting to cd into $lane worktree. King is orchestrator-only — heavy processing belongs IN the lane workspace, not the King's session. Fix: cmux_send into the lane's surface, OR (for trivial reads) use git -C \"$abs\" <cmd> without changing directory." >&2
      return 1
      ;;
  esac

  return 0
}
