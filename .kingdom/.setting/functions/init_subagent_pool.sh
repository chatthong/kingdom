#!/usr/bin/env bash
# kingdom function: init_subagent_pool

init_subagent_pool () {
  local pool_size=$(jq -r '.cmux.subAgentPool.perMasterPoolSize // 2' "$KJSON")
  for I in $(seq 1 "$pool_size"); do spawn_pool_slot & done
}
