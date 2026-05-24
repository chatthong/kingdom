#!/usr/bin/env bash
# kingdom function: browser_close
# Close a browser pane when done. browser_close <surface>.
browser_close () {
  cmux_close_surface "${1:-$CMUX_BROWSER_SURFACE}"
}
