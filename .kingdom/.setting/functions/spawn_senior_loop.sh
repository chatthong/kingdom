#!/usr/bin/env bash
# kingdom function: spawn_senior_loop

spawn_senior_loop () {
  # Inputs: $1 = senior workspace ref, $2 = story id
  # Dispatches the story-scoped autonomous loop to the already-running claude REPL.
  local ws_ref="$1" id="$2"
  local surface=$(cmux rpc workspace.list 2>/dev/null \
    | jq -r ".[] | select(.ref == \"$ws_ref\") | .surfaces[0].ref" 2>/dev/null)
  [ -z "$surface" ] || [ "$surface" = "null" ] && { echo "❌ spawn_senior_loop: no surface in $ws_ref" >&2; return 1; }
  local brief="/loop You are ${id%%/*}'s Senior owning story/$id. Read .kingdom/.setting/seniors.md, then run the story lifecycle: doc-orient, split + dispatch your pod, merge each worker branch as its Tier-1 passes, run Tier-2 on the story branch, run the review loop (route fixes back to the owning worker, re-review, cap at reviewLoopCap), then write SENIOR_ verdict + push-eligible sentinel and notify the King. Never push."
  cmux rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"$brief\n\"}" 2>/dev/null
}
