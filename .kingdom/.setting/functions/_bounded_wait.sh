#!/usr/bin/env bash
# kingdom function: _bounded_wait

_bounded_wait () {
  # Inputs:
  #   $1     = max_seconds   (global wall-clock budget; e.g. 60 for spawn, 30 for teardown)
  #   $2..$N = PIDs to wait for (default = all current background jobs from `jobs -p`)
  # Output:
  #   stderr line on timeout listing killed PIDs
  # Returns:
  #   0   — all PIDs exited cleanly within budget
  #   124 — global timeout; surviving PIDs killed (matches GNU `timeout` convention)
  #   N   — first non-zero per-PID exit code if any subshell errored
  #
  # CRITICAL: zsh does NOT word-split a plain `$var` (so `for pid in $pids` would iterate ONCE
  # over the whole joined string → the wait is a no-op). `emulate -L sh` gives sh-style word
  # splitting (+ 0-indexed arrays) for the rest of THIS function only, auto-restored on return.
  [ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null
  local max="$1"; shift
  local pids="${*:-$(jobs -p)}"
  [ -z "$pids" ] && return 0

  local start=$(date +%s)
  # locals declared OUTSIDE the loops — zsh re-echoes `name=value` on a repeat `local`
  local rc=0 now pid p pid_rc survivors
  for pid in $pids; do
    while kill -0 "$pid" 2>/dev/null; do
      now=$(date +%s)
      if [ $((now - start)) -ge "$max" ]; then
        survivors=""
        for p in $pids; do
          kill -0 "$p" 2>/dev/null && { kill -9 "$p" 2>/dev/null; survivors="$survivors $p"; }
        done
        # Reap the killed PIDs so no zombies linger past this function.
        for p in $survivors; do
          wait "$p" 2>/dev/null
        done
        echo "⚠️ _bounded_wait timeout after ${max}s; killed:$survivors" >&2
        return 124
      fi
      sleep 0.5
    done
    # PID finished within budget — collect its exit code, track the WORST non-zero rc.
    wait "$pid" 2>/dev/null
    pid_rc=$?
    [ "$pid_rc" -gt "$rc" ] && rc="$pid_rc"
  done
  return $rc
}
