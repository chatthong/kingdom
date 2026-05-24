#!/usr/bin/env bash
# kingdom function: compute_task_duration

compute_task_duration () {
  # $1 = lane, $2 = id. Wall-clock = mtime(sentinel) - mtime(task file), as "N min".
  local lane="$1" id="$2" logs="${LOGS:-$PWD/.kingdom/${project}/logs}" tasks="${TASKS_DIR:-$PWD/.kingdom/${project}/tasks}" tf sf a b
  tf=$(ls -1t "$tasks"/*"__${lane}__${id}.md" 2>/dev/null | head -1)
  sf=$(ls -1 "$logs"/done/*"${lane}__${id}.flag" 2>/dev/null | head -1)
  if [ -n "$tf" ] && [ -n "$sf" ]; then
    a=$(stat -f %m "$tf" 2>/dev/null || stat -c %Y "$tf"); b=$(stat -f %m "$sf" 2>/dev/null || stat -c %Y "$sf")
    echo "$(( (b - a) / 60 )) min"
  else echo "unknown"; fi
}
