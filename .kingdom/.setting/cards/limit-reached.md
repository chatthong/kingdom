# limit-reached

**Fires when:** `pr-limit=N` or `pod-limit=N` is hit (v0.33.0; replaces `cap-reached`).
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 4 auto-dispatch + Step 5 poll loop.

## Template

```markdown
> [!WARNING]
> ```
> ╭─ 🛑 ${LIMIT_KIND} reached ─────────────────────────────╮
> │  ${LIMIT_KIND}=${LIMIT_VAL} hit                         │
> │  PRs opened: ${PRS_OPENED_TODAY} · pods done: ${PODS_DONE_TODAY}
> │                                                         │
> │  Holding further dispatch. Lanes stay alive; in-flight  │
> │  work finishes, then idle.                              │
> │                                                         │
> │  To raise it: reply '${LIMIT_KIND}=${SUGGESTED_NEW}'    │
> │  To stop fully: '/kingdom:save'                         │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LIMIT_KIND}` | which limit fired | `pr-limit` or `pod-limit` |
| `${LIMIT_VAL}` | the user-passed limit value | `5` |
| `${PRS_OPENED_TODAY}` | PR counter from the poll loop | `5` |
| `${PODS_DONE_TODAY}` | pod counter from the poll loop | `3` |
| `${SUGGESTED_NEW}` | `${LIMIT_VAL} + 5`, rounded to nearest 5 | `10` |

## Response handling

| Reply | Action |
|---|---|
| `pr-limit=N` / `pod-limit=N` (> current) | King raises that limit; dispatch resumes if N > current count |
| `pr-limit=none` / `pod-limit=none` | King removes that limit |
| `/kingdom:save` | Day ends; lanes close gracefully |
| `hold` / anything else | King stays paused, waits for next instruction |

## Notes

- Fires ONCE per limit-hit event (not every tick). King tracks an announced flag per limit to avoid spam.
- `pr-limit` and `pod-limit` are independent ceilings; the card names whichever fired. Both can be active in one session.
