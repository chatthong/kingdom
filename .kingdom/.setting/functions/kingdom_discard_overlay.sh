#!/usr/bin/env bash
# kingdom function: kingdom_discard_overlay
#
# Drop the kingdom working-tree overlay. R29 (hardened v0.37.0): call this ONLY
# AFTER the gated work has been pushed (gh pr create succeeded) — NEVER while the
# user is still reviewing the overlay or before push approval. The overlay is the
# human review surface (R15); wiping it early destroys what the user needs to see.
#
# v0.37.0 fix: take a project root ($1) and use `git -C` so it can't operate on
# the wrong repo when called from a lane worktree (the bare `git checkout` was
# cwd-dependent). Also `clean -fd` the untracked overlay files the old version left.
kingdom_discard_overlay () {
  local proj="${1:-$PWD}"
  git -C "$proj" checkout kingdom
  git -C "$proj" restore .    # drop modified tracked files
  git -C "$proj" clean -fd    # drop untracked overlay files (old version skipped these)
}
