#!/usr/bin/env bash
# kingdom function: carve_and_push_feature

carve_and_push_feature () {
  local lane="$1" topic="$2" sub_task_id="$3"

  # CORRECT — fast-forward checkout; no new commits
  git checkout -b "feature/$topic" "$lane"

  # Auto-generate PR body from task file (v0.18.0+)
  local pr_body=$(generate_pr_body_from_task_file "$lane" "$sub_task_id")
  local pr_title=$(get_pr_title_from_task_file "$lane" "$sub_task_id")

  git push -u origin "feature/$topic"
  gh pr create \
    --base develop \
    --head "feature/$topic" \
    --title "$pr_title" \
    --body "$pr_body"

  # After push, discard the kingdom overlay (different concern — kingdom branch)
  kingdom_discard_overlay
}
