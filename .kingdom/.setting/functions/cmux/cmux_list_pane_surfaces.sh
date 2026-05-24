#!/usr/bin/env bash
# kingdom function: cmux_list_pane_surfaces
# List the surface refs of the current/target panes (e.g. to grab a freshly-spawned tab's surface).
# See reference/cmux.md § Inspect topology.
cmux_list_pane_surfaces () {
  cmux list-pane-surfaces "$@" 2>/dev/null
}
