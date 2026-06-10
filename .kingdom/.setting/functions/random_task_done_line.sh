#!/usr/bin/env bash
# kingdom function: random_task_done_line

random_task_done_line () {
  [ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: 0-indexed arrays (no `mapfile` in zsh — replaced below)
  local pool_file="$WS/.kingdom/.setting/cards/task-complete.md"
  local last_file="$LOGS/.last-task-done-line"
  local last=$(cat "$last_file" 2>/dev/null || echo "0")

  # Extract the numbered lines from the pool file. `mapfile` is bash-only (absent in zsh),
  # so build the array with a portable read loop.
  local lines=() l
  while IFS= read -r l; do lines+=("$l"); done < <(grep -E '^[0-9]+\. ' "$pool_file" | sed 's/^[0-9]\+\. //')
  local count=${#lines[@]}
  [ "$count" -eq 0 ] && return 0

  # H6: with a 1-line pool, `RANDOM % 1` is always 0; if last==0 the
  # "pick something != last" loop never breaks → session hang. Short-circuit.
  if [ "$count" -le 1 ]; then
    echo "0" > "$last_file"
    echo "${lines[0]}"
    return 0
  fi

  # Pick a random index that isn't last
  local idx
  while true; do
    idx=$((RANDOM % count))
    [ "$idx" != "$last" ] && break
  done
  echo "$idx" > "$last_file"
  echo "${lines[$idx]}"
}
