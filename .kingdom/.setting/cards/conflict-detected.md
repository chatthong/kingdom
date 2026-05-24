# conflict-detected

**Fires when:** King's FINAL conflict check (`git merge-tree --write-tree --no-messages origin/develop ${LANE}`) finds conflict markers at push time.
**Used by:** [`king.md`](../roles/king.md) push approval gate Step 4.

## Template

```markdown
> [!WARNING]
> ```
> ╭─ ⚠ Conflict at push time · ${LANE} ────────────────────╮
> │  origin/develop moved during approval window.           │
> │  git merge-tree found conflict in:                      │
> │    ${CONFLICT_FILES_LIST}                               │
> │                                                         │
> │  Options:                                               │
> │    • rebase ${LANE} onto fresh origin/develop           │
> │    • discard and re-dispatch                            │
> │                                                         │
> │  Reply: 'rebase' / 'discard'                            │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane being pushed | `worker-2` |
| `${CONFLICT_FILES_LIST}` | conflicting file paths from `git merge-tree`, one per line prefixed `    • ` | `    • apps/webshop/middleware.ts` |

## Response handling

| Reply | Action |
|---|---|
| `rebase` | King dispatches `git rebase origin/develop` in the lane's worktree → re-run Tier-1 + Tier-2 gates → re-prompt push |
| `discard` | King aborts the push entirely; lane keeps its commit on `${LANE}` for later cycles |

## Trigger context (why this exists)

The pre-commit gate runs *before* King reports "push?" to the user. The user may take minutes to decide. The lead may merge another PR in that window. The FINAL conflict check is the freshness guarantee — without it, a stale "gate green" could approve a push that conflicts on arrival.

`git merge-tree --write-tree --no-messages` is plumbing; it computes the merge without touching any working tree or branch ref. Conflict markers (`<<<<<<<` / `=======` / `>>>>>>>`) in its output mean the merge wouldn't be clean.

## Notes

- This card is rare in practice: lead merges + push approval rarely race. When it fires, rebase is almost always the right choice (the lead's merge is canonical; lane's commit is the one that needs to move).
- If `${CONFLICT_FILES_LIST}` is empty but merge-tree returned non-zero, fallback to "conflict in undetermined files; rebase and try again."
