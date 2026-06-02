#!/usr/bin/env bash
# kingdom function: tmux_new_workspace  (FALLBACK mirror of cmux_new_workspace)
# Create a lane window. NAME = the bare slug (stable target handle); emoji/color/state are
# window options rendered in the status bar, so state changes never rename the window.
# Echoes the ref "<session>:<slug>".
#   tmux_new_workspace <slug> <cwd> <emoji> <rolecolor>
tmux_new_workspace () {
  local slug="$1" cwd="${2:-$PWD}" emoji="${3:-👷}" color="${4:-colour141}" S; S="$(tmux_session)"
  tmux new-window -t "$S" -n "$slug" -c "$cwd"
  tmux set-window-option -t "$S:$slug" @emoji "$emoji"
  tmux set-window-option -t "$S:$slug" @rolecolor "$color"
  tmux set-window-option -t "$S:$slug" @state "▶"
  printf '%s:%s' "$S" "$slug"
}
