#!/usr/bin/env bash
# kingdom function: inbox_read
# Print a message file from the shared broker inbox.
# With --consume, move it to inbox/.archive/ after printing.
# The .archive/ dir is a sibling of the message file (one level up from any subdir,
# but for the flat broker feed it lives at inbox/.archive/).
#
#   inbox_read <file> [--consume]
inbox_read () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null
  local msgfile="$1" consume="$2"
  [ -n "$msgfile" ] && [ -f "$msgfile" ] || { echo "❌ inbox_read: not a file ($msgfile)" >&2; return 1; }
  cat "$msgfile"
  if [ "$consume" = "--consume" ]; then
    local archive
    archive="$(dirname "$msgfile")/.archive"
    mkdir -p "$archive" || { echo "❌ inbox_read: cannot create $archive" >&2; return 1; }
    mv "$msgfile" "$archive/" && printf '🗄️  archived → %s/%s\n' "$archive" "$(basename "$msgfile")" >&2
  fi
}
