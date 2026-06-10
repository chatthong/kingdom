#!/usr/bin/env bash
# kingdom function: inbox_list
# Print pending message file paths for a recipient, oldest first (U4, Shared spec 1).
# Pending = files directly under inbox/<recipient>/ (handled ones live in .archive/).
#   inbox_list <recipient>
inbox_list () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally; auto-reverts on return
  local recipient="$1"
  [ -n "$recipient" ] || { echo "❌ inbox_list: usage: inbox_list <recipient>" >&2; return 1; }
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { echo "❌ inbox_list: \$PROJECT unset" >&2; return 1; }
  local dir="${WS:-$PWD}/.kingdom/$proj/inbox/$recipient"
  [ -d "$dir" ] || return 0   # no inbox yet = no pending mail
  # Oldest first: filenames lead with a sortable UTC stamp, so lexical sort works.
  ls -1 "$dir"/*.md 2>/dev/null | sort || true
}
