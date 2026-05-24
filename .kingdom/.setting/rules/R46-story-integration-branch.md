### R46. Story integration branch — Tier 2 (v0.32.0+)

When `kingdom.json.integration.enabled` is true and a unit of work (the configurable `integration.unit`: story, milestone, or issue) needs more than one worker, the King opens a **story integration branch** instead of the solo `worker -> feature/<topic>` path.

- The branch is named per `integration.branchPattern` (default `story/<id>`), branched off `git.base` (`develop`), and lives in the owning Senior's worktree (`.worktrees/senior-N/`).
- It is a **real local branch with real merge commits**: each pod worker's branch is merged into it by the Senior (not `git apply` overlay).
- It stays **local**. Only the final `story/<id> -> develop` PR reaches origin (R6 still holds for lane branches; the story branch is the single thing promoted per unit).
- Single-worker quick tasks may still use the solo `worker -> feature/<topic>` path. Not every task is a pod.
