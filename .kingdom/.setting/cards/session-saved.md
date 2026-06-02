# session-saved

**Fires when:** `/kingdom:save` completes — state snapshot written to `state.json` and lane workspaces closed.
**Used by:** [`commands/save.md`](../../../commands/save.md) — renders as the final output of a successful save run.

## Template

```markdown
> [!TIP]
> ```
> ╭─ 💾 Session saved · ${PROJECT} ────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │                                                         │
> │  Snapshot: .kingdom/${PROJECT}/state.json               │
> │                                                         │
> │  Lane status:                                           │
> │  ${LANE_STATUS_LIST}                                    │
> │                                                         │
> │  Open PRs: ${N_OPEN_PRS} ${OPEN_PR_NUMBERS}             │
> │  Ready for fresh work next time: ${READY_FRESH}         │
> │                                                         │
> │  ${NEXT_HINT}                                           │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | active project | `my-app` |
| `${LOCAL_DATETIME}` | `date '+%A, %B %-d, %Y · %H:%M %Z'` | `Monday, May 19, 2026 · 09:15 +07` |
| `${LANE_STATUS_LIST}` | one bullet per lane (see format below) | (multi-line) |
| `${N_OPEN_PRS}` | count of open PRs from this kingdom | `2` |
| `${OPEN_PR_NUMBERS}` | comma list in parens, or empty string if zero | `(#257, #258)` |
| `${READY_FRESH}` | `✅ yes` if all lanes idle; `❌ no (lanes have in-flight work)` if any lane has an active task | `✅ yes` |
| `${NEXT_HINT}` | action prompt (see variants below) | `Lanes free. Pick fresh work next time.` |

## `${LANE_STATUS_LIST}` format

One bullet per configured lane. Two sub-formats:

**Lane has an in-flight task:**
```text
  • worker-1 · branch=worker-1 · task=FE-P0-FOUND.5 (status=discovery-complete)
```

**Lane is idle (no in-flight task file):**
```text
  • worker-1 · idle (no in-flight task)
```

Drop lanes that were never configured for the project (i.e., do not render a bullet for unconfigured lane slots).

## `${NEXT_HINT}` variants

| Condition | Value |
|---|---|
| All lanes idle (`${READY_FRESH}` = `✅ yes`) | `Lanes free. Pick fresh work next time.` |
| One or more lanes have in-flight work | `Run /kingdom:work ${PROJECT} when ready to resume.` |

## `${OPEN_PR_NUMBERS}` rendering

- If `${N_OPEN_PRS}` is `0`, drop `${OPEN_PR_NUMBERS}` and render: `Open PRs: 0`
- Otherwise render: `Open PRs: 2 (#257, #258)`

## Example rendering — mixed state

```text
> [!TIP]
> ```
> ╭─ 💾 Session saved · my-app ───────────────────────────╮
> │  Monday, May 19, 2026 · 09:15 +07                       │
> │                                                         │
> │  Snapshot: .kingdom/my-app/state.json                  │
> │                                                         │
> │  Lane status:                                           │
> │  • worker-1 · branch=worker-1 · task=FE-P0-FOUND.5     │
> │    (status=discovery-complete)                          │
> │  • worker-2 · idle (no in-flight task)                  │
> │  • worker-3 · branch=worker-3 · task=BE-M04-AUTH.2      │
> │    (status=executing)                                   │
> │  • worker-4 · idle (no in-flight task)                  │
> │                                                         │
> │  Open PRs: 2 (#257, #258)                               │
> │  Ready for fresh work next time: ❌ no (lanes have      │
> │    in-flight work)                                      │
> │                                                         │
> │  Run /kingdom:work my-app when ready to resume.        │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Example rendering — all idle

```text
> [!TIP]
> ```
> ╭─ 💾 Session saved · my-app ───────────────────────────╮
> │  Monday, May 19, 2026 · 17:44 +07                       │
> │                                                         │
> │  Snapshot: .kingdom/my-app/state.json                  │
> │                                                         │
> │  Lane status:                                           │
> │  • worker-1 · idle (no in-flight task)                  │
> │  • worker-2 · idle (no in-flight task)                  │
> │  • worker-3 · idle (no in-flight task)                  │
> │  • worker-4 · idle (no in-flight task)                  │
> │                                                         │
> │  Open PRs: 1 (#261)                                     │
> │  Ready for fresh work next time: ✅ yes                 │
> │                                                         │
> │  Lanes free. Pick fresh work next time.                 │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Notes

- `/kingdom:save` writes `state.json` BEFORE closing lane workspaces. If a lane workspace fails to close, the card still renders — the snapshot is the authoritative record.
- `state.json` captures: project name, save timestamp, per-lane task file path + status, open PR list. It is the source of truth for `/kingdom:resume` on next session start.
- This card is always `[!TIP]` flavour (green). There is no failure variant — if save fails partway, the command emits an error card instead (not this card).
- Long `${LANE_STATUS_LIST}` lines that exceed 58 chars wrap to the next `│`-prefixed line (indented two spaces) to stay within box bounds.
