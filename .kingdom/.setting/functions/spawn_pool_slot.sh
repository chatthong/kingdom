#!/usr/bin/env bash
# kingdom function: spawn_pool_slot

spawn_pool_slot () {
  local result=$(cmux_tab_action new-terminal-right \
    --workspace "$CMUX_WORKSPACE_ID" --focus false 2>&1)
  local surface=$(echo "$result" | grep -oE 'surface:[0-9]+' | head -1)
  [ -z "$surface" ] && return 1

  # v0.31.1: read model from config (default sonnet) and pass to claude -p.
  # Pool slots are long-lived; the cost gap between Opus and Sonnet matters here.
  local pool_model=$(jq -r '.cmux.subAgentPool.model // "sonnet"' "$KJSON")
  cmux_tab_action rename --surface "$surface" --title "🐱 sub · idle (pool, $pool_model)"
  # v0.31.1 fix: --model must come BEFORE -p (verified against cmux.md syntax).
  # Wrong: `claude -p --model sonnet`  Right: `claude --model sonnet -p`
  cmux_send "$surface" "claude --model $pool_model -p 'AWAITING_DISPATCH'"

  echo "$surface" >> "$LOGS/.subagent-pool-${CMUX_WORKSPACE_ID#workspace:}.list"
}
