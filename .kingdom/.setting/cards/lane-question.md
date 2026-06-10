# lane-question

**Fires when:** a lane (worker / co-worker / senior / watchman) needs a decision from the King and posts an inbox `question` (R55). Rendered in the lane's own reply so the user sees what it asked while it keeps working on continuable parts.
**Used by:** [`worker.md`](../roles/worker.md), [`co-worker.md`](../roles/co-worker.md), [`senior.md`](../roles/senior.md), [`watchman.md`](../roles/watchman.md) — "Replying with cards" + "Talking to the King".

## Template

```markdown
> [!WARNING]
> ```
> ╭─ ❓ Question for the King · ${LANE} ────────────────────╮
> │  Task: ${TASK_ID}                                       │
> │  Blocking: ${BLOCKING}                                  │
> │                                                         │
> │  ${QUESTION}                                            │
> │                                                         │
> │  Posted to king inbox (needs-reply). Continuing on any  │
> │  unblocked parts; state set to ❓ waiting on King.       │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | the asking lane's slug | `worker-2` |
| `${TASK_ID}` | the lane's current task id | `FE-P0-FOUND.7` |
| `${QUESTION}` | the one-to-three-line question (same text as the inbox body) | `Two auth patterns exist (cookie vs header). Which is canonical?` |
| `${BLOCKING}` | `yes` if the lane cannot make any further progress without the answer; `no` if it queued the question and kept working | `no` |

## Notes

- This card is the lane's **non-blocking** signal: it has already run `inbox_send king question <task> yes "..."` (R55) and set its cmux state to `❓ waiting on King`. It does NOT stall the lane — it continues any continuable work and checks its own inbox (`inbox_list <self>`) between steps.
- `${BLOCKING}=yes` is the louder case: render this card AND make the inbox message the lane's last action before it idles. The watchman's inbox-triage duty nudges the King if a `needs-reply` question waits > 2 ticks (see [`watchman.md`](../roles/watchman.md) → Inbox triage assist).
- Keep it lightweight — one `render_card "lane-question"` call. No ANSI.
