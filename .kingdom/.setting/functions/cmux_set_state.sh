#!/usr/bin/env bash
# kingdom function: cmux_set_state

cmux_set_state () {
  local ws="${1:-$CMUX_WORKSPACE_ID}" emoji="$2" text="$3"
  cmux workspace-action --action set-description \
    --workspace "$ws" \
    --description "$emoji $text" 2>/dev/null
}
