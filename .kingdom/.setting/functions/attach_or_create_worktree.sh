#!/usr/bin/env bash
# kingdom function: attach_or_create_worktree

attach_or_create_worktree () {
  local branch="$1" path="$2" base="${3:-develop}"

  # Case A: worktree directory exists → reuse silently
  [ -d "$path" ] && return 0

  # Case B: branch exists (prior kingdom session) → attach silently
  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git worktree add "$path" "$branch" 2>/dev/null
    return $?
  fi

  # Case C: neither exists → create fresh from origin/<base>
  git worktree add -b "$branch" "$path" "origin/$base" 2>/dev/null
}
