# cap-reached

**Fires when:** `cap=N` argument value hit by `${TASKS_DISPATCHED_TODAY}`.
**Used by:** [`commands/day.md`](../../../commands/day.md) Step 4 auto-dispatch + Step 5 poll loop.

## Template

```markdown
> [!WARNING]
> ```
> ╭─ 🛑 Daily cap reached ─────────────────────────────────╮
> │  cap=${CAP} hit · ${TASKS_DISPATCHED_TODAY} task-completions today
> │                                                         │
> │  Holding further dispatch. Lanes stay alive; in-flight  │
> │  work finishes, then idle.                              │
> │                                                         │
> │  To raise the cap: reply 'cap=${SUGGESTED_NEW_CAP}'     │
> │  (or any number).                                       │
> │  To stop fully: '/kingdom:exit'                         │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${CAP}` | the user-passed `cap=N` value | `5` |
| `${TASKS_DISPATCHED_TODAY}` | counter from poll loop | `5` |
| `${SUGGESTED_NEW_CAP}` | `${CAP} + 5` (round-up to nearest 5) | `10` |

## Response handling

| Reply | Action |
|---|---|
| `cap=N` (any number > current) | King updates `$CAP`; dispatch resumes if N > current count |
| `cap=none` | King removes the cap entirely; falls back to `target` (if set) or unbounded |
| `/kingdom:exit` | Day ends; lanes close gracefully |
| `hold` / anything else | King stays at cap, waits for next instruction |

## Notes

- This card fires ONCE per cap-hit event (not every tick). King tracks `cap_announced` boolean to avoid spam.
- If `cap=N` is raised mid-day and later re-hit, this card fires again with updated counts.
- `${SUGGESTED_NEW_CAP}` rounds up to the nearest 5 for readability: cap=5 → suggest 10, cap=10 → suggest 15, cap=23 → suggest 25.
