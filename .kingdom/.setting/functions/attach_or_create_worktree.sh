#!/usr/bin/env bash
# kingdom function: attach_or_create_worktree

attach_or_create_worktree () {
  # `wt` (worktree path), not `path`: zsh ties the lowercase `path` array to
  # $PATH, so `local path="$2"` would clobber command resolution for the `git`
  # calls below.
  local branch="$1" wt="$2" base="${3:-develop}"

  # Case A: worktree directory exists → reuse silently
  [ -d "$wt" ] && return 0

  # Case B: branch exists (prior kingdom session) → attach
  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git worktree add "$wt" "$branch" 2>&1 | grep -v '^Preparing' >&2
    [ -d "$wt" ] || { echo "❌ attach_or_create_worktree: attach failed for $branch → $wt" >&2; return 1; }
    return 0
  fi

  # Case C: neither exists → create fresh from origin/<base>
  git worktree add -b "$branch" "$wt" "origin/$base" 2>&1 | grep -v '^Preparing' >&2
  [ -d "$wt" ] || { echo "❌ attach_or_create_worktree: create failed for $branch → $wt (is origin/$base fetched?)" >&2; return 1; }
}
