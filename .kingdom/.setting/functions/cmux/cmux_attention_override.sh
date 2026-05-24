#!/usr/bin/env bash
# kingdom function: cmux_attention_override
# Three-signal override when cmux's auto-state is wrong: mark the lane unread, rewrite its
# description with the truth, and fire a notification to the King. See reference/cmux.md
# § Three-layer state override.
#   cmux_attention_override <lane_ws> <king_ws> <desc> <notify_title> <notify_subtitle> <notify_body> [lane_surface]
cmux_attention_override () {
  local lane_ws="$1" king_ws="$2" desc="$3" n_title="$4" n_sub="$5" n_body="$6" lane_surface="$7"
  cmux_workspace_action "$lane_ws" mark-unread
  cmux_workspace_action "$lane_ws" set-description --description "$desc"
  cmux_notify "$king_ws" "$n_title" "$n_sub" "$n_body" "${lane_surface:-$lane_ws}"
}
