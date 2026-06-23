# pr-merged

**Fires when:** `gh pr view <N> --json state -q .state` flips to `MERGED`; triggers [R26](../rules/R26-after-every-pr-merge-king.md).
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 5 (King polls); [`watchman.md`](../roles/watchman.md) `/loop` (watchman detects).

## Template

```markdown
> [!NOTE]
> ```
> ╭─ ✅ PR #${PR_NUMBER} merged ───────────────────────────╮
> │  ${PR_TITLE}                                            │
> │  Squash SHA: ${MERGE_SHA}                               │
> │  Lane freed: ${LANE_FREED}                              │
> │                                                         │
> │  Resyncing kingdom per R26:                             │
> │    ✓ overlay discarded                                  │
> │    ✓ origin/develop fast-forwarded                      │
> │    ✓ kingdom reset to develop tip                       │
> │    ✓ remaining lanes rebased                            │
> │                                                         │
> │  ${LANE_FREED} ready for next dispatch.                 │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PR_NUMBER}` | merged PR number | `258` |
| `${PR_TITLE}` | PR title from `gh pr view` | `feat(shop): middleware refresh-on-expiry` |
| `${MERGE_SHA}` | `gh pr view --json mergeCommit -q .mergeCommit.oid` truncated to 7 chars | `def5678` |
| `${LANE_FREED}` | lane whose commit just landed | `worker-2` |

## Lock-step with R26

This card prints AFTER `kingdom_resync_after_merge` helper (in [`functions/index.md`](../functions/index.md)) runs the 7-step resync. The 4 checkmarks reflect the helper's actual steps, in order:

1. ✓ overlay discarded — `git reset --hard HEAD` + `git clean -fd` on kingdom
2. ✓ origin/develop fast-forwarded — `git fetch` + `git merge --ff-only origin/develop`
3. ✓ kingdom reset to develop tip — `git branch -f kingdom develop`
4. ✓ remaining lanes rebased — `for lane in worker-*: git rebase origin/develop`

If any step fails, the helper aborts and this card is NOT printed (a failure card is logged instead).

## Notes

- PRs follow the two-stage gate (R56): `push` → DRAFT PR; `open` → `gh pr ready <N>` marks it ready for review; only then can a lead approve and the PR reach MERGED. This card fires after that full journey — it never implies a draft was merged directly.
- Watchman can also fire this card if it's polling PRs and detects MERGED before King's next tick. In that case, watchman sends `cmux notify` to King's workspace + writes a one-liner to `master_agent.log`; King re-prints the card on next tick + runs the resync.
- The "Lane freed" line reflects R26 Step 5: the merged-lane's `worker-N` branch resets to develop tip + is now eligible for new dispatch.
