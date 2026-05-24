#!/usr/bin/env bash
# kingdom function: pick_skills_for_task

pick_skills_for_task () {
  local task_id="$1" lane="$2"
  local routing="$WS/.kingdom/.setting/skill-routing.md"
  local task_file=$(ls -1t "$WS/.kingdom/$PROJECT/tasks/"*"__${lane}__${task_id}.md" 2>/dev/null | head -1)
  [ -f "$task_file" ] || return 0

  # Check for user override first
  if [ -n "$SKILL_OVERRIDE" ]; then
    [ "$SKILL_OVERRIDE" = "none" ] && return 0
    echo "$SKILL_OVERRIDE" | tr ',' '\n' | while read -r skill; do
      [ -n "$skill" ] && printf '  → Skill %s · user override\n' "$skill"
    done
    return 0
  fi

  # Build the search corpus: task file + linked reference files
  local corpus=$(cat "$task_file")
  for ref in $(grep -oE 'docs/[a-zA-Z0-9_/-]+\.md' "$task_file" 2>/dev/null | sort -u); do
    [ -f "$PROJ/$ref" ] && corpus+=$'\n'"$(cat "$PROJ/$ref" 2>/dev/null)"
  done
  corpus=$(echo "$corpus" | tr '[:upper:]' '[:lower:]')

  # Parse routing table — extract rows from the markdown table
  local picks=""
  awk -F'|' '/^\| (P1|P2|P3) \|/ {
    priority=$2; gsub(/^ +| +$/, "", priority);
    skill=$3;    gsub(/^ +| +$/, "", skill); gsub(/^`|`$/, "", skill);
    keywords=$4; gsub(/^ +| +$/, "", keywords);
    print priority "\t" skill "\t" keywords
  }' "$routing" | while IFS=$'\t' read -r priority skill keywords; do
    # Try each comma-separated keyword
    echo "$keywords" | tr ',' '\n' | while read -r kw; do
      kw=$(echo "$kw" | sed 's/^ *`//; s/` *$//; s/^ *//; s/ *$//')
      [ -z "$kw" ] && continue
      if echo "$corpus" | grep -qiwF "$kw"; then
        echo "$priority|$skill|$kw"
        break
      fi
    done
  done | sort -u | sort -t'|' -k1,1 | head -3 | while IFS='|' read -r priority skill kw; do
    printf '  → Skill %s · matches keyword: "%s"\n' "$skill" "$kw"
  done
}
