#!/usr/bin/env bash
# kingdom function: browser_snapshot
# Snapshot the page's interactive accessibility tree (JSON with element refs) — the basis for
# ref-based click/fill. Surface defaults to $CMUX_BROWSER_SURFACE. See features/browser docs.
browser_snapshot () {
  local surface="${1:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" snapshot --interactive 2>/dev/null
}
