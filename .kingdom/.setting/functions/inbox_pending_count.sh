#!/usr/bin/env bash
# kingdom function: inbox_pending_count
# Print the integer count of pending messages for a recipient (U4, Shared spec 1).
#   inbox_pending_count <recipient>
inbox_pending_count () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally; auto-reverts on return
  local recipient="$1"
  [ -n "$recipient" ] || { echo "0"; return 1; }
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { echo "0"; return 1; }
  local dir="${WS:-$PWD}/.kingdom/$proj/inbox/$recipient"
  [ -d "$dir" ] || { echo "0"; return 0; }
  local n=$(ls -1 "$dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "${n:-0}"
}
