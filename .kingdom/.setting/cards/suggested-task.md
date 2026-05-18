# suggested-task

**Fires when:** `/kingdom:day` kickoff, third card.
**Used by:** [`commands/day.md`](../../../commands/day.md) Step 3.

## Template

```markdown
> [!NOTE]
> ```
> ╭─ Suggested next task ──────────────────────────────────╮
> │  → ${CANDIDATE_1_ID} · ${CANDIDATE_1_WHY}               │
> │  OR: ${CANDIDATE_2_DESC}                                │
> │       ${CANDIDATE_2_WHY}                                │
> │  OR: ${CANDIDATE_3_DESC}                                │
> │                                                         │
> │  Reply '1' / '2' / '3' or 'go' for the first.           │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${CANDIDATE_1_ID}` | priority-1 source: unfinished prior-session task | `BE-P0-AUTH.2` |
| `${CANDIDATE_1_WHY}` | one-line reasoning + dependency note | `worker-2 idle; depends on FE-P0-FOUND.8 (PR #258)` |
| `${CANDIDATE_2_DESC}` | priority-2: open PR with unresolved review comments | `respond to lead comments on PR #257` |
| `${CANDIDATE_2_WHY}` | one-line elaboration | `(3 unresolved)` |
| `${CANDIDATE_3_DESC}` | priority-5: first unstarted heading in task-ledger | `new from TODO_Webshop.md FE-P0-FOUND.10+` |

## Synthesis priority

King picks candidates in this order, fills slots 1-3:

1. **Unfinished prior-session work** — task files in `.kingdom/${project}/tasks/` with Status ∈ `planning|executing|verifying` and no matching sentinel.
2. **Lead-requested follow-ups** — open PRs with unresolved review comments (`gh pr view <N> --json reviewDecision,reviewThreads`).
3. **Unflipped acceptance criteria** in `TODO_*.md` / `TODO_Master.csv` / `STEP.md` matching an idle lane's domain.
4. **Watchman gap findings** in `WATCH_DOCS_AUDIT.md`.
5. **New work** — first unstarted heading in the task-ledger with no dependency-blocking.

If fewer than 3 candidates exist, drop the unused `OR:` rows (don't print empty lines).

## Notes

- Slot 1 always uses `→` (active choice indicator); slots 2-3 use `OR:` (alternative).
- "Reply 'go' for the first" is hardcoded chat affordance so the user can accept without typing the long ID.
