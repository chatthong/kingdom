#!/usr/bin/env bash
# kingdom function: cmux_capture_pane
# Capture the last N lines a pane is showing (default 30). Optional 3rd arg = a surface ref for
# per-pane precision (e.g. the watchman orphan-tab sweep targeting one tab in a multi-tab workspace);
# omit it for workspace-level. Watchman uses this for blocked-lane detection. See reference/cmux.md § Read pane contents.
cmux_capture_pane () {
  local ws="$1" lines="${2:-30}" surface="$3"
  local args=(--workspace "$ws" --lines "$lines")
  [ -n "$surface" ] && args+=(--surface "$surface")
  cmux capture-pane "${args[@]}" 2>/dev/null
}
