#!/usr/bin/env bash
# kingdom function: cmux_send
# Send text to a target AND submit it. Two calls: the text via `cmux send … -- "$text"`,
# then a real Enter keypress via cmux_send_key (NOT `cmux send … Enter`, which types the
# literal word "Enter"). Auto-targets --surface for surface:* refs, else --workspace.
# See reference/cmux.md § Send. For control keys only, call cmux_send_key directly.
cmux_send () {
  local ref="$1" text="$2"
  local flag=--workspace
  case "$ref" in surface:*) flag=--surface ;; esac
  cmux send "$flag" "$ref" -- "$text"
  cmux_send_key "$ref" Enter
  # K3: a long paste into an IDLE REPL can stay "paste-collapsed" after a single
  # Enter — the brief sits unsubmitted in the composer and the lane silently
  # stalls. Verify it cleared; if the collapsed-paste hint is still on screen,
  # press Enter once more. Best-effort: read-screen may not exist for surface refs.
  sleep 0.3
  if cmux_read_screen "$ref" 2>/dev/null | grep -qiE 'paste again to expand|\[pasted [0-9]+ '; then
    cmux_send_key "$ref" Enter
  fi
}
