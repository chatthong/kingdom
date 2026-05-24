#!/usr/bin/env bash
# kingdom function: senior_merge_worker_into_story

senior_merge_worker_into_story () {
  # Inputs: $1 = senior worktree (on story/<id>), $2 = worker branch
  # Returns: 0 merged clean; 1 conflict (Senior resolves per R49; if unresolvable, abort + mark blocked)
  local wt="$1" wb="$2"
  local story=$(git -C "$wt" rev-parse --abbrev-ref HEAD)
  if git -C "$wt" merge --no-ff -m "merge $wb into $story" "$wb" >/dev/null 2>&1; then
    echo "✅ merged $wb into $story"
    return 0
  fi
  echo "⚠️ conflict merging $wb into $story. Senior resolves (R49); if contradictory worker intents, \`git merge --abort\`, mark story blocked, record detail, escalate to King. No silent overwrite." >&2
  return 1
}
