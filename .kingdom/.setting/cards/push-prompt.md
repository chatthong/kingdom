# push-prompt

**Fires when:** Tier-2 gate passes; King needs Ter's explicit "push" word per [rules.md R1](../rules/R01-push-approval-is-single-shot.md).
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 5 auto-gate-poll loop; [`king.md`](../roles/king.md) push approval gate.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ 👑 Push? · ${LANE} · ${TASK_ID} ──────────────────────╮
> │  Tier-2 gate: ✅ pass (${GATE_DURATION})                │
> │  Files: ${N_MODIFIED} modified, ${N_NEW} new            │
> │  Diff: review live in GitHub Desktop                    │
> │  PR title: ${PR_TITLE}                                  │
> │  PR body: auto-generated from task file                 │
> │                                                         │
> │  Reply 'push' to publish, 'hold' to wait.               │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane name | `worker-2` |
| `${TASK_ID}` | task ID | `FE-P0-FOUND.7` |
| `${GATE_DURATION}` | wall-clock of the Tier-2 gate run | `8 min` |
| `${N_MODIFIED}` | `git status --short` modified files count | `7` |
| `${N_NEW}` | `git status --short` new files count | `2` |
| `${PR_TITLE}` | first line of the auto-generated PR body | `feat(swt-frontend): per-app SEO metadata` |

## Required user response

Per R1, the response that authorises push is **`push`** (or close variants: `push it`, `yes push`). Any other reply (`hold`, `wait`, `no`, ambiguous text) holds the push; King stays at this card, waits for next user message.

**Anti-patterns (do NOT count as push approval):**

- `fire all`, `go ahead`, `yes` (generic) — these don't name the action
- Approval given for a previous PR — R1 is single-shot + PR-specific
- "push them all" — must be one explicit `push` per PR in the queue
