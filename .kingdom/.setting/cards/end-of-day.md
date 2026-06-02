# end-of-day

**Fires when:** `/kingdom:save` runs, OR `pr-limit=N` / `pod-limit=N` hit + no in-flight gates pending, OR all lanes idle + no pending work + no in-flight PRs.
**Used by:** [`commands/save.md`](../../../commands/save.md); [`commands/work.md`](../../../commands/work.md) Step 5 stopping conditions.

## Template

```markdown
> [!TIP]
> ```
> ╭─ 🌙 Day complete · ${PROJECT} ─────────────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │                                                         │
> │  Tasks done:    ${TASKS_DONE}  (target ${BUDGET_TODAY} ${TARGET_HIT_INDICATOR})
> │  PRs pushed:    ${PRS_PUSHED}                           │
> │  PRs merged:    ${PRS_MERGED}  ${MERGED_PR_NUMBERS}     │
> │  Pending PRs:   ${PRS_PENDING}  (waiting on lead review)│
> │  Gates run:     ${GATES_RUN} (${GATES_FAILED} fail${FAIL_NOTE})
> │                                                         │
> │  Week to date:  ${WEEK_DONE} / ${WEEK_TARGET} target  (${WEEK_PCT}, ${PACE_STATUS})
> │                                                         │
> │  ${EXIT_HINT}                                           │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | active project | `my-app` |
| `${LOCAL_DATETIME}` | `date '+%A, %B %-d, %Y · %H:%M %Z'` | `Monday, May 18, 2026 · 21:42 +07` |
| `${TASKS_DONE}` | sentinel count for today | `7` |
| `${BUDGET_TODAY}` | parse_target daily band | `6-10` |
| `${TARGET_HIT_INDICATOR}` | `✅` if within band, `⚠ over` / `⚠ under` if outside | `✅` |
| `${PRS_PUSHED}` | count of `gh pr create` calls today | `4` |
| `${PRS_MERGED}` | count of PRs flipped to MERGED today | `2` |
| `${MERGED_PR_NUMBERS}` | comma list in parens, e.g. `(#254, #255)`, or empty | `(#254, #255)` |
| `${PRS_PENDING}` | currently open PRs from this kingdom | `2` |
| `${GATES_RUN}` | total gate fires today (Tier-1 + Tier-2) | `11` |
| `${GATES_FAILED}` | failed gates | `1` |
| `${FAIL_NOTE}` | `, dispatched fix` if all fails got a fix-task, else empty | `, dispatched fix` |
| `${WEEK_DONE}` | sentinel count for ISO week | `18` |
| `${WEEK_TARGET}` | weekly band from parse_target | `30-50/week` |
| `${WEEK_PCT}` | `${WEEK_DONE} / mid(${WEEK_TARGET}) * 100` rounded | `60%` |
| `${PACE_STATUS}` | `on pace` / `behind` / `ahead` based on day-of-week vs % | `on pace` |
| `${EXIT_HINT}` | `Run /kingdom:save to close lanes gracefully.` (when not invoked by save) OR `Lanes closed. Conversation kept alive.` (when invoked by save) | `Run /kingdom:save to close lanes gracefully.` |

## Notes

- When invoked by `/kingdom:save`, the `${EXIT_HINT}` says "Lanes closed. Conversation kept alive." (or "King workspace closed too" if `--include-king`).
- When invoked by `pr-limit=N` / `pod-limit=N` hit, `${EXIT_HINT}` says "Limit reached. Reply 'pr-limit=10' (or 'pod-limit=N') to raise; or run /kingdom:save."
- When invoked by all-idle, `${EXIT_HINT}` says "No pending work. Run /kingdom:save when done, or queue more tasks."
