#!/usr/bin/env bash
# kingdom function: run_tier2_on_story

run_tier2_on_story () {
  # Inputs: $1 = senior worktree (story branch checked out), $2 = kingdom.json path
  # Runs gate.tests + gate.smoke + gate.lint in the story worktree. Returns 0 if all pass.
  local wt="$1" kjson="$2" ok=1 key cmd
  for key in tests smoke lint; do
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      ( cd "$wt" && eval "$cmd" ) || { echo "❌ Tier-2 ($key) failed on story branch: $cmd" >&2; ok=0; }
    done < <(jq -r ".gate.$key[]?" "$kjson" 2>/dev/null)
  done
  [ "$ok" = 1 ] && echo "✅ Tier-2 passed on story branch"
  return $((1 - ok))
}
