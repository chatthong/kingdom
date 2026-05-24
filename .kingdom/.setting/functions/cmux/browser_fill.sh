#!/usr/bin/env bash
# kingdom function: browser_fill
# Fill a form field by ref. browser_fill <ref> <value> [surface].
browser_fill () {
  local ref="$1" value="$2" surface="${3:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" fill --ref "$ref" --value "$value" 2>/dev/null
}
