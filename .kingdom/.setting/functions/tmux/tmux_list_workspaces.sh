#!/usr/bin/env bash
# kingdom function: tmux_list_workspaces  (FALLBACK mirror of cmux_list_workspaces)
# List the lanes (the sidebar contents): slug + emoji + color + state, one per line.
tmux_list_workspaces () { tmux list-windows -t "$(tmux_session)" -F '#{window_name} #{@emoji} #{@rolecolor} #{@state}'; }
