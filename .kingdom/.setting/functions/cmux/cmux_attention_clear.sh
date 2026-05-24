#!/usr/bin/env bash
# kingdom function: cmux_attention_clear
# Resolve an attention override: clear the unread badge and restore the active-state description.
# See reference/cmux.md § Three-layer state override.
#   cmux_attention_clear <lane_ws> <next_state_desc>
cmux_attention_clear () {
  local lane_ws="$1" next_desc="${2:-▶ active}"
  cmux_workspace_action "$lane_ws" mark-read
  cmux_workspace_action "$lane_ws" set-description --description "$next_desc"
}
