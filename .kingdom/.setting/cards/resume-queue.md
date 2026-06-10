# resume-queue

**Fires when:** `/kingdom:work` Step 0.6 scan finds in-flight task files (per [R33](../rules/R33-king-must-read-existing-task.md)).
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 0.6 — renders BEFORE `suggested-task`.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ ⏯ Resume in-flight work · ${PROJECT} ─────────────────╮
> │  ${N_RESUME} task(s) mid-flight from prior session(s):  │
> │                                                         │
> │  ${RESUME_LIST}                                         │
> │                                                         │
> │  ${N_DECISION} task(s) blocked, awaiting your call:     │
> │                                                         │
> │  ${DECISION_LIST}                                       │
> │                                                         │
> │  Per R33: King will resume these BEFORE opening new     │
> │  task files. Reply 'resume all' to re-dispatch every    │
> │  in-flight task, or pick a number to focus.             │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | project name | `my-app` |
| `${N_RESUME}` | count of items in `${RESUME_LIST}` | `2` |
| `${RESUME_LIST}` | one bullet per resume item: `  • <lane> · <task-id> · status=<status> · last note: <last-progress-line>` | (multi-line, see below) |
| `${N_DECISION}` | count of items in `${DECISION_LIST}` | `1` |
| `${DECISION_LIST}` | one bullet per decision item: `  • <lane> · <task-id> · blocked on: <blocker-summary>` | (multi-line) |

## Example `${RESUME_LIST}` rendering

```text
  • worker-1 · FE-P0-FOUND.5 · status=discovery-complete
    last note: Layer-1 scan done; 2 soft blockers surfaced (A, B)
  • worker-3 · FE-P0-FOUND.10 · status=executing
    last note: Layer-3 batch 4 of 7 in progress
```

## Example `${DECISION_LIST}` rendering

```text
  • worker-1 · FE-P0-FOUND.5
    blocker A: legal:terms translation_key seed
    blocker B: @workspace/db dep route via shop or account?
```

## Empty-queue behaviour

If both queues are empty, this card is **not rendered**. The kickoff flow jumps straight from `daily-status` to `suggested-task`.

If only one queue has items, drop the empty section + its heading. E.g., if `${N_DECISION}=0`, drop the `${N_DECISION} task(s) blocked...` line + `${DECISION_LIST}` line.

## Response handling

| Reply | Action |
|---|---|
| `resume all` | King re-dispatches every `${RESUME_LIST}` item with `[RESUME]` flag in the brief, pointing at the same task ID + last progress note. Decision-queue items get surfaced for unblock first. |
| `resume <lane>` or pick a number | King resumes only that lane's in-flight task; other lanes continue from queue. |
| `unblock <task-id>` | User provides the missing info; King writes it into the task file as a `## Progress notes` entry, then dispatches `[RESUME]`. |
| `cancel <task-id>` | User explicitly cancels; King flips the task file Status to `cancelled` + appends a sentinel; lane is freed for new dispatch. |
| `go` or `skip` | Ignore resume queue this cycle; proceed to new dispatch (treats in-flight tasks as paused; King re-surfaces them on next `/kingdom:work`). |

## Why this card matters

Without R33 + this card, King at session start jumps straight to "Suggested next task" picked from the project ledger, ignoring `.kingdom/<project>/tasks/` entirely. Lanes that had in-flight work yesterday get a NEW task file today, orphaning the old one. Sentinel mismatches accumulate. Worker-1 ends up with two task files for overlapping work. The audit trail corrupts.

Incident (2026-05-19): King ignored a worker-1 task file marked `discovery-complete` (2 soft blockers needing user input) and instead surfaced fresh project-ledger candidates. ~5 minutes lost before user manually said "scan on current branch we start work for 3 brach already, recheck at task".
