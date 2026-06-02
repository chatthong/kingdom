#!/usr/bin/env bash
# kingdom function: tmux_new_split  (FALLBACK mirror of cmux_new_split)
# Split a lane window into a pane. dir = -h | -v (default -v).
#   tmux_new_split <ws-ref> [-h|-v] [cwd]
tmux_new_split () { tmux split-window "${2:--v}" -t "$(tmux_target "$1")" -c "${3:-$PWD}"; }
