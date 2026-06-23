#!/usr/bin/env bash
# kingdom function: inbox_list
# List pending message file paths from the shared broker feed, oldest-first.
# Pending = files directly under inbox/ (handled ones live in inbox/.archive/).
# Filename format: <UTC>__<from>__<to>__<type>.md
#
#   inbox_list [--to <recipient>] [--from <who>]
#
# Default (no flags): list the WHOLE pending feed.
# --to <recipient>: only messages where to==<recipient> OR to==all.
# --from <who>:     only messages where from==<who>.
# Flags may be combined. Returns 0 with empty output when none match.
inbox_list () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null
  local filter_to="" filter_from=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --to)   filter_to="$2";   shift 2 ;;
      --from) filter_from="$2"; shift 2 ;;
      *) echo "❌ inbox_list: unknown option: $1" >&2; return 1 ;;
    esac
  done
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { echo "❌ inbox_list: \$PROJECT unset" >&2; return 1; }
  local inboxdir="${WS:-$PWD}/.kingdom/$proj/inbox"
  [ -d "$inboxdir" ] || return 0   # no inbox yet = no pending messages
  # Collect *.md files directly under inbox/ (not inside .archive/)
  # Filenames sort lexically oldest-first because they start with a UTC stamp.
  # NOTE: all loop locals are declared ONCE here, never inside the loop body — under zsh
  # a re-run `local name=...` echoes the assignment to stdout, polluting the path list.
  local msgfile="" base="" ffrom="" fto=""
  for msgfile in "$inboxdir"/*.md; do
    [ -e "$msgfile" ] || continue   # no_nomatch: unmatched glob passes literally
    base="$(basename "$msgfile" .md)"
    # Parse: <UTC>__<from>__<to>__<type> — split on __ with awk
    ffrom="$(printf '%s' "$base" | awk -F'__' '{print $2}')"
    fto="$(printf '%s' "$base"   | awk -F'__' '{print $3}')"
    # Apply --from filter
    if [ -n "$filter_from" ]; then
      [ "$ffrom" = "$filter_from" ] || continue
    fi
    # Apply --to filter: match exact recipient OR broadcast "all"
    if [ -n "$filter_to" ]; then
      [ "$fto" = "$filter_to" ] || [ "$fto" = "all" ] || continue
    fi
    printf '%s\n' "$msgfile"
  done
  return 0
}
