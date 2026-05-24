#!/usr/bin/env bash
# kingdom function: cmux_close_surface
# Close a single surface (tab/pane). See reference/cmux.md § Teardown.
cmux_close_surface () {
  cmux close-surface --surface "$1" 2>/dev/null
}
