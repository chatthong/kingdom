#!/usr/bin/env bash
# kingdom function: cmux_send
# Send text to a target AND submit it. Two calls: the text via `cmux send … -- "$text"`,
# then a real Enter keypress (NOT `cmux send … Enter`, which types the literal word "Enter").
# Auto-targets --surface for surface:* refs, else --workspace.
# See reference/cmux.md § Send. For control keys only, call cmux_send_key directly.
#
# U15: this is the user's #1 real-world pain — the Enter keypress used to depend on the
# sibling wrapper `cmux_send_key`, which is silently a no-op under zsh when not loaded in
# the same session (function-not-found is non-fatal) → the brief sits unsubmitted and the
# lane stalls. So cmux_send is now SELF-SUFFICIENT: it calls `cmux send-key` inline and only
# delegates to cmux_send_key if that wrapper happens to be defined. It then VERIFIES the
# composer cleared (read-screen the target) and re-fires Enter once if it didn't.
cmux_send () {
  local ref="$1" text="$2"
  local flag=--workspace
  case "$ref" in surface:*) flag=--surface ;; esac
  cmux send "$flag" "$ref" -- "$text"

  # --- submit (self-sufficient Enter) ---------------------------------------
  # send-key prefers --workspace (it errors "Surface is not a terminal" on --surface).
  local keyflag=--workspace
  case "$ref" in surface:*) keyflag=--surface ;; esac
  _cmux_send_enter () { cmux send-key "$keyflag" "$ref" Enter 2>/dev/null; }
  _cmux_send_enter

  # --- submission verification + paste-collapse re-send ---------------------
  # Two failure modes after a single Enter:
  #   (1) K3 paste-collapse — a long paste into an IDLE REPL stays "paste-collapsed",
  #       the brief unsubmitted in the composer.
  #   (2) the Enter simply didn't register (composer still echoes the typed text).
  # Read the target's screen (surface OR workspace — the old code always used --workspace,
  # so the K3 check silently never applied to surface refs; fixed here) and re-fire Enter
  # once if either marker is present.
  sleep 0.3
  local screen
  case "$ref" in
    surface:*) screen=$(cmux read-screen --surface "$ref" 2>/dev/null) ;;
    *)         screen=$(cmux read-screen --workspace "$ref" 2>/dev/null) ;;
  esac
  if [ -n "$screen" ] && printf '%s' "$screen" | grep -qiE 'paste again to expand|\[pasted [0-9]+ '; then
    _cmux_send_enter
  fi
  unset -f _cmux_send_enter 2>/dev/null
  return 0
}
