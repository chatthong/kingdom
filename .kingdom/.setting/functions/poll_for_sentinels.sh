#!/usr/bin/env bash
# kingdom function: poll_for_sentinels

poll_for_sentinels () {
  # $1 = name glob under <LOGS>/done (e.g. "audit-*"); $2 = timeout secs (default 180).
  local pat="$1" budget="${2:-180}" logs="${LOGS:-$PWD/.kingdom/${PROJECT}/logs}" start
  start=$(date +%s)
  while [ $(( $(date +%s) - start )) -lt "$budget" ]; do
    ls "$logs"/done/${pat}*.flag >/dev/null 2>&1 && { echo "sentinels present: $pat"; return 0; }
    sleep 5
  done
  echo "poll_for_sentinels: ${budget}s timeout waiting for $pat" >&2; return 124
}
