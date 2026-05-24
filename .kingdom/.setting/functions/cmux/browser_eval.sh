#!/usr/bin/env bash
# kingdom function: browser_eval
# Evaluate JS in the page and return the result — the escape hatch (screenshot via canvas,
# console capture, fetch/performance reads all reachable here). browser_eval <js> [surface].
browser_eval () {
  local js="$1" surface="${2:-$CMUX_BROWSER_SURFACE}"
  cmux browser "$surface" eval "$js" 2>/dev/null
}
