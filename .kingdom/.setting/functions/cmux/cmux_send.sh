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
}
