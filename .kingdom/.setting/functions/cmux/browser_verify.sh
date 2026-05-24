#!/usr/bin/env bash
# kingdom function: browser_verify
# Composite UI smoke check any role can call: open <url>, wait, assert <expect> (text or
# CSS selector) is present, scan the console for errors, then report PASS/FAIL + reason and
# tidy the pane. Returns 0 on PASS, 1 on FAIL.
#   browser_verify "http://localhost:3000" "Sign in"
#   browser_verify "http://localhost:3000/cart" "[data-testid=cart-total]"
browser_verify () {
  local url="$1" expect="$2" surface
  surface=$(browser_open "$url") || { echo "FAIL · could not open browser pane"; return 1; }
  sleep 2   # let the app paint / hydrate
  local found console_errs esc
  esc=${expect//\"/\\\"}   # escape double-quotes for safe JS embedding (bash 3.2-safe; no ${x@Q})
  # selector if it looks like one, else text search
  case "$expect" in
    \[*\] | .* | \#* | *' > '*)
      found=$(browser_eval "document.querySelector(\"$esc\") ? 'YES':'NO'" "$surface") ;;
    *)
      found=$(browser_eval "document.body.innerText.includes(\"$esc\") ? 'YES':'NO'" "$surface") ;;
  esac
  console_errs=$(browser_eval "(window.__kErrs||[]).length" "$surface")
  browser_close "$surface"
  if [ "$found" = "YES" ]; then
    echo "PASS · found '${expect}'${console_errs:+ · console errors: $console_errs}"
    return 0
  fi
  echo "FAIL · '${expect}' not found at ${url}${console_errs:+ · console errors: $console_errs}"
  return 1
}
