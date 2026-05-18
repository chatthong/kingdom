# task-complete

**Fires when:** Tier-2 gate passes on a lane's overlay; just before `push-prompt` fires.
**Used by:** [`commands/day.md`](../../../commands/day.md) Step 5 auto-gate-poll loop.

## Template

```markdown
> [!TIP]
> ```
> ╭─ ✨ Task complete ─────────────────────────────────────╮
> │  ${LANE} · ${TASK_ID} · ${DURATION}                     │
> │  ${RANDOM_LINE}                                         │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane name from sentinel path | `worker-2` |
| `${TASK_ID}` | task ID from sentinel path | `FE-P0-FOUND.7` |
| `${DURATION}` | wall-clock from dispatch to sentinel | `12 min` |
| `${RANDOM_LINE}` | pick one from the pool below; rotation respects last-seen | (see pool) |

## Random pool (20 lines)

`random_task_done_line` helper in `_primitives.md` picks one of these on each fire. The helper avoids repeating the most-recent pick by keeping a small ring buffer in `<LOGS>/.last-task-done-line`.

1. Lane idle. Want me to dispatch the next one?
2. That's ${N_DONE_TODAY} tasks closed today. ${REMAINING} more to hit target.
3. Coffee break earned. ☕
4. Lead's review queue +1.
5. Fast work, ${DURATION} dispatch to gate-green.
6. Two-tier gate green. Push when ready.
7. Three tasks done in a row. Momentum. 🚀
8. Half-way to today's target band.
9. Today's target band reached. Continuing at a chiller pace.
10. 🎯 Bullseye.
11. ${LANE} just shipped. Other lanes already on the next ones.
12. Closer fired. Audit trail logged. Sentinel touched.
13. Clean diff. ~${N_FILES} files, 0 conflicts.
14. PR body auto-written from task file. Saved 5 min.
15. Watchman sees no fallout on develop smoke.
16. Slow and steady today, ${N_DONE_TODAY} tasks done. Quality > speed.
17. Hour ${HOUR_OF_DAY} · ${N_DONE_TODAY} done. Good pace.
18. Did you eat? 🍜
19. Walking break suggested. The kingdom can wait.
20. Bird outside? 🐦 Look up for 30 seconds. Then push.

## Sub-variables (inside random lines)

| Var | Source |
|---|---|
| `${N_DONE_TODAY}` | sentinel count for today in local TZ |
| `${REMAINING}` | `${BUDGET_TODAY_HI} - ${N_DONE_TODAY}` clamped at 0 |
| `${N_FILES}` | `git diff --stat origin/develop..${LANE} \| tail -1` files-changed count |
| `${HOUR_OF_DAY}` | `date '+%-H'` |

## Notes

- The pool is plain prose, NOT lane-shaming or pressure-y. Lines 18/19/20 are "rest reminders" — fire ~10% of the time so the kingdom feels like a coworker, not a drill sergeant.
- To customise per-workspace: edit the workspace copy of this file at `.kingdom/.setting/cards/task-complete.md`.
