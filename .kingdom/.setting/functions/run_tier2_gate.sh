#!/usr/bin/env bash
# kingdom function: run_tier2_gate

run_tier2_gate () {
  # Runs gate.tests + smoke + lint on the kingdom overlay (primary checkout on the kingdom branch). 0 = pass.
  # ${PROJECT} (exported), NOT ${project} — see run_tier1_gate (empty name → false pass).
  local kjson="${KJSON:-$PWD/.kingdom/${PROJECT}/kingdom.json}" ok=0 key cmd
  [ -f "$kjson" ] || { echo "❌ run_tier2_gate: kingdom.json not found ($kjson) — failing closed" >&2; return 1; }
  for key in tests smoke lint; do
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      ( cd "${PROJ:-$PWD}" && eval "$cmd" ) || ok=1
    done < <(jq -r ".gate.$key[]?" "$kjson" 2>/dev/null)
  done
  return $ok
}
