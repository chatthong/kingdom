#!/usr/bin/env bash
# kingdom function: compute_ready_for_fresh_work

compute_ready_for_fresh_work () {
  local state_json="$1"
  # true iff every lane in state.lanes has task=null AND uncommitted_files=0
  local has_in_flight
  has_in_flight=$(echo "$state_json" \
    | jq '[.lanes[] | select(.task != null or .uncommitted_files > 0)] | length')
  [ "$has_in_flight" = "0" ] && echo "true" || echo "false"
}
