#!/usr/bin/env bash
# kingdom function: watchman_cross_story_scan

watchman_cross_story_scan () {
  # Inputs: $1 = PROJ. Pairwise git merge-tree across in-flight story branches.
  # Echoes a drift summary the King consumes at push time. Cheap; runs each watchman tick.
  local proj="$1" out="" i j
  local arr=($(git -C "$proj" for-each-ref --format='%(refname:short)' 'refs/heads/story/*'))
  for ((i=0; i<${#arr[@]}; i++)); do
    for ((j=i+1; j<${#arr[@]}; j++)); do
      if git -C "$proj" merge-tree --write-tree "${arr[i]}" "${arr[j]}" 2>/dev/null | grep -qiE '^CONFLICT|<<<<<<<'; then
        out="$out ${arr[i]}<->${arr[j]}"
      fi
    done
  done
  [ -n "$out" ] && echo "⚠️ cross-story drift:$out" || echo "✅ no cross-story drift"
}
