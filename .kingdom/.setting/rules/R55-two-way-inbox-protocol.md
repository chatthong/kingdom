### R55. Two-way inbox protocol — lanes never stall silently — Tier 2 (v0.44.0)

A lane that hits a question or a flag MUST NOT freeze waiting for the King to happen to notice. Real-world failure (a week of fleet driving): lanes had no way to ask the King anything without stalling, so they either guessed wrong or sat dead at a prompt. The fix is a durable, file-backed, **non-blocking** inbox both directions.

**Directories + format.** `$WS/.kingdom/<project>/inbox/<recipient>/` where `<recipient>` ∈ `king | worker-N | co-worker-N | senior-N | watchman-N`. Handled messages move to `inbox/<recipient>/.archive/`. Each message is `<UTC>__<from>__<type>.md` with front matter (`from`, `to`, `type`, `task`, `needs-reply`) + a free-text body. Types: `question | flag | info | memory-request | docs-update`.

**Helpers** (in `functions/`): `inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>`, `inbox_list <recipient>`, `inbox_read <file> [--consume]`, `inbox_reply <lane> <task_id> <message...>` (King sugar), `inbox_pending_count <recipient>`.

**Lane side (non-blocking — the whole point):**
- When you need a decision or hit a blocker, post `inbox_send king question <task> yes "..."` (or `flag` for a problem), set your cmux state to `❓ waiting on King`, render the [`lane-question`](../cards/lane-question.md) card, and **keep working on any continuable part of the task.** Never sit dead waiting for a reply.
- Check your own inbox (`inbox_list <self>`) at **task start**, **when blocked**, and **before the closer** — fold any King reply in before you proceed/close.

**King side (triage every poll tick):**
- Each poll tick, `inbox_list king` (plus legacy `king-inbox/` for back-compat). For each item: answer with `inbox_reply <lane> <task> "..."` + a `cmux_send` nudge to the lane, OR escalate a genuine user-decision to the user. A `memory-request` → the King writes the memory itself (R54) then replies. Consume (`--consume` / move to `.archive/`) after handling so the inbox stays a live queue, not a pile.

**Why Tier 2:** skipping the inbox doesn't lose data or break a gate, but it directly removes the "lane stalls silently / guesses wrong" decay path — a strong default. The sentinel flag (R22) remains the load-bearing completion signal; the inbox is for *questions*, never task hand-off. See [`watchman.md`](../roles/watchman.md) → Inbox triage assist (the watchman nudges the King on questions waiting > 2 ticks), and each role doc's "Talking to the King" section.
