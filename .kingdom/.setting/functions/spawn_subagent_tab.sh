#!/usr/bin/env bash
# kingdom function: spawn_subagent_tab

spawn_subagent_tab () {
  # $1 = model (default sonnet), $2 = brief. Visible-tab fallback when the pre-warmed pool is empty (R38):
  # open a terminal tab in the current workspace, boot claude, send the brief.
  local model="${1:-sonnet}" brief="$2" surf
  cmux_tab_action new-terminal-right --focus false
  sleep 1
  surf=$(cmux_list_pane_surfaces | grep -oE 'surface:[0-9]+' | tail -1)
  if [ -n "$surf" ]; then
    cmux_rpc surface.send_text "{\"surface_id\":\"$surf\",\"text\":\"claude --model ${model}\n\"}"
    sleep 2
    cmux_rpc surface.send_text "{\"surface_id\":\"$surf\",\"text\":\"${brief}\n\"}"
  fi
}
