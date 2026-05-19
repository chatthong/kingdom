# daily-status

**Fires when:** `/kingdom:work` kickoff, second card after `welcome`.
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 3.

## Template

```markdown
> [!NOTE]
> ```
> ╭─ Daily ritual · ${PROJECT} ────────────────────────────╮
> │  Counting unit: 1 task = 1 task file = 1 sentinel ≈ 1 PR
> │                                                         │
> │  Target: ${TARGET} → today's budget ${BUDGET_TODAY} tasks
> │         (this week: ${DONE_THIS_WEEK} done · ${IN_FLIGHT} in-flight · cap=${CAP})
> │                                                         │
> │  Context: rules.md · CLAUDE.md · README.md · docs/      │
> │           MEMORY.md · TER.md · watchman state           │
> │  Watchman: develop ${DEV_STATUS} @ ${LAST_TICK}         │
> │  PR queue: ${N_OPEN} open · ${N_MERGED_TODAY} merged today
> │  Lanes blocked: ${N_BLOCKED}                            │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | `$ARGUMENTS` resolved project | `bfg-swt` |
| `${TARGET}` | `target=` arg, or `(none)` | `30-50/week` |
| `${BUDGET_TODAY}` | `parse_target` daily band, or `unbounded` | `6-10` |
| `${DONE_THIS_WEEK}` | count of sentinels in `<LOGS>/done/` for the ISO week | `3` |
| `${IN_FLIGHT}` | task files with Status ∈ `planning|executing|verifying` | `5` |
| `${CAP}` | `cap=` arg, or `none` | `none` |
| `${DEV_STATUS}` | from `watchman_state.json` (`green` / `red` / `yellow`) | `green` |
| `${LAST_TICK}` | watchman last `/loop` tick timestamp in local TZ | `11:24 +07` |
| `${N_OPEN}` | `gh pr list --state open --json number \| jq length` | `4` |
| `${N_MERGED_TODAY}` | `gh pr list --state merged --search "merged:>=$(date +%F)" \| jq length` | `0` |
| `${N_BLOCKED}` | from `watchman_state.json.blocked_lanes` array length | `0` |

## Notes

- The counting-unit line is hardcoded (not a variable) because rules.md R23 + R25 fix the unit definition. Per kingdom contract: 1 sentinel = 1 task.
- `${BUDGET_TODAY}` ranges respect both `cap` (hard) and `target` (soft). If both passed, `cap` wins; the line reflects whichever is more restrictive.
