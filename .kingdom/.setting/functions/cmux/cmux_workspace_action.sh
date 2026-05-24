#!/usr/bin/env bash
# kingdom function: cmux_workspace_action
# Single wrapper for `cmux workspace-action` — pass the action + its flags.
#   cmux_workspace_action "$ws" rename --title "👷 worker-1"
#   cmux_workspace_action "$ws" set-color --color Amber
#   cmux_workspace_action "$ws" set-description --description "▶ L3"
#   cmux_workspace_action "$ws" pin            # also: unpin, mark-read, mark-unread, clear-color, clear-description
# Silent on failure (sidebar cosmetics never block work). See reference/cmux.md § Rename / Pin / Set color.
cmux_workspace_action () {
  local ws="$1" action="$2"; shift 2
  cmux workspace-action --action "$action" --workspace "$ws" "$@" 2>/dev/null
}
