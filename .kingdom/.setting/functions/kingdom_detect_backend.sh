#!/usr/bin/env bash
# kingdom function: kingdom_detect_backend
# Detect which terminal app is hosting the King, and echo the backend to use:
#   cmux       — hosted by cmux.app (PRIMARY): $CMUX_CLAUDE_PID is set AND the `cmux` CLI is present
#   tmux       — any OTHER terminal (Ghostty, iTerm2, Terminal.app, a Linux term) with tmux available (FALLBACK)
#   standalone — neither cmux.app nor tmux → no lane workspaces possible (in-process Agent() sub-agents only)
#
# cmux.app sets $CMUX_CLAUDE_PID (+ $CMUX_WORKSPACE_ID / $CMUX_SURFACE_ID) in every session it hosts;
# requiring the `cmux` binary too means a stray env var alone won't mis-route us to a missing CLI.
kingdom_detect_backend () {
  if [ -n "${CMUX_CLAUDE_PID:-}" ] && command -v cmux >/dev/null 2>&1; then
    echo cmux
  elif command -v tmux >/dev/null 2>&1; then
    echo tmux
  else
    echo standalone
  fi
}
