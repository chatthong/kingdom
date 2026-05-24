#!/usr/bin/env bash
# kingdom function: save_session_state

save_session_state () {
  local state_file="$WS/.kingdom/$PROJECT/state.json"
  local saved_at
  saved_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build the lanes object by iterating over lanes declared in kingdom.json
  local lanes_json
  lanes_json=$(jq -r '.shape | keys[]' "$KJSON" 2>/dev/null)
  [ -z "$lanes_json" ] && { echo "⚠️ save_session_state: no lanes in $KJSON" >&2; return 1; }

  local lanes_obj='{}'
  while IFS= read -r lane; do
    local worktree_path="$WS/.worktrees/$lane"
    local branch head_sha uncommitted task_obj

    # branch: the checked-out branch name (fall back to lane name if worktree absent)
    if [ -d "$worktree_path/.git" ] || [ -f "$worktree_path/.git" ]; then
      branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$lane")
      head_sha=$(git -C "$worktree_path" rev-parse --short HEAD 2>/dev/null || echo "unknown")
      uncommitted=$(git -C "$worktree_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    else
      branch="$lane"
      head_sha="unknown"
      uncommitted=0
    fi

    # task: find the most recent in-flight task file for this lane (no done/*.flag yet)
    local task_file
    task_file=$(ls -1t "$WS/.kingdom/$PROJECT/tasks/"*"__${lane}__"*.md 2>/dev/null \
      | while read -r f; do
          base=$(basename "$f" .md)
          subtask_id=$(echo "$base" | sed 's/.*__//')
          # skip if a done flag exists (task already closed)
          ls "$WS/.kingdom/$PROJECT/logs/done/"*"__${lane}__${subtask_id}.flag" >/dev/null 2>&1 \
            && continue
          echo "$f"
          break
        done)

    if [ -n "$task_file" ]; then
      local task_id status layer blockers_json
      task_id=$(basename "$task_file" .md | sed 's/.*__//')
      # Read Status and Layer fields from the task file header block
      status=$(grep -m1 '^Status:' "$task_file" 2>/dev/null | awk '{print $2}' || echo "unknown")
      layer=$(grep -m1 '^Layer:' "$task_file" 2>/dev/null | awk '{print $2}' || echo "")
      # Blockers: lines under a "## Blockers" section
      blockers_json=$(awk '/^## Blockers/,/^##/' "$task_file" 2>/dev/null \
        | grep '^- ' | sed 's/^- //' \
        | jq -Rs '[split("\n")[] | select(length > 0)]' 2>/dev/null || echo '[]')
      local rel_task_file="tasks/$(basename "$task_file")"
      task_obj=$(jq -n \
        --arg id "$task_id" \
        --arg tf "$rel_task_file" \
        --arg st "$status" \
        --arg ly "$layer" \
        --argjson bl "$blockers_json" \
        '{id: $id, task_file: $tf, status: $st, layer: $ly, blockers: $bl}')
    else
      task_obj="null"
    fi

    lanes_obj=$(echo "$lanes_obj" | jq \
      --arg lane "$lane" \
      --arg branch "$branch" \
      --arg sha "$head_sha" \
      --argjson uc "$uncommitted" \
      --argjson task "$task_obj" \
      '.[$lane] = {branch: $branch, head_sha: $sha, uncommitted_files: $uc, task: $task}')
  done <<< "$lanes_json"

  # Collect open PRs via gh CLI (silent if gh unavailable)
  local open_prs_json='[]'
  if command -v gh >/dev/null 2>&1; then
    open_prs_json=$(gh pr list --repo "$(git -C "$PROJ" remote get-url origin 2>/dev/null)" \
      --state open --json number,headRefName,state 2>/dev/null \
      | jq 'map({number: .number, branch: .headRefName, state: .state})' 2>/dev/null || echo '[]')
  fi

  local ready
  ready=$(compute_ready_for_fresh_work "$(jq -n --argjson l "$lanes_obj" '{lanes: $l}')")

  local state_json
  state_json=$(jq -n \
    --arg sv "1" \
    --arg ts "$saved_at" \
    --argjson lanes "$lanes_obj" \
    --argjson prs "$open_prs_json" \
    --argjson ready "$( [ "$ready" = "true" ] && echo "true" || echo "false" )" \
    '{schema_version: $sv, saved_at_utc: $ts, lanes: $lanes, open_prs: $prs, ready_for_fresh_work: $ready}')

  # Atomic write: tmp → mv (avoids partial reads if concurrent)
  local tmp
  tmp=$(mktemp "${state_file}.XXXXXX")
  printf '%s\n' "$state_json" > "$tmp" && mv "$tmp" "$state_file"
  echo "✅ state saved → $state_file"
}
