# audit-summary

**Fires when:** `/kingdom:work` finishes the audit pass.
**Used by:** [`commands/work.md`](../../../commands/work.md) final step. Also fired by `/kingdom:work` Step 1 as a confirmation that the audit ran.

## Template

```markdown
> [!NOTE]
> ```
> ╭─ 📋 Audit complete · ${PROJECT} ───────────────────────╮
> │  Specialists fan-out: ${N_SPECIALISTS} parallel · ${DURATION}
> │                                                         │
> │  Reconciled:                                            │
> │    ✓ ${N_CHECKBOXES_FLIPPED} stale checkboxes flipped   │
> │    ✓ ${N_ORPHANS_BACKFILLED} orphan artifacts backfilled│
> │    ✓ ${N_LOG_LINES_REPAIRED} log lines repaired         │
> │                                                         │
> │  Gaps surfaced (King review):                           │
> │    • ${N_DIGESTS_STALE} stale digests                   │
> │    • ${N_TASK_MERGES} task-file merge candidates        │
> │    • ${N_SUSPECT} suspect "claimed-done-no-commit"      │
> │                                                         │
> │  Report: ${REPORT_PATH}                                 │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | project being audited | `my-app` |
| `${N_SPECIALISTS}` | parallel-spawn count | `4` |
| `${DURATION}` | wall-clock | `2m 14s` |
| `${N_CHECKBOXES_FLIPPED}` | low-risk auto-fixes | `7` |
| `${N_ORPHANS_BACKFILLED}` | raw artifacts that got curated digest | `2` |
| `${N_LOG_LINES_REPAIRED}` | `master_agent.log` entries added | `3` |
| `${N_DIGESTS_STALE}` | high-risk: digest text doesn't match raw | `0` |
| `${N_TASK_MERGES}` | task files that should consolidate | `1` |
| `${N_SUSPECT}` | sentinels with no matching commit | `0` |
| `${REPORT_PATH}` | path to the full audit report | `.kingdom/my-app/logs/kingdom-update-2026-05-18T1142Z.md` |

## Notes

- If all gap-surfacing counts are zero, drop the "Gaps surfaced" section entirely (cleaner card).
- The "Reconciled" section shows what watchman/audit fixed autonomously per its scope rules. High-risk findings are flagged for King review; they're NOT auto-fixed.
