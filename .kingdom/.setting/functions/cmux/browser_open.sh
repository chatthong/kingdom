#!/usr/bin/env bash
# kingdom function: browser_open
# Open a built-in browser split pane in a workspace at <url>, echo its surface ref.
# Any role uses this to SEE a running app while it works (visible, matches R36/R37).
#   surf=$(browser_open "http://localhost:3000")
# Uses the documented one-call verb `cmux browser open-split [url] --workspace <ws>`
# (verified against the cmux CLI contract 2026-06-10; the old `new-split --type browser`
# flag does not exist in current cmux and silently produced no surface).
browser_open () {
  local url="$1" ws="${2:-$CMUX_WORKSPACE_ID}"
  local out surface
  local _ba=(open-split)
  [ -n "$url" ] && _ba+=("$url")
  [ -n "$ws" ]  && _ba+=(--workspace "$ws")
  _ba+=(--focus false)
  out=$(cmux browser "${_ba[@]}" 2>&1)
  surface=$(echo "$out" | grep -oE 'surface:[0-9]+' | head -1)
  [ -z "$surface" ] && { echo "❌ browser_open: no surface ref from: $out" >&2; return 1; }
  echo "$surface"
}
