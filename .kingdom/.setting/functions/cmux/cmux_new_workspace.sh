#!/usr/bin/env bash
# kingdom function: cmux_new_workspace
# Create a workspace and echo its ref (workspace:N). Primitive — no rename/color/claude-launch
# (cmux_spawn_workspace / spawn_master_workspace compose those). $window_flag is the optional
# `--window <id>` pass-through for multi-window setups. See reference/cmux.md § Spawn a workspace.
cmux_new_workspace () {
  local name="$1" cwd="$2" desc="$3" window_flag="$4"
  local result
  result=$(cmux new-workspace \
    --name "$name" \
    --description "$desc" \
    --cwd "$cwd" \
    --focus false \
    $window_flag 2>&1)
  echo "$result" | grep -oE 'workspace:[0-9]+' | head -1
}
