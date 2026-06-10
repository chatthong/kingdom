#!/usr/bin/env bash
# kingdom function: init_subagent_pool

init_subagent_pool () {
  # Fail closed: with $KJSON unset, jq fails silently and `seq 1 ""` counts DOWN
  # (1 0) on macOS — two phantom slots instead of a clean error.
  [ -n "${KJSON:-}" ] && [ -f "$KJSON" ] || { echo "❌ init_subagent_pool: \$KJSON unset or missing" >&2; return 1; }
  local pool_size=$(jq -r '.cmux.subAgentPool.perMasterPoolSize // 2' "$KJSON" 2>/dev/null)
  case "$pool_size" in (*[!0-9]*|'') pool_size=2 ;; esac
  for I in $(seq 1 "$pool_size"); do spawn_pool_slot & done
}
