#!/usr/bin/env bash
# kingdom function: inbox_read
# Print a message; with --consume, move it to inbox/<recipient>/.archive/ after
# printing (U4, Shared spec 1).
#   inbox_read <file> [--consume]
inbox_read () {
  local file="$1" consume="$2"
  [ -n "$file" ] && [ -f "$file" ] || { echo "❌ inbox_read: not a file ($file)" >&2; return 1; }
  cat "$file"
  if [ "$consume" = "--consume" ]; then
    local archive="$(dirname "$file")/.archive"
    mkdir -p "$archive" || { echo "❌ inbox_read: cannot create $archive" >&2; return 1; }
    mv "$file" "$archive/" && echo "🗄️  archived → $archive/$(basename "$file")" >&2
  fi
}
