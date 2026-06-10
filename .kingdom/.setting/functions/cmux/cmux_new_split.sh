#!/usr/bin/env bash
# kingdom function: cmux_new_split
# Add a split pane to a workspace. dir=left|right|up|down. Optional type "browser" routes to
# `cmux browser open-split` — `new-split` has NO --type flag in the current CLI contract
# (verified 2026-06-10; passing one errors and the caller silently got no surface).
# Echoes raw cmux output (grep for surface:N to capture the new pane). See reference/cmux.md § Spawn a split.
cmux_new_split () {
  local dir="${1:-right}" ws="$2" type="$3"
  if [ "$type" = "browser" ]; then
    local _ba=(open-split)
    [ -n "$ws" ] && _ba+=(--workspace "$ws")
    _ba+=(--focus false)
    cmux browser "${_ba[@]}" 2>&1
    return $?
  fi
  local args=("$dir")
  [ -n "$ws" ] && args+=(--workspace "$ws")
  args+=(--focus false)
  cmux new-split "${args[@]}" 2>&1
}
