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
# U12: cmux's workspace.list often hasn't materialised the new workspace's
# surface for ~1s right after creation, so a single immediate call returns empty
# (the user hits this constantly spawning worktrees). Retry up to 6 times, ~1s
# apart, before giving up; on final failure print a diagnostic to stderr instead
# of failing silently.
#
#   surface=$(cmux_first_surface "workspace:7")
cmux_first_surface () {
  local ws_ref="$1" surface="" listing i
  # NB: declare `listing` ONCE above — re-`local`-ing it inside the loop echoes "listing=…"
  # to stdout on every iteration after the first under zsh (a real zsh quirk; it pollutes
  # the captured surface ref).
  # cmux_rpc may not be loaded if this file is sourced alone; fall back to raw cmux.
  for i in 1 2 3 4 5 6; do
    if command -v cmux_rpc >/dev/null 2>&1; then
      listing=$(cmux_rpc workspace.list 2>/dev/null)
    else
      listing=$(cmux rpc workspace.list 2>/dev/null)
    fi
    # `.workspaces?` (try-operator): indexing a flat ARRAY with the string key
    # "workspaces" THROWS in jq before `//` can fire — the `?` suppresses that so
    # `// .` correctly falls back to the array itself. Handles both schemas.
    surface=$(printf '%s' "$listing" | jq -r --arg r "$ws_ref" \
      '[(.workspaces? // .)] | flatten | .[] | select(.ref == $r) | .surfaces[0].ref // empty' \
      2>/dev/null | head -1)
    [ -n "$surface" ] && { printf '%s' "$surface"; return 0; }
    [ "$i" -lt 6 ] && sleep 1
  done
  printf '⚠️ no surface found for %s after 6 tries — workspace may not have booted\n' "$ws_ref" >&2
  return 1
}
