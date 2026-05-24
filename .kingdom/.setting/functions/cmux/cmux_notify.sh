#!/usr/bin/env bash
# kingdom function: cmux_notify
# Fire a cmux notification. Positional: ws title subtitle body [surface].
# Empty args are skipped. Workspace ref → sidebar badge; surface ref → blue ring.
# Always prefix $title with a role emoji (👑/👷/🧑‍💼/🕵️/🐱). See reference/cmux.md § Notification system.
cmux_notify () {
  local ws="$1" title="$2" subtitle="$3" body="$4" surface="$5"
  local args=()
  [ -n "$ws" ]       && args+=(--workspace "$ws")
  [ -n "$surface" ]  && args+=(--surface "$surface")
  [ -n "$title" ]    && args+=(--title "$title")
  [ -n "$subtitle" ] && args+=(--subtitle "$subtitle")
  [ -n "$body" ]     && args+=(--body "$body")
  cmux notify "${args[@]}" 2>/dev/null
}
