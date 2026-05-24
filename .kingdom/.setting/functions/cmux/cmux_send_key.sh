#!/usr/bin/env bash
# kingdom function: cmux_send_key
# Press a real key/chord (Enter, C-l, C-c, …). Uses `cmux send-key`, NOT `cmux send`:
# `cmux send <ref> Enter` types the literal word "Enter" (send only emits text) — the classic
# "brief lands in a dead shell" silent failure. send-key prefers --workspace (it errored
# "Surface is not a terminal" on --surface in testing), so workspace refs are recommended.
cmux_send_key () {
  local ref="$1" key="${2:-Enter}"
  local flag=--workspace
  case "$ref" in surface:*) flag=--surface ;; esac
  cmux send-key "$flag" "$ref" "$key" 2>/dev/null
}
