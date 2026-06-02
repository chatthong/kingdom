#!/usr/bin/env bash
# kingdom function: kingdom_reset

kingdom_reset () {
  # Take the project root + use `git -C` so it can't reset the wrong repo when called from a
  # lane worktree (the v0.37.0 fix applied to kingdom_discard_overlay/kingdom_overlay_lane but
  # missed this one). Default BASE to develop so an unset $BASE can't make it `origin/`.
  local proj="${1:-${PROJ:-$PWD}}"
  git -C "$proj" checkout kingdom
  git -C "$proj" fetch origin
  git -C "$proj" reset --hard "origin/${BASE:-develop}"
}
