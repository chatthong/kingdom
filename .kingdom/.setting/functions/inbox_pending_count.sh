#!/usr/bin/env bash
# kingdom function: inbox_pending_count
# Print the integer count of pending messages in the shared broker feed.
# Echo 0 on any error; never exits non-zero.
# Filename format: <UTC>__<from>__<to>__<type>.md
#
#   inbox_pending_count [--to <recipient>]
#
# Default (no flags): count the WHOLE pending feed.
# --to <recipient>: count only messages where to==<recipient> OR to==all.
inbox_pending_count () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null
  local filter_to=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --to) filter_to="$2"; shift 2 ;;
      *)    echo "0"; return 0 ;;   # unknown option: safe fallback
    esac
  done
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { echo "0"; return 0; }
  local inboxdir="${WS:-$PWD}/.kingdom/$proj/inbox"
  [ -d "$inboxdir" ] || { echo "0"; return 0; }
  # All loop locals declared ONCE here — a re-run `local x=...` inside the loop echoes the
  # assignment to stdout under zsh, which would corrupt the integer this function must print.
  local n=0 msgfile="" base="" fto=""
  for msgfile in "$inboxdir"/*.md; do
    [ -e "$msgfile" ] || continue   # no_nomatch: unmatched glob passes literally
    if [ -n "$filter_to" ]; then
      base="$(basename "$msgfile" .md)"
      fto="$(printf '%s' "$base" | awk -F'__' '{print $3}')"
      [ "$fto" = "$filter_to" ] || [ "$fto" = "all" ] || continue
    fi
    n=$(( n + 1 ))
  done
  echo "$n"
  return 0
}
