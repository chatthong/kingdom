#!/usr/bin/env bash
# kingdom function: browser_screenshot
# Best-effort PNG capture for review evidence. browser_screenshot <surface> <out_path>.
# Tries a native screenshot verb, then falls back to a canvas data-URL via eval. Returns 1 if neither works.
browser_screenshot () {
  local surface="${1:-$CMUX_BROWSER_SURFACE}" out="${2:-/tmp/kingdom-shot-$(date -u +%H%M%S).png}"
  if cmux browser "$surface" screenshot --path "$out" 2>/dev/null; then
    echo "$out"; return 0
  fi
  local datauri
  datauri=$(browser_eval "(()=>{const c=document.createElement('canvas');c.width=innerWidth;c.height=innerHeight;return c.toDataURL('image/png');})()" "$surface")
  if [ -n "$datauri" ]; then
    echo "${datauri#data:image/png;base64,}" | base64 --decode > "$out" 2>/dev/null && { echo "$out"; return 0; }
  fi
  echo "⚠️ browser_screenshot: no capture path worked for $surface" >&2; return 1
}
