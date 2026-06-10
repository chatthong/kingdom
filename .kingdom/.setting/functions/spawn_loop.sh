#!/usr/bin/env bash
# kingdom function: spawn_loop
# Dispatch an autonomous /loop brief to a freshly-spawned lane's claude REPL.
# Generic — ANY role uses it (replaces the old spawn_watchman_loop / spawn_senior_loop):
#   spawn_loop "$ws" "/loop"                         # watchman: plain monitor loop
#   spawn_loop "$ws" "/loop You own story/<id>. …"   # senior: story-scoped loop brief
# Resolves the surface robustly via cmux_first_surface (handles the wrapped
# workspace.list schema, K2/K6). The receiving claude REPL was booted by
# spawn_master_workspace; cmux buffers surface input until the REPL attaches.
#   $1 = workspace ref (output of spawn_master_workspace)
#   $2 = brief text to send, INCLUDING the leading "/loop"
spawn_loop () {
  local ws_ref="$1" brief="$2"
  local surface=$(cmux_first_surface "$ws_ref")
  if [ -z "$surface" ]; then echo "❌ spawn_loop: no surface in $ws_ref" >&2; return 1; fi
  # H8: build the payload with jq so a brief containing " or \ can't malform the
  # JSON (raw interpolation silently broke the RPC → lane sat idle at a prompt).
  local payload=$(jq -cn --arg s "$surface" --arg t "$brief"$'\n' '{surface_id:$s,text:$t}')
  cmux_rpc surface.send_text "$payload"
}
