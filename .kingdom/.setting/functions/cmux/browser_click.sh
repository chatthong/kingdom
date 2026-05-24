#!/usr/bin/env bash
# kingdom function: browser_click
# Click an element by ref (from browser_snapshot). browser_click <ref> [surface].
browser_click () {
  local ref="$1" surface="${2:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" click --ref "$ref" 2>/dev/null
}
