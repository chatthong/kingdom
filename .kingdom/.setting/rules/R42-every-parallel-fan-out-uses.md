### R42. Every parallel fan-out uses `_bounded_wait`, never bare `wait` — Tier 1 (v0.30.0+)

Bare `wait` (no PID, no timeout) blocks until **every** backgrounded subshell exits. If one hangs — `git worktree add` blocked on `.git/index.lock`, `cmux send` to a not-yet-ready workspace, `gh pr view` on a stale network connection — the parent script hangs forever. The Claude Code harness then auto-pushes the bash call to background and the user sees "Job's output is empty and files weren't written."

This was the actual hang vector observed across v0.27-v0.29.4 in real consumer use (live cmux audit 2026-05-20: every cmux command itself returns in <0.65s — none of the perceived "cmux hangs" were cmux's fault; the hang was always a downstream subshell that bare `wait` couldn't time out).

**Required pattern:**

```bash
# WRONG (pre-v0.30.0):
for lane in $LANES; do
  ( spawn_master_workspace ... ) &
done
wait                   # ← if any subshell hangs, this never returns

# CORRECT (v0.30.0+):
PIDS=""
for lane in $LANES; do
  ( spawn_master_workspace ... ) &
  PIDS="$PIDS $!"
done
_bounded_wait 60 $PIDS    # ← kills survivors after 60s; returns 124 on timeout
```

**Budget guidance** is in [`functions/_bounded_wait.sh`](../functions/_bounded_wait.sh). Rough defaults: 5s for cosmetic cmux fan-outs, 15s for cmux teardown, 45s for `parallel_edit_fanout`, 60s for full lane spawn.

**Call sites that MUST use `_bounded_wait`:**

- `commands/work.md` Step 0.4 — King workspace-rename fan-out (5s) AND all-lane spawn cycle (60s)
- `commands/save.md` — teardown fan-out (15s)
- [`functions/parallel_edit_fanout.sh`](../functions/parallel_edit_fanout.sh) — per-lane PR-flip fan-out (45s)
- `.kingdom/.setting/roles/watchman.md` — orphan-tab sweep (10s)
- Any new parallel fan-out added in the future

**Anti-pattern banned:** `&` ... `&` ... `wait` (no PIDs collected, no timeout). Spotting this in a review = automatic block.

**Why Tier 1:** the user-visible failure mode (kingdom appears frozen, requires manual `TaskStop`, lanes half-spawned, dispatch never fires) corrupts the audit trail and forces a manual `/kingdom:save` + `/kingdom:work` cycle to recover. The cost of the disciplined pattern is ~6 lines of bash per fan-out; the cost of the failure mode is a debugging session every few days.
