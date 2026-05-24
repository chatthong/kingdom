#!/usr/bin/env bash
# kingdom function: random_task_done_line

random_task_done_line () {
  local pool_file="$WS/.kingdom/.setting/cards/task-complete.md"
  local last_file="$LOGS/.last-task-done-line"
  local last=$(cat "$last_file" 2>/dev/null || echo "0")

  # Extract the 20 numbered lines from the pool file
  mapfile -t lines < <(grep -E '^[0-9]+\. ' "$pool_file" | sed 's/^[0-9]\+\. //')
  local count=${#lines[@]}
  [ "$count" -eq 0 ] && return 0

  # Pick a random index that isn't last
  local idx
  while true; do
    idx=$((RANDOM % count))
    [ "$idx" != "$last" ] && break
  done
  echo "$idx" > "$last_file"
  echo "${lines[$idx]}"
}
