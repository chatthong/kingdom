#!/usr/bin/env bash
# kingdom function: tmux_send  (FALLBACK mirror of cmux_send)
# Send text AND submit: send-keys -l (literal, so "Page"/"Down"/"Space" aren't read as keys),
# then a separate Enter.
#   tmux_send <ws-ref> <text>
tmux_send () { local t; t="$(tmux_target "$1")"; tmux send-keys -t "$t" -l "$2"; tmux send-keys -t "$t" Enter; }
