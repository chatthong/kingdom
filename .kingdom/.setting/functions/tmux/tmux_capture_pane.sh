#!/usr/bin/env bash
# kingdom function: tmux_capture_pane  (FALLBACK mirror of cmux_capture_pane)
# Capture the last N lines (default 30) incl. scrollback (tmux uses negative -S).
#   tmux_capture_pane <ws-ref> [N]
tmux_capture_pane () { local n="${2:-30}"; tmux capture-pane -t "$(tmux_target "$1")" -p -S "-$n"; }
