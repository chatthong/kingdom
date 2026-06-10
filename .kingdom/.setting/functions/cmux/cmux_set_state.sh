#!/usr/bin/env bash
# kingdom function: cmux_set_state
# Live status-line update: set a workspace's sidebar description to "<emoji> <text>".
# Cosmetic + silent-on-failure. See reference/cmux.md § Dynamic workspace descriptions.
# U3: self-sufficient — calls cmux_workspace_action if loaded, else the raw cmux subcommand
# inline, so this file works even sourced alone.
cmux_set_state () {
  local ws="$1" emoji="$2" text="$3"
  if command -v cmux_workspace_action >/dev/null 2>&1; then
    cmux_workspace_action "$ws" set-description --description "$emoji $text"
  else
    cmux workspace-action --action set-description --workspace "$ws" --description "$emoji $text" 2>/dev/null
  fi
}
