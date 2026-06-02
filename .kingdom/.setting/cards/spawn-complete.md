# spawn-complete

**Fires when:** `/kingdom:work <project>` finishes spawning lanes (whether fresh-spawn or resume).
**Used by:** [`commands/work.md`](../../../commands/work.md); also as a sub-step of [`commands/work.md`](../../../commands/work.md) Step 2.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ 🚀 Kingdom spawned · ${PROJECT} ──────────────────────╮
> │  cmux.app sidebar:                                      │
> │    📌 👑 King (amber, pinned)                           │
> │       ${WORKER_ROSTER}                                  │
> │       ${COWORKER_ROSTER}                                │
> │       ${WATCHMAN_ROSTER}                                │
> │                                                         │
> │  All ${TOTAL_LANES} Claude sessions running.            │
> │  cmux_send dispatch active.                             │
> │  Watchman /loop scheduled (5-15 min).                   │
> │                                                         │
> │  ${MODE_NOTE}                                           │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | project name | `my-app` |
| `${WORKER_ROSTER}` | one-line `👷 worker-1 · worker-2 · worker-3 (violet)` | `👷 worker-1 · worker-2 · worker-3 (violet)` |
| `${COWORKER_ROSTER}` | one-line `🧑‍💼 co-worker-1 (blue)` (omit line if `co-workers=0`) | `🧑‍💼 co-worker-1 (blue)` |
| `${WATCHMAN_ROSTER}` | one-line `🕵️ watchman-1 (rose, split layout)` (omit if `watchman=0`) | `🕵️ watchman-1 (rose, split layout)` |
| `${TOTAL_LANES}` | King + all workers + co-workers + watchmen | `5` |
| `${MODE_NOTE}` | `Fresh spawn (created N worktrees).` OR `Resumed N existing lanes.` | `Resumed 5 existing lanes.` |

## Fallback-mode variants

When primary cmux.app mode is unavailable, swap the "cmux.app sidebar" header for the active mode:

| Mode | Replacement header |
|---|---|
| PRIMARY (cmux.app) | `cmux.app sidebar:` |
| FALLBACK (raw tmux) | `tmux session "kingdom-${PROJECT}":` |
| HEADLESS (`claude -p` chains) | `Headless processes:` |

## Notes

- Card replaces the previous "kingdom ready" stdout block in `commands/work.md`.
- If lanes had to be created (not resumed), `${MODE_NOTE}` says `Fresh spawn (created ${N} worktrees).` This signals the user that the first dispatch may take longer (no warm caches).
