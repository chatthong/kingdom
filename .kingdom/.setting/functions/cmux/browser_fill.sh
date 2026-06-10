#!/usr/bin/env bash
# kingdom function: browser_fill
# Fill a form field by CSS selector. browser_fill <selector> <value> [surface].
# Contract-verified 2026-06-10: fill takes [--selector <css>] [--text <text>] — not --ref/--value.
browser_fill () {
  local selector="$1" value="$2" surface="${3:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" fill --selector "$selector" --text "$value" 2>/dev/null
}
