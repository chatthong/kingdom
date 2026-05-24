#!/usr/bin/env bash
# kingdom function: spawn_senior_workspace

spawn_senior_workspace () {
  # Inputs: $1 = senior lane (senior-1), $2 = story worktree path, $3 = color (default Teal)
  # Thin wrapper over spawn_master_workspace (claude boots automatically, v0.31.1+).
  spawn_master_workspace "🎓 $1" "$2" "${3:-Teal}"
}
