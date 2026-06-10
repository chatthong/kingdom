#!/usr/bin/env bash
# kingdom function: cmux_attention_override
# Three-signal override when cmux's auto-state is wrong: mark the lane unread, rewrite its
# description with the truth, and fire a notification to the King. See reference/cmux.md
# § Three-layer state override.
#   cmux_attention_override <lane_ws> <king_ws> <desc> <notify_title> <notify_subtitle> <notify_body> [lane_surface]
# U3: self-sufficient — uses the sibling wrappers if loaded, else raw cmux inline.
cmux_attention_override () {
  local lane_ws="$1" king_ws="$2" desc="$3" n_title="$4" n_sub="$5" n_body="$6" lane_surface="$7"
  if command -v cmux_workspace_action >/dev/null 2>&1; then
    cmux_workspace_action "$lane_ws" mark-unread
    cmux_workspace_action "$lane_ws" set-description --description "$desc"
  else
    cmux workspace-action --action mark-unread --workspace "$lane_ws" 2>/dev/null
    cmux workspace-action --action set-description --workspace "$lane_ws" --description "$desc" 2>/dev/null
  fi
  if command -v cmux_notify >/dev/null 2>&1; then
    cmux_notify "$king_ws" "$n_title" "$n_sub" "$n_body" "${lane_surface:-$lane_ws}"
  else
    local _surf="${lane_surface:-$lane_ws}" _na=()
    [ -n "$king_ws" ] && _na+=(--workspace "$king_ws")
    [ -n "$_surf" ]   && _na+=(--surface "$_surf")
    [ -n "$n_title" ] && _na+=(--title "$n_title")
    [ -n "$n_sub" ]   && _na+=(--subtitle "$n_sub")
    [ -n "$n_body" ]  && _na+=(--body "$n_body")
    cmux notify "${_na[@]}" 2>/dev/null
  fi
}
