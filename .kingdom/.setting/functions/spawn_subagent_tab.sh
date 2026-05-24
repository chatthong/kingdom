#!/usr/bin/env bash
# kingdom function: spawn_subagent_tab

spawn_subagent_tab () {
  # $1 = model (default sonnet), $2 = brief. Visible-tab fallback when the pre-warmed pool is empty (R38):
  # open a terminal tab in the current workspace, boot claude, send the brief.
  local model="${1:-sonnet}" brief="$2" surf
  cmux tab-action --action new-terminal-right --focus false 2>/dev/null
  sleep 1
  surf=$(cmux list-pane-surfaces 2>/dev/null | grep -oE 'surface:[0-9]+' | tail -1)
  if [ -n "$surf" ]; then
    cmux rpc surface.send_text "{\"surface_id\":\"$surf\",\"text\":\"claude --model ${model}\n\"}" 2>/dev/null
    sleep 2
    cmux rpc surface.send_text "{\"surface_id\":\"$surf\",\"text\":\"${brief}\n\"}" 2>/dev/null
  fi
}
