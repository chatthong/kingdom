# what-to-work-on

**Fires when:** `/kingdom:work` invoked with no args (interactive mode, v0.28.0+).
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 0.0.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ 👑 What do you want to work on today? ────────────────╮
> │  ${LOCAL_DATETIME}                                      │
> │                                                         │
> │  Projects available in this workspace:                  │
> │  ${PROJECTS_LIST}                                       │
> │                                                         │
> │  Live state to consider:                                │
> │  ${LIVE_STATE_LIST}                                     │
> │                                                         │
> │  Reply with any of:                                     │
> │    • a project name (e.g. "bfg-swt")                    │
> │    • free-form intent (e.g. "fix login bug in bfg-swt") │
> │    • a specific task/PR ID                              │
> │    • inline caps (e.g. "5 tasks today" or "30-50/wk")   │
> │                                                         │
> │  Or type 'cancel' to exit without starting the kingdom. │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LOCAL_DATETIME}` | `date '+%A, %B %-d, %Y · %H:%M %Z'` | `Tuesday, May 19, 2026 · 16:42 +07` |
| `${PROJECTS_LIST}` | bullet per project from `ls -d .kingdom/*/` (excluding `.setting`) | (multi-line, see below) |
| `${LIVE_STATE_LIST}` | bullet per actionable item: open PRs awaiting review, in-flight task files with blockers, lanes idle for >24h | (multi-line, see below) |

## Example `${PROJECTS_LIST}` rendering

```text
  • bfg-swt   · last activity 2h ago · 4 PRs open · 1 task in-flight
  • cert-site · last activity 3d ago · 0 PRs open · idle
  • td-rep    · last activity 12h ago · 0 PRs open · idle
```

Each project row shows: name + last `master_agent.log` activity + PR count + in-flight task count. Gives the user a one-glance answer to "what's been happening across projects."

## Example `${LIVE_STATE_LIST}` rendering

```text
  → bfg-swt PR #257 has 3 unresolved lead comments (lead-requested follow-up)
  → bfg-swt worker-1 FE-P0-FOUND.5 blocked on 2 user-decision items (resume?)
  → cert-site no live state (idle)
```

If a project has zero actionable items, drop its line from `${LIVE_STATE_LIST}`. If the whole list is empty, replace with `"Nothing on fire across any project. Pick one and tell me what you'd like to do."`.

## Reply parsing

After the card is rendered, King waits for the user's reply (next chat message). Parse rules:

| User says | King parses |
|---|---|
| `bfg-swt` | `project=bfg-swt`, no task_hint |
| `work on bfg-swt` | `project=bfg-swt`, no task_hint |
| `fix login bug in bfg-swt` | `project=bfg-swt`, `task_hint="fix login bug"` |
| `continue worker-1 PDPA` | `project=<inferred>`, `task_hint="resume worker-1 FE-P0-FOUND.5"` (fuzzy-matched) |
| `review PR 257` | `project=<inferred from PR>`, `task_hint="address lead comments on PR #257"` |
| `pair on co-worker-1 for the wireframe` | `project=<inferred>`, `task_hint="pair on co-worker-1, scope: wireframe"` |
| `5 PRs today, bfg-swt` | `project=bfg-swt`, `pr-limit=5` |
| `3 stories on cert-site` | `project=cert-site`, `pod-limit=3` |
| `till lunch` | `project=<current>`, soft hint (no limit, King decides) |
| `cancel` / `nvm` / `forget it` | Exit without starting the kingdom. |
| `hi` / `what's up` / a question | Treat as conversational, NOT a kingdom invocation. Reply normally; user can re-run `/kingdom:work` when ready. |

## Project resolution

Fuzzy substring match against `${AVAILABLE_PROJECTS}` from Step 0.0. If multiple projects match, King replies asking which one. If zero projects match AND only one project exists in the workspace, default to that one. Otherwise stop and ask.

## Confirmation gate

Before proceeding to Step 0.1 (and the rest of `/kingdom:work`), King prints the parsed interpretation back:

```text
👑 Parsed:
   project   = bfg-swt
   task      = continue worker-1 FE-P0-FOUND.5 (matched task file)
   cap       = (none)
   target    = (none)

   Proceed? Or correct the parse.
```

User confirms with `go` / `yes` / `proceed` → King runs Step 0.1 → Step 0.4 (visible-progress) → rest of day flow with `task_hint` as a strong prior in resume-scan + dispatch.

User corrects → King re-parses + re-prints confirmation.

## Why this card exists

Lowers the friction for "I have a vague idea what I want to do today, just figure it out." Without this mode, `/kingdom:work` requires the user to remember the exact project name + the precise budget syntax. The card gives them context (live state across all projects) + accepts natural-language replies.

## Notes

- The card explicitly lists what's actionable so the user doesn't have to remember which PRs are open or which tasks are blocked. Cuts the "what was I doing again?" cognitive load.
- This is the ONLY card that pauses the `/kingdom:work` flow waiting on user input — other cards (welcome, suggested-task, etc) display + continue. Interactive-mode cards block until reply.
