#!/usr/bin/env bash
# kingdom function: spawn_watchman_loop

spawn_watchman_loop () {
  # Inputs:
  #   $1 = watchman workspace ref (e.g., workspace:7) — output of spawn_master_workspace
  # Returns:
  #   0 — /loop dispatch fired
  #   1 — dispatch failed (workspace not ready, surface not resolvable)
  local ws_ref="$1"

  # Find the surface inside this workspace (claude REPL is the receiver — already
  # launched by spawn_master_workspace Step 1b). v0.37.0 (K2/K6): cmux_first_surface
  # handles the wrapped {workspaces:[…]} schema the old inline jq broke on.
  local surface=$(cmux_first_surface "$ws_ref")

  if [ -z "$surface" ]; then
    echo "❌ spawn_watchman_loop: no surface found in $ws_ref" >&2
    return 1
  fi

  # Send /loop to the already-running claude REPL.
  # v0.31.1: the prior `claude\n` send + sleep was removed — that's now
  # spawn_master_workspace's job. Sending /loop here while claude is still
  # booting is safe because cmux buffers surface input until the receiver is
  # ready (Step 1b's 1.5s sleep gives the REPL time to attach).
  cmux_rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"/loop\n\"}"

  return 0
}
