# watchman-alert

**Fires when:** Watchman's `/loop` body emits one of the 8 canonical notification events.
**Used by:** [`watchman.md`](../roles/watchman.md) `/loop` body; receiver is the King's chat (via `cmux notify` to King's workspace).

## Template

```markdown
> [!${ALERT_FLAVOUR}]
> ```
> ╭─ 🕵️ ${LANE} · ${SEVERITY} ─────────────────────────────╮
> │  Event: ${EVENT_SUMMARY}                                │
> │  Details: ${EVENT_DETAILS}                              │
> │  Source: ${REPORT_PATH}                                 │
> │                                                         │
> │  ${ACTION_HINT}                                         │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${ALERT_FLAVOUR}` | derived from `${SEVERITY}` (see mapping below) | `WARNING` |
| `${LANE}` | watchman lane name | `watchman-1` |
| `${SEVERITY}` | `urgent` / `info` / `actionable` | `urgent` |
| `${EVENT_SUMMARY}` | one-line description | `develop smoke RED` |
| `${EVENT_DETAILS}` | key=value · key=value | `breaker=a1b2c3d4 · suspect_lane=worker-2 · stage=test` |
| `${REPORT_PATH}` | path to the `WATCH_*.md` report | `WATCH_DEV_RED_2026-05-18T11:24Z.md` |
| `${ACTION_HINT}` | one-line user prompt for next action | `Reply 'investigate' or 'ack' to dismiss.` |

## Severity → alert flavour

| `${SEVERITY}` | `${ALERT_FLAVOUR}` |
|---|---|
| `urgent` | `CAUTION` (red) — develop RED, gate breaker, blocked-lane critical |
| `actionable` | `WARNING` (amber) — PR ready to merge, lead comment incoming, gap finding |
| `info` | `NOTE` (blue) — develop advanced (cosmetic), watchman tick summary |

## 8 canonical events

(Defined in [cmux.md § Notification system](../reference/cmux.md#notification-system))

| Event | Severity | Example summary |
|---|---|---|
| `dev_red` | urgent | `develop smoke RED` |
| `dev_green` | info | `develop smoke recovered to GREEN` |
| `pr_ready` | actionable | `PR #258 mergeable, CI green, idle 30m` |
| `pr_blocked` | actionable | `PR #257 has unresolved review threads` |
| `lane_blocked` | urgent | `worker-1 stuck on permission prompt (14m)` |
| `gate_pass` | info | `worker-2 Tier-2 gate passed (8 min)` |
| `gate_fail` | urgent | `worker-3 Tier-1 gate failed: typecheck` |
| `gap_finding` | actionable | `3 task files have stale sentinels (closer skipped)` |

## Notes

- Watchman writes the full report at `${REPORT_PATH}` BEFORE firing the alert card. The card is a pointer; the report has the diagnostic detail.
- `${ACTION_HINT}` varies by event: `lane_blocked` says "Click the lane workspace + approve the prompt"; `pr_ready` says "Merge with `gh pr merge <N>` or schedule via your team's workflow"; `dev_red` says "Check `${REPORT_PATH}` for the breaking commit."
