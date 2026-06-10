#!/usr/bin/env bash
# kingdom function: browser_click
# Click an element by CSS selector (discover one via browser_snapshot). browser_click <selector> [surface].
# Contract-verified 2026-06-10: click takes [--selector <css> | <css>] — there is no --ref flag.
browser_click () {
  local selector="$1" surface="${2:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" click --selector "$selector" 2>/dev/null
}
