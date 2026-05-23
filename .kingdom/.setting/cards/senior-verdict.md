# senior-verdict

**Fires when:** a Senior finishes a review-loop iteration on its story branch (v0.32.0+). Clean = story is push-eligible; otherwise fixes were routed back to workers.
**Used by:** [`seniors.md`](../seniors.md) review loop; [`commands/work.md`](../../../commands/work.md) Step 5 (King renders the final clean verdict before the story push-prompt).

## Template

```markdown
> [!NOTE]
> ```
> ╭─ 🎓 Senior verdict · story/${STORY_ID} · iter ${ITER}/${CAP} ─╮
> │  Reviewed: ${N_AREAS} areas across ${N_FILES} files         │
> │  Tier-2 (story): ${TIER2_STATUS}                            │
> │  Verdict: ${VERDICT}                                        │
> │  ${VERDICT_DETAIL}                                          │
> ╰─────────────────────────────────────────────────────────────╯
> ```
```

`${VERDICT}` is one of:

- `✅ clean — push-eligible` (handed to King; `${VERDICT_DETAIL}` summarizes what passed)
- `🔧 fixes routed` (`${VERDICT_DETAIL}` lists `worker-N: <issue>` per routed fix; loop continues)
- `⛔ escalated` (review-loop cap hit; `${VERDICT_DETAIL}` lists outstanding findings for the human)

## Variables

| Var | Source | Example |
|---|---|---|
| `${STORY_ID}` | story id | `FE-AUTH` |
| `${ITER}` / `${CAP}` | review-loop iteration / `integration.reviewLoopCap` | `2` / `3` |
| `${N_AREAS}` / `${N_FILES}` | touched areas / files reviewed | `4` / `11` |
| `${TIER2_STATUS}` | `run_tier2_on_story` result | `✅ pass` / `❌ fail` |
| `${VERDICT}` | review outcome | see above |
| `${VERDICT_DETAIL}` | one-line summary or routed-fix list | `worker-2: auth token not refreshed on 401` |

## Notes

The Senior never pushes (R1). A `✅ clean` verdict means the Senior wrote `SENIOR_<UTC>__story-<id>.md` + the push-eligible sentinel and handed the story to the King; the King then runs its cross-story check (R50) and renders [`push-prompt`](push-prompt.md).
