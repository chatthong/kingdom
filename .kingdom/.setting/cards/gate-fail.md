# gate-fail

**Fires when:** Tier-1 or Tier-2 gate fails on a lane.
**Used by:** [`commands/work.md`](../../../commands/work.md) Step 5; [`king.md`](../roles/king.md) gate flow.

## Template

```markdown
> [!CAUTION]
> ```
> ╭─ ❌ Gate fail · ${LANE} · ${TASK_ID} ──────────────────╮
> │  Tier: ${TIER} (${TIER_SCOPE})                          │
> │  Failure: ${FAILURE_SUMMARY}                            │
> │  Report: ${REPORT_PATH}                                 │
> │                                                         │
> │  Options:                                               │
> │    • dispatch fix-task back to ${LANE}                  │
> │    • investigate yourself (overlay still on kingdom)    │
> │    • discard overlay (${LANE} keeps its commit)         │
> │                                                         │
> │  Reply: 'fix' / 'mine' / 'discard'                      │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane name | `worker-2` |
| `${TASK_ID}` | task ID | `FE-P0-FOUND.7` |
| `${TIER}` | `Tier-1` or `Tier-2` | `Tier-2` |
| `${TIER_SCOPE}` | scope description | `kingdom overlay` (Tier-2) / `lane worktree` (Tier-1) |
| `${FAILURE_SUMMARY}` | one-line failure summary | `3 tests failed in apps/webshop` |
| `${REPORT_PATH}` | test-report file path | `docs/test-reports/KING_…__worker-2__FE-….md` |

## Response handling

| Reply | Action |
|---|---|
| `fix` | King dispatches a fix-task back to `${LANE}` with the failure summary in the brief |
| `mine` | King leaves the overlay intact; user investigates manually in the kingdom worktree |
| `discard` | King runs `kingdom_discard_overlay`; lane keeps its commit on `${LANE}` for retry later |

## Notes

- Tier-1 failures dispatch automatically back to the lane (no card shown); this card is for Tier-2 since Tier-2 needs human triage (cross-lane integration is ambiguous about which lane to blame).
- Tier-1 fail card variant: change `${TIER_SCOPE}` to `lane worktree`, drop the "overlay still on kingdom" / "discard overlay" options (Tier-1 didn't overlay yet).
