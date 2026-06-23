### R55. Shared broker inbox — one feed, everyone reads, the addressed actor acts — Tier 2

A lane that hits a question or a flag MUST NOT freeze waiting for the King to notice. And the King must not miss messages that only fire a transient badge it cannot "see." Real-world failure (a week of fleet driving): lanes had no non-stalling escalation path; they either guessed wrong or sat dead at a prompt. The fix is a **single shared broker feed** — one flat directory, fully visible to all actors, with the *addressed* actor owning the reply.

**Why broker, not per-recipient mailboxes.** Per-recipient subdirectories (`inbox/<recipient>/`) meant a message to the King lived in a directory the King never checked unless it knew to look, and cross-actor visibility (watchman noticing a question aging > 2 ticks) required scanning all subdirs. A flat feed with `<to>` in the filename gives every actor full audit visibility from one location and lets the watchman triage without special-casing.

---

#### Store layout

```
$WS/.kingdom/<project>/inbox/           ← single flat directory; all pending messages
$WS/.kingdom/<project>/inbox/.archive/  ← consumed messages (move, never delete)
```

`$WS` defaults to `$PWD`; `$PROJECT` must be set before any helper call.

---

#### Filename format

```
<UTC>__<from>__<to>__<type>.md
```

`UTC` = `date -u +%Y-%m-%dT%H%MZ` (e.g. `2026-06-23T1042Z`).

---

#### Front matter (YAML-fenced)

```
---
from: <actor>
to: <actor>
type: <type>
task: <task_id>
needs-reply: yes|no
---
<free-text body>
```

**Actors** (`from` / `to`): `king | worker-N | co-worker-N | senior-N | watchman-N | all`
- `all` = broadcast; everyone reads; nobody specifically owns — every actor reads and acts on content relevant to them, but nobody must reply.

**Types**: `question | flag | info | memory-request | docs-update`

---

#### Semantics — everyone reads, the addressed actor acts

- **Full feed visibility.** Every actor MAY read the entire pending feed at any time. This is the point: the watchman can age-check the King's queue; a Senior can see an unblocking `flag` that affects its story; the King can spot a worker-to-worker `info` without being the `to`.
- **Ownership.** The actor whose `to` matches (`to == me`, or `to == all`) **owns** the action, reply, and consume. A non-addressed reader NEVER consumes someone else's message.
- **Anyone can bell anyone, including the King.** `inbox_send king question ...` is the canonical escalation. `inbox_send watchman-1 flag ...` routes to watchman. `inbox_send all info ...` broadcasts.
- **Consume = move to `.archive/`.** After handling, the addressed actor moves the file. Consumed messages are never deleted — the archive is the audit trail.

---

#### Helper signatures

All helpers: `#!/usr/bin/env bash`, zsh-safe. **Never** name a local variable `path`, `fpath`, `cdpath`, or `manpath` — zsh ties those to `$PATH` (v0.43.1 bug). Use `srcfile`, `msgfile`, `dir`, `proj` instead. Guard on missing `$PROJECT`.

```bash
inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>
```
Write one file into `inbox/` named `<UTC>__<from>__<to>__<type>.md` with the front matter above. `from = "${LANE:-${KINGDOM_ROLE:-king}}"`. Then **doorbell**: resolve `<to>`'s workspace ref from `$WS/.kingdom/$PROJECT/logs/workspace-refs.env` — try `^<to>_WS=` then the uppercased form (`printf '%s' "$to" | tr 'a-z-' 'A-Z_'`) — and call `cmux_notify` best-effort if the ref exists. The file is the source of truth; a notify failure is non-fatal.

```bash
inbox_list [--to <recipient>] [--from <who>]
```
Default: list the whole pending feed (exclude `.archive/`), oldest-first, one path per line. `--to <me>`: only messages where `to == me` OR `to == all`. `--from <who>`: filter by `from`. Returns 0 with empty output when none. zsh: `setopt local_options no_nomatch`.

```bash
inbox_read <file> [--consume]
```
Print the file. `--consume`: `mkdir -p inbox/.archive && mv` the file there.

```bash
inbox_reply <to> <task_id> <message...>
```
Sugar: `inbox_send <to> info <task_id> no <message...>`.

```bash
inbox_pending_count [--to <recipient>]
```
Echo an integer count of pending messages (whole feed, or `to==me/all` with `--to`). Echo `0` on any error; never a non-zero exit.

---

#### Lane side (non-blocking — the whole point)

- When you hit a decision blocker, post `inbox_send king question <task> yes "..."` (or `flag` for a problem), set your cmux state to `❓ waiting on King`, render the [`lane-question`](../cards/lane-question.md) card, and **keep working on any continuable part of the task.** Never sit dead.
- Check your own inbox (`inbox_list --to <self>`) at **task start**, **when blocked**, and **before the closer** — fold any reply in before you proceed or close.

---

#### King side — drain the inbox EVERY TURN, not only the poll loop

The King-as-model only sees inbox content when it *runs* `inbox_list`; a `cmux_notify` is a human-facing badge, invisible to the model. Therefore the King MUST drain and consume its inbox (`to==king` or `to==all`) at **every turn where it acts or replies to the user** — at minimum:

1. Session kickoff (Step 0 of `commands/work.md`)
2. Every dispatch decision (Step 4)
3. Every push / gate decision (Step 7)
4. Whenever it returns any response to the user

Consume-and-archive is **mandatory** after handling. A message left unconsumed re-appears in the next `inbox_list`; the inbox must be a live queue, not an accumulating pile.

For each pending item addressed to the King:
- **`question` / `flag`** → answer with `inbox_reply <lane> <task> "..."` + `cmux_send` nudge to the lane. Escalate to the user only if a genuine human decision is required.
- **`memory-request`** → validate against R34 + existing memory; write the memory if valid (R54); reply to the lane.
- **`info` / `docs-update`** → acknowledge, act if needed, archive.

---

#### Doorbell fix — KING_WS in workspace-refs.env

`commands/work.md` MUST write `KING_WS=<ref>` into `workspace-refs.env` at spawn (idempotently: strip any existing `KING_WS=` line, then append the current one), alongside the existing `<lane>_WS=` writes. Without this, `inbox_send king ...` cannot resolve the doorbell target and the King receives file-only messages with no badge.

---

#### Legacy-store convergence

Prior versions wrote King-side messages to `$WS/.kingdom/<project>/king-inbox/`, `.../logs/king-inbox/`, and `.../king-inbox.md`. The King-session drain ALSO sweeps these legacy stores: read, action, then archive (move to the nearest `.archive/` equivalent). Going forward everyone writes **only** to `inbox/`. Do not delete legacy data; archive it. The migration is complete when the legacy paths are empty.

---

**Why Tier 2.** Skipping the inbox doesn't lose committed data or break a gate, but it directly re-opens the "lane stalls silently / guesses wrong" decay path that motivated this rule. The sentinel flag (R22) remains the load-bearing completion signal; the inbox is for *questions*, never task hand-off. See [`watchman.md`](../roles/watchman.md) → Inbox triage assist (watchman nudges the King on questions waiting > 2 ticks), and each role doc's "Talking to the King" section. R54 (memory writes) funnels through this inbox.
