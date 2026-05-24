#!/usr/bin/env bash
# kingdom function: cmux_list_panes
# List a workspace's panes as JSON. See reference/cmux.md § Inspect topology.
cmux_list_panes () {
  cmux list-panes --workspace "$1" --json 2>/dev/null
}
