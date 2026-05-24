#!/usr/bin/env bash
# kingdom function: find_ungated_sentinels

find_ungated_sentinels () {
  for FLAG in "$LOGS"/done/*.flag; do
    [ -f "$FLAG" ] || continue
    BASE=$(basename "$FLAG" .flag)
    LANE=$(echo "$BASE" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    SUBTASK_ID=$(echo "$BASE" | sed 's/.*__//')

    # Already gated? (test report exists)
    if ! ls "$PROJ/docs/test-reports/KING_"*"__${LANE}__${SUBTASK_ID}.md" >/dev/null 2>&1; then
      echo "UN_GATED: $LANE / $SUBTASK_ID"
    fi
  done
}
