#!/usr/bin/env bash
# kingdom function: cmux_list_workspaces
# List all workspaces (labels + refs). Used by guard_lane_workspace_exists to confirm a lane's
# workspace is visible in the sidebar before dispatch. See reference/cmux.md § Inspect topology.
cmux_list_workspaces () {
  cmux list-workspaces "$@" 2>/dev/null
}
