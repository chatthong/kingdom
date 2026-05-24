#!/usr/bin/env bash
# kingdom function: latest_test_report

latest_test_report () {
  # $1 = lane, $2 = id. Newest KING_/LANE_ test report matching this lane+id.
  local lane="$1" id="$2" dir="${PROJ:-$PWD}/docs/test-reports"
  ls -1t "$dir"/*"${lane}__${id}.md" 2>/dev/null | head -1
}
