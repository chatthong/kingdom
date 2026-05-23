# story-assembled

**Fires when:** a Senior has merged all of its pod's sub-tasks into the story branch and run Tier-2, just before the review loop begins (v0.32.0+).
**Used by:** [`seniors.md`](../seniors.md) story lifecycle (step 3 -> step 4 transition).

## Template

```markdown
> [!NOTE]
> ```
> ╭─ 🎓 Story assembled · story/${STORY_ID} ───────────────╮
> │  Pod: ${POD_WORKERS}                                    │
> │  Merged: ${N_MERGED}/${N_SUBTASKS} sub-tasks            │
> │  Tier-2 (story branch): ${TIER2_STATUS}                 │
> │  Next: Senior review loop (R48)                         │
> ╰─────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${STORY_ID}` | story id | `FE-AUTH` |
| `${POD_WORKERS}` | the Senior's pod | `worker-1, worker-2, worker-3` |
| `${N_MERGED}` / `${N_SUBTASKS}` | merged vs total sub-tasks | `3` / `3` |
| `${TIER2_STATUS}` | `run_tier2_on_story` result | `✅ pass` / `❌ fail` |

## Notes

If Tier-2 fails on the assembled story branch, the Senior routes the failure to the owning worker(s) as a fix-task (same loop as a review finding) rather than proceeding to review. A merge conflict during assembly is handled per R49 (Senior resolves, or marks the story blocked and escalates).
