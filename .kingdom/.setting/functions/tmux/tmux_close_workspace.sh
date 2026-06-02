#!/usr/bin/env bash
# kingdom function: tmux_close_workspace  (FALLBACK mirror of cmux_close_workspace)
# Tear down one lane window.
#   tmux_close_workspace <ws-ref>
tmux_close_workspace () { tmux kill-window -t "$(tmux_target "$1")" 2>/dev/null; }
