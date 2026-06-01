#!/usr/bin/env bash
# kingdom function: cmux_first_surface
# Resolve the first surface ref inside a workspace, robust to cmux's wrapped
# workspace.list schema.
#
# THE K6 TRAP: some cmux builds return `[{ref,surfaces}, …]` (a flat array) but
# others return `{window_ref, workspaces:[{ref,surfaces}, …]}` (an object). The
# old call sites assumed the flat array (`jq '.[] | select(.ref==…)'`), which
# errors on the wrapped shape → surface=null → the post-spawn `claude\n` and
# `/loop` sends are silently skipped → the lane sits at a dead bash prompt.
# `(.workspaces // .)` handles both; the flatten copes with either nesting.
#
#   surface=$(cmux_first_surface "workspace:7")
cmux_first_surface () {
  local ws_ref="$1"
  # `.workspaces?` (try-operator): indexing a flat ARRAY with the string key
  # "workspaces" THROWS in jq before `//` can fire — the `?` suppresses that so
  # `// .` correctly falls back to the array itself. Handles both schemas.
  cmux_rpc workspace.list 2>/dev/null \
    | jq -r --arg r "$ws_ref" \
        '[(.workspaces? // .)] | flatten | .[] | select(.ref == $r) | .surfaces[0].ref // empty' \
    | head -1
}
