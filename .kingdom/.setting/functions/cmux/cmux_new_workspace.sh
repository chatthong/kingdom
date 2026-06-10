#!/usr/bin/env bash
# kingdom function: cmux_new_workspace
# Create a workspace and echo its ref (workspace:N). Primitive — no rename/color/claude-launch
# (cmux_spawn_workspace / spawn_master_workspace compose those). See reference/cmux.md § Spawn a workspace.
#
# Finding 8: extra cmux flags are now proper passthrough args (shift 3; append "$@"), so callers
# pass each flag pre-split — never word-split an unquoted variable. Two supported call forms:
#   (A) Array form (preferred):  cmux_new_workspace "$name" "$cwd" "$desc" --window "$uuid"
#       → each flag/value is its own argv entry; passed through verbatim.
#   (B) Legacy single-string form (back-compat with spawn_master_workspace.sh, which builds
#       window_flag="--window $cached_win"):  cmux_new_workspace "$name" "$cwd" "$desc" "--window abc"
#       → detected as exactly ONE trailing arg that contains a space, and deliberately word-split
#         (under `emulate -L sh` so zsh splits like bash) into separate argv entries.
cmux_new_workspace () {
  local name="$1" cwd="$2" desc="$3"; shift 3
  # Back-compat: a single trailing arg containing a space is the legacy "--window <id>" string.
  if [ "$#" -eq 1 ] && [ "${1#* }" != "$1" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then emulate -L sh; fi
    set -- $1
  fi
  local result
  result=$(cmux new-workspace \
    --name "$name" \
    --description "$desc" \
    --cwd "$cwd" \
    --focus false \
    "$@" 2>&1)
  echo "$result" | grep -oE 'workspace:[0-9]+' | head -1
}
