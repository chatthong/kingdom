#!/usr/bin/env bash
# kingdom function: cmux_set_state
# Live status-line update: set a workspace's sidebar description to "<emoji> <text>".
# Cosmetic + silent-on-failure. See reference/cmux.md § Dynamic workspace descriptions.
cmux_set_state () {
  local ws="$1" emoji="$2" text="$3"
  cmux_workspace_action "$ws" set-description --description "$emoji $text"
}
