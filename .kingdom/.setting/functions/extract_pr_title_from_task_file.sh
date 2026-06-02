#!/usr/bin/env bash
# kingdom function: extract_pr_title_from_task_file

extract_pr_title_from_task_file () {
  # $1 = lane, $2 = id. PR title = the task file's "# Task: <id> — <title>" first line.
  local lane="$1" id="$2" tasks="${TASKS_DIR:-$PWD/.kingdom/${PROJECT}/tasks}" tf
  tf=$(ls -1t "$tasks"/*"__${lane}__${id}.md" 2>/dev/null | head -1)
  if [ -n "$tf" ]; then head -1 "$tf" | sed 's/^#\{1,\} *//; s/^Task: *//'; else echo "$id"; fi
}
