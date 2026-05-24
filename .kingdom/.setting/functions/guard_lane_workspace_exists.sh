#!/usr/bin/env bash
# kingdom function: guard_lane_workspace_exists

guard_lane_workspace_exists () {
  # Inputs:
  #   $1 = lane name (worker-1, co-worker-1, watchman-1, etc.)
  # Returns:
  #   0  — lane workspace visible in cmux + worktree exists; dispatch may proceed
  #   1  — R31/R36 violation; dispatch MUST NOT fire
  local lane="$1"
  local proj_dir="${PROJ:-$PWD}"

  # Worktree check (universal, mode-agnostic per R31 expanded)
  if [ ! -d "$proj_dir/.worktrees/$lane" ]; then
    echo "❌ R31 VIOLATION: worktree .worktrees/$lane missing. Run attach_or_create_worktree before dispatch." >&2
    return 1
  fi

  # cmux workspace check (PRIMARY mode only — AGENT fallback skips this)
  if ! command -v cmux >/dev/null 2>&1; then
    return 0  # FALLBACK/AGENT mode — worktree existence is enough
  fi

  local ws_list=$(cmux_list_workspaces)
  if [ -z "$ws_list" ]; then
    return 0  # cmux not running; not PRIMARY mode
  fi

  # Look for the lane label in workspace titles (matches "👷 worker-1", "👑 King · ...", etc.)
  if ! echo "$ws_list" | grep -qE "(👷|🧑‍💼|🕵️|👑).*$lane\b|\b$lane\b"; then
    echo "❌ R31 + R36 VIOLATION: lane $lane has no workspace in cmux sidebar. Run spawn_master_workspace before dispatch. Without a visible workspace, the user sees nothing happening (R36 'stuck on fan-out' anti-pattern)." >&2
    return 1
  fi

  return 0
}
