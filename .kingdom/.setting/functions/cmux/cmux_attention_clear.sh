#!/usr/bin/env bash
# kingdom function: cmux_attention_clear
# Resolve an attention override: clear the unread badge and restore the active-state description.
# See reference/cmux.md § Three-layer state override.
#   cmux_attention_clear <lane_ws> <next_state_desc>
# U3: self-sufficient — uses cmux_workspace_action if loaded, else raw cmux inline.
cmux_attention_clear () {
  local lane_ws="$1" next_desc="${2:-▶ active}"
  if command -v cmux_workspace_action >/dev/null 2>&1; then
    cmux_workspace_action "$lane_ws" mark-read
    cmux_workspace_action "$lane_ws" set-description --description "$next_desc"
  else
    cmux workspace-action --action mark-read --workspace "$lane_ws" 2>/dev/null
    cmux workspace-action --action set-description --workspace "$lane_ws" --description "$next_desc" 2>/dev/null
  fi
}
