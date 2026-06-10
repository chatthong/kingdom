#!/usr/bin/env bash
# kingdom function: compute_task_duration

compute_task_duration () {
  # $1 = lane, $2 = id. Wall-clock = mtime(sentinel) - mtime(task file), as "N min".
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally instead of aborting "no matches found"; auto-reverts on return
  local lane="$1" id="$2" logs="${LOGS:-$PWD/.kingdom/${PROJECT}/logs}" tasks="${TASKS_DIR:-$PWD/.kingdom/${PROJECT}/tasks}" tf sf a b
  tf=$(ls -1t "$tasks"/*"__${lane}__${id}.md" 2>/dev/null | head -1)
  sf=$(ls -1 "$logs"/done/*"${lane}__${id}.flag" 2>/dev/null | head -1)
  if [ -n "$tf" ] && [ -n "$sf" ]; then
    a=$(stat -f %m "$tf" 2>/dev/null || stat -c %Y "$tf" 2>/dev/null); b=$(stat -f %m "$sf" 2>/dev/null || stat -c %Y "$sf" 2>/dev/null)
    echo "$(( (b - a) / 60 )) min"
  else echo "unknown"; fi
}
