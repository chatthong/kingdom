#!/usr/bin/env bash
# kingdom function: tmux_identify  (FALLBACK mirror of cmux_identify)
# Echo the caller's tmux context: <session>:<window>.<pane>.
tmux_identify () { tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'; }
