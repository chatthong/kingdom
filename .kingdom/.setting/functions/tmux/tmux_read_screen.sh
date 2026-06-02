#!/usr/bin/env bash
# kingdom function: tmux_read_screen  (FALLBACK mirror of cmux_read_screen)
# Read a lane's current visible viewport (no scrollback).
#   tmux_read_screen <ws-ref>
tmux_read_screen () { tmux capture-pane -t "$(tmux_target "$1")" -p; }
