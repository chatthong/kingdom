#!/usr/bin/env bash
# kingdom function: spawn_subagent_from_pool

spawn_subagent_from_pool () {
  local model="$1" brief="$2"
  local pool_file="$LOGS/.subagent-pool-${CMUX_WORKSPACE_ID#workspace:}.list"
  local surface=$(head -1 "$pool_file" 2>/dev/null)

  if [ -z "$surface" ]; then
    spawn_subagent_tab "$model" "$brief"   # fall back to standard spawn
    return
  fi

  sed -i.bak '1d' "$pool_file" && rm "${pool_file}.bak"

  cmux_tab_action rename --surface "$surface" --title "🐱 sub · $model · $(echo "$brief" | head -c 30)"
  cmux_send "$surface" "$brief"

  spawn_pool_slot &   # refill pool in background
}
