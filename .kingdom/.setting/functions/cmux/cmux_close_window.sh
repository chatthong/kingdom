#!/usr/bin/env bash
# kingdom function: cmux_close_window
# Close an entire native cmux.app window (rare). See reference/cmux.md § Teardown.
cmux_close_window () {
  cmux close-window --window "$1" 2>/dev/null
}
