#!/usr/bin/env bash
# kingdom function: run_tier2_on_story

run_tier2_on_story () {
  # Inputs: $1 = senior worktree (story branch checked out), $2 = kingdom.json path
  # Runs gate.tests + gate.smoke + gate.lint in the story worktree. Returns 0 if all pass.
  local wt="$1" kjson="$2" ok=1 key cmd ran=0
  # C5: fail closed on a missing config — jq on a missing file emits nothing, the
  # loop never runs, and the function would return PASS on ZERO checks (the exact
  # bug run_tier1_gate/run_tier2_gate already guard against).
  [ -f "$kjson" ] || { echo "❌ run_tier2_on_story: kingdom.json not found ($kjson) — failing closed" >&2; return 1; }
  for key in tests smoke lint; do
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      ran=$((ran + 1))
      ( cd "$wt" && eval "$cmd" ) || { echo "❌ Tier-2 ($key) failed on story branch: $cmd" >&2; ok=0; }
    done < <(jq -r ".gate.$key[]?" "$kjson" 2>/dev/null)
  done
  # Gates must never pass vacuously: zero commands across tests/smoke/lint = misconfig.
  [ "$ran" -eq 0 ] && { echo "❌ run_tier2_on_story: no gate.tests/smoke/lint commands in $kjson — failing closed (a gate must verify something)" >&2; return 1; }
  [ "$ok" = 1 ] && echo "✅ Tier-2 passed on story branch"
  return $((1 - ok))
}
