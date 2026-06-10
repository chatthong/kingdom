#!/usr/bin/env bash
# kingdom function: carve_and_push_feature

carve_and_push_feature () {
  local lane="$1" topic="$2" sub_task_id="$3"
  [ -n "$lane" ] && [ -n "$topic" ] || { echo "❌ carve_and_push_feature: usage: <lane> <topic> <sub_task_id>" >&2; return 1; }

  # CORRECT — fast-forward checkout; no new commits. Fail closed: a failed checkout
  # (branch exists, dirty tree) must NOT fall through to pushing whatever HEAD is.
  git checkout -b "feature/$topic" "$lane" \
    || { echo "❌ carve_and_push_feature: checkout -b feature/$topic from $lane failed — nothing pushed" >&2; return 1; }

  # Auto-generate PR body from task file (v0.18.0+)
  local pr_body=$(generate_pr_body_from_task_file "$lane" "$sub_task_id")
  local pr_title=$(get_pr_title_from_task_file "$lane" "$sub_task_id")

  git push -u origin "feature/$topic" \
    || { echo "❌ carve_and_push_feature: push failed for feature/$topic" >&2; return 1; }
  gh pr create \
    --base develop \
    --head "feature/$topic" \
    --title "$pr_title" \
    --body "$pr_body"

  # After push (R29), discard the kingdom overlay — ONLY now, never before push.
  # Pass the project root explicitly (this helper runs with cwd = project root).
  kingdom_discard_overlay "$PWD"
}
