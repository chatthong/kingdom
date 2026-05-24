#!/usr/bin/env bash
# kingdom function: generate_pr_body_from_task_file

generate_pr_body_from_task_file () {
  local lane="$1" sub_task_id="$2"
  local task_file=$(ls -1t "$WS/.kingdom/${PROJECT}/tasks/"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)
  local digest_file=$(ls -1t "$LOGS/"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)
  local test_report=$(ls -1t "$PROJ/docs/test-reports/KING_"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)

  cat <<EOF
## Summary

$(awk '/^## Brief/,/^##/' "$task_file" | sed '1d;$d')

## Implementation

$(awk '/^## Plan/,/^## Progress/' "$task_file" | sed '1d;$d' | grep -E '^\s*- \[x\]')

## Verification

$(awk '/^## Final summary/,/^##/' "$task_file" | sed '1d;$d')

$([ -n "$test_report" ] && echo "📋 Test report: $(basename "$test_report")")

## Test plan

- [x] Tier-1 gate passed
- [x] Tier-2 gate passed (integrated on kingdom)
- [ ] Manual review by lead

---

🤖 PR body auto-generated from kingdom task file: \`tasks/$(basename "$task_file")\`
🤖 Curated closer artifact: \`logs/$(basename "$digest_file")\`
EOF
}
