#!/usr/bin/env bash
# kingdom function: find_ungated_sentinels

find_ungated_sentinels () {
  # `find` instead of a `*.flag` shell glob: an empty done/ dir makes the glob
  # abort the function under zsh's NOMATCH. Locals everywhere — the old `BASE=`
  # leaked to the GLOBAL $BASE (= develop), silently corrupting the overlay base.
  local flag flag_base lane subtask_id
  [ -d "$LOGS/done" ] || return 0
  while IFS= read -r flag; do
    [ -f "$flag" ] || continue
    flag_base=$(basename "$flag" .flag)
    lane=$(echo "$flag_base" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    subtask_id=$(echo "$flag_base" | sed 's/.*__//')

    # Already gated? (King test report exists) — `find` so a no-match doesn't abort under zsh.
    if ! find "$PROJ/docs/test-reports" -name "KING_*__${lane}__${subtask_id}.md" 2>/dev/null | grep -q .; then
      echo "UN_GATED: $lane / $subtask_id"
    fi
  done < <(find "$LOGS/done" -maxdepth 1 -name '*.flag' 2>/dev/null)
}
