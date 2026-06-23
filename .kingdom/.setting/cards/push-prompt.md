# push-prompt

**Fires when:** Tier-2 gate passes; King needs your explicit "push" word per [R1](../rules/R01-push-approval-is-single-shot.md). On `push`: carve `feature/<topic>`, `git push`, open a **DRAFT** PR (R56). The PR stays draft until you say `open` for that specific PR.
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
> │  Reply 'push' → carve feature branch + push + DRAFT PR  │
> │  Reply 'open' after push → mark that draft PR ready     │
> │  Reply 'hold' → wait, do nothing yet.                   │
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
| `${PR_TITLE}` | first line of the auto-generated PR body | `feat(shop): per-app SEO metadata` |

## Required user responses

**Two-stage gate (R1 + R56):**

1. **`push`** (or close variants: `push it`, `yes push`) — carve `feature/<topic>`, `git push`, open a DRAFT PR via `gh pr create --draft`. The PR is not visible to reviewers until marked ready. King stays at the next stage.
2. **`open`** (single-shot, per-PR) — `gh pr ready <N>` marks that one draft PR ready for review. The literal word `open` for PR #N. A prior `open` does NOT carry to another PR.

Per R1, both words are **single-shot + PR-specific**. Any other reply (`hold`, `wait`, `no`, ambiguous text) holds; King waits for next user message.

**Anti-patterns (do NOT count as approval):**

- `fire all`, `go ahead`, `yes` (generic) — these don't name the action
- Approval given for a previous PR — R1 is single-shot + PR-specific
- "push them all" / "open all" — must be one explicit word per PR
