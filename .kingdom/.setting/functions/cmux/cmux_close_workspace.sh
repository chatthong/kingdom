#!/usr/bin/env bash
# kingdom function: cmux_close_workspace
# Close a whole workspace (lane teardown, /kingdom:save). NOT tab-action close. See reference/cmux.md § Teardown.
cmux_close_workspace () {
  cmux close-workspace --workspace "$1" 2>/dev/null
}
