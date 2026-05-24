#!/usr/bin/env bash
# kingdom function: cmux_new_window
# Open a fresh cmux.app window; echo its UUID. Used by spawnWindow="new". See reference/cmux.md § Multi-window.
cmux_new_window () {
  cmux new-window 2>&1 | grep -oE '[A-F0-9-]{36}' | head -1
}
