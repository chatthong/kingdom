#!/usr/bin/env bash
# kingdom function: spawn_subagent_tab

spawn_subagent_tab () {
  # $1 = model (default sonnet), $2 = brief. Visible-tab fallback when the pre-warmed pool is empty (R38):
  # open a terminal tab in the current workspace, boot claude, send the brief.
  local model="${1:-sonnet}" brief="$2" surf result
  # H8: capture the tab-action result and grep the surface from IT (like
  # spawn_pool_slot), not the racy `cmux_list_pane_surfaces | tail -1` which
  # grabs the wrong surface under concurrent spawns.
  result=$(cmux_tab_action new-terminal-right --focus false 2>&1)
  sleep 1
  surf=$(echo "$result" | grep -oE 'surface:[0-9]+' | head -1)
  [ -z "$surf" ] && surf=$(cmux_list_pane_surfaces | grep -oE 'surface:[0-9]+' | tail -1)
  if [ -n "$surf" ]; then
    # H8: jq-build both payloads so a brief with " or \ can't malform the JSON.
    local boot=$(jq -cn --arg s "$surf" --arg t "claude --model ${model}"$'\n' '{surface_id:$s,text:$t}')
    cmux_rpc surface.send_text "$boot"
    sleep 2
    local payload=$(jq -cn --arg s "$surf" --arg t "$brief"$'\n' '{surface_id:$s,text:$t}')
    cmux_rpc surface.send_text "$payload"
  fi
}
