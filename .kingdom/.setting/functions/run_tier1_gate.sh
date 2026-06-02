#!/usr/bin/env bash
# kingdom function: run_tier1_gate

run_tier1_gate () {
  # $1 = lane, $2 = sub-task id. Runs gate.typecheck inside the lane's worktree (Tier-1, fast). 0 = pass.
  # ${PROJECT} (exported), NOT ${project} (a non-exported local) — an empty name yielded
  # `.kingdom//kingdom.json` → jq read nothing → the loop never ran → FALSE PASS on zero checks.
  local lane="$1" wt="${PROJ:-$PWD}/.worktrees/$1" kjson="${KJSON:-$PWD/.kingdom/${PROJECT}/kingdom.json}" ok=0 cmd
  [ -f "$kjson" ] || { echo "❌ run_tier1_gate: kingdom.json not found ($kjson) — failing closed" >&2; return 1; }
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    ( cd "$wt" && eval "$cmd" ) || ok=1
  done < <(jq -r '.gate.typecheck[]?' "$kjson" 2>/dev/null)
  return $ok
}
