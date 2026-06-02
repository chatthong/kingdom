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
  local rc=0
  for pid in $pids; do
    while kill -0 "$pid" 2>/dev/null; do
      local now=$(date +%s)
      if [ $((now - start)) -ge "$max" ]; then
        local survivors=""
        for p in $pids; do
          kill -0 "$p" 2>/dev/null && { kill -9 "$p" 2>/dev/null; survivors="$survivors $p"; }
        done
        echo "⚠️ _bounded_wait timeout after ${max}s; killed:$survivors" >&2
        return 124
      fi
      sleep 0.5
    done
    wait "$pid" 2>/dev/null
    local pid_rc=$?
    [ "$pid_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$pid_rc"
  done
  return $rc
}
