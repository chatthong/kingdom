#!/usr/bin/env bash
# kingdom function: cmux_tab_action
# Single wrapper for `cmux tab-action` — pass the action + its flags. Targets a surface, not a workspace.
#   cmux_tab_action new-terminal-right --workspace "$WS" --surface "$SURF" --focus false
#   cmux_tab_action rename --surface "$SURF" --title "🐱 sub · Sonnet"
#   cmux_tab_action close  --surface "$CMUX_SURFACE_ID"     # 5-step closer Step 5
# See reference/cmux.md § Spawn a tab / Close own tab. (Use cmux_close_workspace for whole workspaces.)
cmux_tab_action () {
  local action="$1"; shift
  cmux tab-action --action "$action" "$@"
}
