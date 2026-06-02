#!/usr/bin/env bash
# kingdom function: tmux_set_state  (FALLBACK mirror of cmux_set_state)
# Live sidebar state: set the @state glyph (▶ ⏸ ✅ ⚠ 🐾) WITHOUT renaming the window, so the
# target handle stays valid. Optional 3rd arg stored in @statetext.
#   tmux_set_state <ws-ref> <glyph> [text]
tmux_set_state () {
  local t; t="$(tmux_target "$1")"
  tmux set-window-option -t "$t" @state "${2:-▶}"
  [ -n "$3" ] && tmux set-window-option -t "$t" @statetext "$3"
  return 0   # never return the trailing test's status (would abort callers under `set -e`)
}
