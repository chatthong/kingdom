# Story pods (v0.32.0+)

Story pods let multiple workers attack one unit of work in parallel, get it reviewed as a whole, and ship it as a single PR. They are optimized for both quality and speed by giving the King and the Senior **different, non-overlapping** quality concerns.

## When to use a pod vs the solo path

| Situation | Path |
|---|---|
| One unit needs several independent sub-tasks done in parallel | **Story pod** (a Senior + N workers on a `story/<id>` branch) |
| A quick one-worker change | **Solo** (`worker -> feature/<topic>`, the classic flow) |

Pods are enabled by `kingdom.json.integration.enabled` and `shape.seniors > 0`. Set either off to keep the classic per-worker flow.

## The shape

```
King (orchestrator, sole pusher, your chat)
 ├─ story/A -> Senior-1 -> worker-1, worker-2, worker-3
 └─ story/B -> Senior-2 -> worker-4, worker-5
 watchman-1 (per-lane scans + cross-story drift signal)
```

- **King** owns everything *between* stories: it picks units from the task-ledger, partitions their file-scopes so pods do not collide, sequences dependencies, allocates pods within `sanityCap`, and holds the final human-gated push. It never re-reviews a story's internals.
- **Senior-N** owns one story *end to end*: split into sub-tasks, dispatch its pod, merge each worker branch into the local `story/<id>` branch, run Tier-2 on that branch, run the review loop, and mark the story push-eligible.
- **Worker** does its sub-task on `worker-N`, passes Tier-1, signals done; its Senior merges and reviews.
- **Watchman** is unchanged except for one duty: a per-tick `git merge-tree` scan across in-flight `story/*` branches that feeds the King a cross-story drift signal.

## The branch model

| Branch | Reaches origin? |
|---|---|
| `worker-N` | no (local lane) |
| `story/<id>` | only as the final `story/<id> -> develop` PR |
| `feature/<topic>` | yes (solo PRs) |

The story branch lives in the Senior's worktree (`.worktrees/senior-N/`), branched off `develop`, with real merge commits. Review happens in place; only the final PR is pushed. See [`.kingdom/.setting/git.md`](../.kingdom/.setting/git.md).

## The three-tier gate

1. **Tier 1 (worker):** lane typecheck in each worker's worktree.
2. **Tier 2 (story):** `gate.tests + smoke + lint` on the assembled `story/<id>` branch, run by the Senior.
3. **Tier 3 (Senior review loop):** the Senior fans out reviewers per touched area, synthesizes as Opus, routes fixes back to the owning worker, and re-reviews until clean (cap `integration.reviewLoopCap`) or escalates.

Then the human push (R1) is the final, single gate.

## Why this is fast AND high-quality

- **No redundant review:** the Senior is the sole within-story reviewer; the King never re-reviews the same code. Review is paid once.
- **No unowned concern:** the Senior owns within-story depth (coherence, acceptance, architecture, doc cross-check); the King owns cross-story breadth (conflicts, sequencing, consistency across pods). Nothing falls through the gap.
- **Parallelism:** pods run independently and concurrently; the only serial bottleneck is the human push, which you want serial anyway.

## Rules

R46 (story branch), R47 (three-tier gate), R48 (Senior sole within-story reviewer), R49 (Senior owns within-story conflicts), R50 (King owns cross-story); R30 amended for delegated dispatch. See [`.kingdom/.setting/rules.md`](../.kingdom/.setting/rules.md) and the role spec [`.kingdom/.setting/seniors.md`](../.kingdom/.setting/seniors.md).
