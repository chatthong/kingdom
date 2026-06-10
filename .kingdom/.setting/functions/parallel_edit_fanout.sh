#!/usr/bin/env bash
# kingdom function: parallel_edit_fanout

parallel_edit_fanout () {
  # Inputs:
  #   $1 = search term            (literal string, no regex)
  #   $2 = replacement term       (literal string; the token %PR% is replaced PER LANE
  #                               with that lane's pr_number from the spec, so one call
  #                               can stamp a different PR number into each branch)
  #   $3 = lane spec              (space-separated: "worker-1=246 worker-2=247 co-worker-1=248")
  #                               format = "<lane>=<pr_number>"; pr_number resolves the lane's target PR
  #   $4 = file glob              (relative to lane worktree; default '**/*')
  # Outputs:
  #   per-lane stdout line: "OK <lane> <files_changed>" or "SKIP <lane> <reason>"
  #   exit 0 iff every lane succeeded or skipped cleanly
  [ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: split `$spec` in the for-loop (else 1 garbage iteration)
  local search="$1" replace="$2" spec="$3" glob="${4:-}"
  local rc=0 lane pr lane_wt pids=""
  local tmpdir=$(mktemp -d)
  # Clean the tmpdir on any exit path / signal so an early return never leaks it.
  trap 'rm -rf "$tmpdir"' EXIT INT TERM

  for unit in $spec; do
    lane="${unit%=*}"
    pr="${unit#*=}"
    # Per-lane replacement: substitute the %PR% token with THIS lane's pr. Done via
    # sed, NOT ${replace//%PR%/$pr} — that bash-ism is a silent no-op under zsh (both
    # native and `emulate -L sh`, which this function runs under), leaving the literal
    # token in the commit. `pr` is a bare integer from the spec, so no sed-escaping is
    # needed. A replacement with no token passes through unchanged → non-backfill
    # callers are unaffected.
    lane_replace=$(printf '%s' "$replace" | sed "s/%PR%/$pr/g")
    lane_wt="$WORKTREES/$lane"
    [ -d "$lane_wt" ] || { echo "SKIP $lane no-worktree" >> "$tmpdir/out"; continue; }

    # Each lane runs in its own subshell — parallel across branches,
    # but `switch → edit → amend → push` stays atomic within the branch.
    (
      cd "$lane_wt" || { echo "SKIP $lane cd-failed" >> "$tmpdir/out"; exit 0; }

      # R27: skip if PR already merged (force-push would touch a closed branch)
      if [ -n "$pr" ]; then
        state=$(gh pr view "$pr" --json state -q .state 2>/dev/null)
        [ "$state" = "MERGED" ] && { echo "SKIP $lane pr-merged" >> "$tmpdir/out"; exit 0; }
        [ "$state" = "CLOSED" ] && { echo "SKIP $lane pr-closed" >> "$tmpdir/out"; exit 0; }
      fi

      # Discover files containing the search term (scoped by glob if provided)
      if [ -n "$glob" ]; then
        files=$(rg -l --fixed-strings "$search" -g "$glob" 2>/dev/null)
      else
        files=$(rg -l --fixed-strings "$search" 2>/dev/null)
      fi
      [ -z "$files" ] && { echo "SKIP $lane no-matches" >> "$tmpdir/out"; exit 0; }

      # Apply replacement (literal, no regex — sed -i '' on macOS, sed -i on Linux)
      n=0
      while IFS= read -r f; do
        if [ "$(uname)" = "Darwin" ]; then
          sed -i '' "s|$(printf '%s' "$search" | sed 's/[][\/.*^$|]/\\&/g')|$(printf '%s' "$lane_replace" | sed 's/[\/&|]/\\&/g')|g" "$f"
        else
          sed -i "s|$(printf '%s' "$search" | sed 's/[][\/.*^$|]/\\&/g')|$(printf '%s' "$lane_replace" | sed 's/[\/&|]/\\&/g')|g" "$f"
        fi
        n=$((n + 1))
      done <<< "$files"

      # Amend + force-with-lease (R1 / R28 exclusive-sensitive — but limited to lane's
      # own short-lived worktree, not a primary branch; safe under R28's parallel-across-
      # branches clause). --force-with-lease bails if remote moved since fetch.
      git add -u 2>/dev/null
      if git diff --cached --quiet; then
        echo "SKIP $lane no-staged-changes" >> "$tmpdir/out"
        exit 0
      fi
      git commit --amend --no-edit >/dev/null 2>&1 || {
        echo "FAIL $lane amend-failed" >> "$tmpdir/out"
        exit 1
      }
      git push --force-with-lease >/dev/null 2>&1 || {
        echo "FAIL $lane push-failed" >> "$tmpdir/out"
        exit 1
      }
      echo "OK $lane $n" >> "$tmpdir/out"
    ) &
    pids="$pids $!"
  done
  # R42: bounded wait — each subshell does gh + sed + git commit + git push --force-with-lease;
  # network stalls on any one of those would block bare `wait` forever. 45s budget covers
  # the slowest credible case (push to slow remote × parallelism).
  _bounded_wait 45 $pids
  local wait_rc=$?
  [ "$wait_rc" -eq 124 ] && echo "FAIL _bounded_wait timeout — surviving subshells killed" >> "$tmpdir/out"

  # Aggregate + log
  cat "$tmpdir/out" 2>/dev/null
  if grep -q '^FAIL ' "$tmpdir/out" 2>/dev/null; then
    rc=1
  fi
  printf '%s  PARALLEL_EDIT_FANOUT  search=%q  replace=%q  result=%s\n' \
    "$(date -u +%FT%TZ)" "$search" "$replace" \
    "$([ $rc -eq 0 ] && echo ok || echo partial)" \
    >> "$LOGS/master_agent.log"
  # Normal path: clear the trap (so it never fires later on the host shell's exit) then clean up.
  trap - EXIT INT TERM
  rm -rf "$tmpdir"
  return $rc
}
