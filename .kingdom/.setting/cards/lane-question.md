# lane-question

**Fires when:** a lane (worker / co-worker / senior / watchman) needs a decision from any other actor and posts an inbox `question` (R55). The `<to>` field is whoever owns the answer — usually the King but can be any lane. Rendered in the sender's own reply so the user sees what was asked while the sender keeps working on continuable parts.
**Used by:** [`worker.md`](../roles/worker.md), [`co-worker.md`](../roles/co-worker.md), [`senior.md`](../roles/senior.md), [`watchman.md`](../roles/watchman.md) — "Replying with cards" + "Talking to the King".

## Template

```markdown
> [!WARNING]
> ```
> ╭─ ❓ Question · ${LANE} → ${TO} ────────────────────────╮
> │  Task: ${TASK_ID}                                       │
> │  Blocking: ${BLOCKING}                                  │
> │                                                         │
> │  ${QUESTION}                                            │
> │                                                         │
> │  Posted to shared inbox (needs-reply). Continuing on    │
> │  any unblocked parts; state set to ❓ waiting on ${TO}. │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | the asking lane's slug | `worker-2` |
| `${TO}` | the addressed recipient (the `<to>` field of the inbox message) | `king` or `senior-1` |
| `${TASK_ID}` | the lane's current task id | `FE-P0-FOUND.7` |
| `${QUESTION}` | the one-to-three-line question (same text as the inbox body) | `Two auth patterns exist (cookie vs header). Which is canonical?` |
| `${BLOCKING}` | `yes` if the lane cannot make any further progress without the answer; `no` if it queued the question and kept working | `no` |

## Notes

- This card is the lane's **non-blocking** signal: it has already run `inbox_send <to> question <task> yes "..."` (R55) and set its cmux state to `❓ waiting on <to>`. It does NOT stall the lane — it continues any continuable work and checks its own inbox (`inbox_list --to <self>`) between steps.
- `${BLOCKING}=yes` is the louder case: render this card AND make the inbox message the lane's last action before it idles. The watchman's inbox-triage duty scans the whole feed and nudges the addressed actor if a `needs-reply` question waits > 2 ticks (see [`watchman.md`](../roles/watchman.md) → Helper duty A).
- Keep it lightweight — one `render_card "lane-question"` call. No ANSI.
