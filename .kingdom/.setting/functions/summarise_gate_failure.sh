#!/usr/bin/env bash
# kingdom function: summarise_gate_failure

summarise_gate_failure () {
  # $1 = lane, $2 = id. Last failing lines from the newest test report, or a generic message.
  local rpt; rpt=$(latest_test_report "$@")
  if [ -n "$rpt" ] && [ -f "$rpt" ]; then grep -iE 'fail|error|✗' "$rpt" | tail -5; else echo "gate failed (see test report)"; fi
}
