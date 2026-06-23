### R56. PRs open as draft; the literal 'open' marks ready — Tier 2

Every PR created by any lane or the King MUST be opened as a **draft**. The human promotes it to ready with the literal word `open` (per-PR, single-shot, exactly like R1's `push`). Two-stage gate:

1. **`push`** → `guard_worker_commit_branch` passes → carve `feature/<topic>` from `worker-N` tip (R9) → `git push origin feature/<topic>` → `gh pr create --draft ...`
2. **`open`** (for a specific PR) → `gh pr ready <N>`

| Word | Counts as "mark PR ready"? |
|---|---|
| `open` (replying to a King prompt showing PR #N) | ✅ — for that one PR |
| `open #N` or `open <branch>` (matches the prompt) | ✅ |
| `open all` / `ready all` / generic approval | ❌ — not single-shot |
| Approval from a prior turn for a different action | ❌ |
| Inferred consent ("the user said go earlier") | ❌ |
| The `push` word alone | ❌ — push creates the draft; it does NOT mark it ready |

**`gh pr create` exit code MUST be checked.** Every call site wraps with `|| return 1` (or equivalent) so a failed create is never masked and the King does not mistakenly believe a PR exists.

```bash
gh pr create --draft --title "..." --body "..." || return 1
```

**Why drafts always:** a draft PR is visible on the remote (reviewers can see the diff, CI fires) but cannot be accidentally merged before the human has reviewed the final overlay. The `open` single-shot mirrors R1's push-approval discipline: one explicit human acknowledgement per PR, per stage.

**Why exit-code check:** `gh pr create` can silently succeed with a non-zero exit (network timeout, duplicate branch, missing upstream) and emit an error to stderr while the caller continues. An unchecked failure leaves a dangling `feature/*` branch with no PR, which the watchman's backfill (R27) will never find.

**Interaction with R1:** `push` (R1) governs the `git push` + draft creation step; `open` (R56) governs promotion to ready. Both are single-shot + PR-specific. Neither word substitutes for the other.

**Interaction with R4:** creating a draft PR for a `feature/<topic>` branch does not touch the `kingdom` branch. The overlay (R15) must have passed before `push` is requested.
