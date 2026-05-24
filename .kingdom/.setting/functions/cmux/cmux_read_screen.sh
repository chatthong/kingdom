#!/usr/bin/env bash
# kingdom function: cmux_read_screen
# Read a workspace's current visible viewport (no scrollback). See reference/cmux.md § Read pane contents.
cmux_read_screen () {
  cmux read-screen --workspace "$1" 2>/dev/null
}
