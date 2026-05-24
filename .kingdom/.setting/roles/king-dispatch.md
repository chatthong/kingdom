# king-dispatch.md — Dispatching a task to a lane

> Extracted from [`king.md`](king.md) (v0.35.0 modular reorg). How the King sends a task brief to a lane across all three host modes (cmux `send` primary / `tmux send-keys` fallback / `claude -p` headless) plus file-based completion polling.

See [`king.md`](king.md) for the King role overview, [`worker.md`](worker.md) for the 4-step closer, [`cmux.md`](../reference/cmux.md) for the cmux command reference.

---

## Dispatching a task to a lane

### Primary (`cmux send --workspace` via cmux.app)

In PRIMARY mode each master owns its own workspace (spawned in `commands/work.md` Step 0.4). Workspace refs are persisted at `$LOGS/workspace-refs.env` (sourced by King at session start):

```bash
source "$LOGS/workspace-refs.env"     # exposes KING_WS, WORKER_WS_1..N, COWORKER_WS_*, WATCHMAN_WS_*

PROMPT="Claim sub-task <SUBTASK_ID> from <task-source>. Work it in this worktree.
When you finish, run the 4-step closer (see worker.md):
  1) raw     -> $LOGS/raw/<ID>__opus-worker-1.md
  2) curated -> $LOGS/<ID>.md  (## TL;DR first)
  3) one-line status -> $LOGS/master_agent.log
  4) touch    $LOGS/done/<ID>__opus-worker-1.flag
     ALSO run: cmux notify --workspace $KING_WS \\
       --title '👑 ' --body 'lane worker-1 done: <ID>'
Spawn sub-agents as visible tabs by default (R38 — all models default to tab).
Use: cmux tab-action --action new-terminal-right --workspace $WORKER_WS_1
Tab-spawned sub-agents follow the 5-step closer (Step 5 = close own tab via
cmux tab-action --action close --surface \$CMUX_SURFACE_ID).
Background Agent() spawns are opt-in only (set spawn_mode: background in brief)."

# v0.31.0 R31+R36 hard gate: refuse to send brief if worker-1's cmux workspace
# is missing from the sidebar. Without this guard, the brief was historically
# routed into a void: dispatch returned success, no lane ever saw it, King
# polled forever for a sentinel that never came. The 2026-05-20 morning session
# burned ~3 hours on exactly this failure mode.
guard_lane_workspace_exists "worker-1" || { echo "❌ worker-1 workspace missing — spawn first"; exit 1; }

cmux send --workspace "$WORKER_WS_1" -- "$PROMPT"
cmux send --workspace "$WORKER_WS_1" Enter
```

No `-l` flag, no Enter ceremony, no escaping fights. The workspace ref is stable across the session — King addresses lanes by `$WORKER_WS_N` not by pane title.

### Fallback (`tmux send-keys -l` via raw tmux)

```bash
PANE=2                                                       # pane 1.2 = worker-1
tmux send-keys -t "$SESSION:$WIN.$PANE" -l "$PROMPT"         # -l = literal
tmux send-keys -t "$SESSION:$WIN.$PANE" Enter
```

### Headless (`claude -p`)

Skip both multiplexers — useful for CI / unattended runs:

```bash
( cd "$PROJ/.worktrees/worker-1" && claude -p "$PROMPT" )    # blocks until lane completes
```

Same 4-step closer artifact protocol in all three modes.

### Polling completion (file-based, all modes)

```bash
until [ -f "$LOGS/done/${ID}__opus-worker-1.flag" ]; do sleep 5; done
tail -n 1 "$LOGS/master_agent.log"
```

See [`worker.md`](worker.md) → 4-step closer for the artifact format.
