#!/usr/bin/env bash
# kingdom function: cmux_new_split
# Add a split pane to a workspace. dir=left|right|up|down. Optional type (e.g. "browser")
# requests a non-terminal surface where the cmux version supports it. Echoes raw cmux output
# (grep for surface:N / workspace:N to capture the new pane). See reference/cmux.md § Spawn a split.
cmux_new_split () {
  local dir="${1:-right}" ws="$2" type="$3"
  local args=("$dir")
  [ -n "$ws" ]   && args+=(--workspace "$ws")
  [ -n "$type" ] && args+=(--type "$type")
  args+=(--focus false)
  cmux new-split "${args[@]}" 2>&1
}
