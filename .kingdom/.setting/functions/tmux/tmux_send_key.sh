#!/usr/bin/env bash
# kingdom function: tmux_send_key  (FALLBACK mirror of cmux_send_key)
# Send a raw key/chord (Enter, C-c, C-l, …) — NOT literal text.
#   tmux_send_key <ws-ref> <key>
tmux_send_key () { tmux send-keys -t "$(tmux_target "$1")" "${2:-Enter}"; }
