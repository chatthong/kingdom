#!/usr/bin/env bash
# kingdom function: cmux_read_screen
# Read a target's current visible viewport (no scrollback). Accepts a workspace ref
# OR a surface ref — `surface:*` routes via --surface (contract-verified 2026-06-10;
# the old workspace-only form silently returned nothing for surface refs).
# See reference/cmux.md § Read pane contents.
cmux_read_screen () {
  case "$1" in
    surface:*) cmux read-screen --surface "$1" 2>/dev/null ;;
    *)         cmux read-screen --workspace "$1" 2>/dev/null ;;
  esac
}
