#!/usr/bin/env bash
# kingdom function: cmux_tree
# Enumerate the full cmux topology (all windows/workspaces/panes). Extra args pass through.
# Kingdom uses it for the R31 lane-readiness check + resume. See reference/cmux.md § Inspect topology.
cmux_tree () {
  cmux tree --all "$@" 2>/dev/null
}
