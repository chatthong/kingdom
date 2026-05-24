#!/usr/bin/env bash
# kingdom function: compute_gate_duration

compute_gate_duration () {
  # $1 = lane, $2 = id. The King records gate start in $GATE_ELAPSED; this returns a label.
  echo "${GATE_ELAPSED:-a few min}"
}
