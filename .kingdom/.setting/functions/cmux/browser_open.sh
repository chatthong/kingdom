#!/usr/bin/env bash
# kingdom function: browser_open
# Open a built-in browser split pane in a workspace, navigate to <url>, echo its surface ref.
# Any role uses this to SEE a running app while it works (visible, matches R36/R37).
#   surf=$(browser_open "http://localhost:3000")
# NOTE: the exact "open browser pane" verb varies by cmux version; this uses `new-split --type browser`
# (cmux ≥ 0.64) then navigates via eval. Verify against your cmux if the pane doesn't appear.
browser_open () {
  local url="$1" ws="${2:-$CMUX_WORKSPACE_ID}"
  local out surface
  out=$(cmux_new_split right "$ws" browser)
  surface=$(echo "$out" | grep -oE 'surface:[0-9]+' | head -1)
  [ -z "$surface" ] && { echo "❌ browser_open: no surface ref from: $out" >&2; return 1; }
  [ -n "$url" ] && cmux browser "$surface" eval "location.href='${url}'" 2>/dev/null
  echo "$surface"
}
