#!/usr/bin/env bash
# kingdom function: browser_verify
# Composite UI smoke check any role can call: open <url>, wait, assert <expect> (text or
# CSS selector) is present, scan the console for errors, then report PASS/FAIL + reason and
# tidy the pane. Returns 0 on PASS, 1 on FAIL.
#   browser_verify "http://localhost:3000" "Sign in"
#   browser_verify "http://localhost:3000/cart" "[data-testid=cart-total]"
# U3: self-sufficient — wraps the sibling helpers (browser_open/_eval/_close) with inline
# raw-cmux fallbacks so this file works even sourced alone.
browser_verify () {
  local url="$1" expect="$2" surface
  # inline browser_eval shim: use the wrapper if loaded, else raw cmux browser eval.
  _bv_eval () {
    if command -v browser_eval >/dev/null 2>&1; then browser_eval "$1" "$2"
    else cmux browser "$2" eval "$1" 2>/dev/null; fi
  }
  if command -v browser_open >/dev/null 2>&1; then
    surface=$(browser_open "$url") || { echo "FAIL · could not open browser pane"; unset -f _bv_eval; return 1; }
  else
    # Contract-verified 2026-06-10: one-call open + navigate (new-split has no --type flag).
    surface=$(cmux browser open-split "$url" --workspace "${CMUX_WORKSPACE_ID}" --focus false 2>&1 | grep -oE 'surface:[0-9]+' | head -1)
    [ -z "$surface" ] && { echo "FAIL · could not open browser pane"; unset -f _bv_eval; return 1; }
  fi
  # Wait for real load state (documented `browser wait`); fall back to a fixed pause.
  cmux browser "$surface" wait --load-state complete --timeout 10 2>/dev/null || sleep 2
  local found console_errs esc
  # Finding 12: fully JSON-encode the expect value into a JS string literal — `jq -Rn --arg`
  # emits a complete, quoted JS-safe literal (its own surrounding quotes included) that escapes
  # ", \, backtick, newlines, and any $(…)/`…` so nothing shell- or JS-injects. Embed $esc bare
  # (no surrounding quotes) inside the JS template.
  esc=$(jq -Rn --arg s "$expect" '$s')
  # selector if it looks like one, else text search
  case "$expect" in
    \[*\] | .* | \#* | *' > '*)
      found=$(_bv_eval "document.querySelector($esc) ? 'YES':'NO'" "$surface") ;;
    *)
      found=$(_bv_eval "document.body.innerText.includes($esc) ? 'YES':'NO'" "$surface") ;;
  esac
  console_errs=$(_bv_eval "(window.__kErrs||[]).length" "$surface")
  if command -v browser_close >/dev/null 2>&1; then browser_close "$surface"
  else cmux close-surface --surface "$surface" 2>/dev/null; fi
  unset -f _bv_eval 2>/dev/null
  if [ "$found" = "YES" ]; then
    echo "PASS · found '${expect}'${console_errs:+ · console errors: $console_errs}"
    return 0
  fi
  echo "FAIL · '${expect}' not found at ${url}${console_errs:+ · console errors: $console_errs}"
  return 1
}
