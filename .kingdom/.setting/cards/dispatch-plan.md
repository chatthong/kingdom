# dispatch-plan

**Fires when:** `/kingdom:work` kickoff, fourth card.
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 3.

## Template

```markdown
> [!NOTE]
> ```
> ╭─ Today's plan (within target ${BUDGET_TODAY}) ─────────╮
> │  • worker-1     → ${LANE_1_ASSIGNMENT}                  │
> │  • worker-2     → ${LANE_2_ASSIGNMENT}                  │
> │  • worker-3     → ${LANE_3_ASSIGNMENT}                  │
> │  • co-worker-1  → ${COWORKER_ASSIGNMENT}                │
> │  • watchman-1   → /loop running (5-15 min)              │
> │                                                         │
> │  Dispatched: ${N_DISPATCHED} / target ${BUDGET_TODAY}   │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${BUDGET_TODAY}` | parse_target daily band, or `unbounded` | `6-10` |
| `${LANE_N_ASSIGNMENT}` | task ID assigned to lane, or `(held)` / `(held for paired work)` | `BE-P0-AUTH.2` |
| `${COWORKER_ASSIGNMENT}` | co-worker assignment (usually `(held for paired work)`) | `(held for paired work)` |
| `${N_DISPATCHED}` | count of lanes with active dispatch this cycle | `2` |

## Notes

- One bullet per lane in `kingdom.json.shape`. Card auto-extends if there are more workers / co-workers / watchmen.
- `(held)` = lane is idle by design this cycle (no fitting task in queue).
- `(held for paired work)` = co-workers default to held until user activates with `"pair on co-worker-N"`.
- Watchmen always show `/loop running (5-15 min)` regardless of dispatch state.
