#!/usr/bin/env bash
# kingdom function: browser_close
# Close a browser pane when done. browser_close <surface>.
# U3: self-sufficient — uses cmux_close_surface if loaded, else raw cmux inline.
browser_close () {
  local surf="${1:-$CMUX_BROWSER_SURFACE}"
  if command -v cmux_close_surface >/dev/null 2>&1; then
    cmux_close_surface "$surf"
  else
    cmux close-surface --surface "$surf" 2>/dev/null
  fi
}
