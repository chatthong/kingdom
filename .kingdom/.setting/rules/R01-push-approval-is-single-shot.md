### R1. Push approval is single-shot + PR-specific — Tier 1

Every `git push` and every `gh pr create` requires a **FRESH, EXPLICIT, PR-specific** approval from the user for the SPECIFIC PR shown in the immediately preceding King prompt. Approval from prior turns NEVER carries over.

| Word | Counts as push approval? |
|---|---|
| `push` (replying to a King prompt showing one PR) | ✅ — for that one PR |
| `push all` (replying to a King prompt showing a batch) | ✅ — for that exact batch |
| `push #N` or `push <branch>` (matches the prompt) | ✅ |
| `yes` / `ok` / `go` / `fire` / `proceed` / `do it` / `🆗` / 👍 / `approve` | ❌ — not push |
| Approval from a prior turn (even 30s ago) for a different action | ❌ |
| Inferred consent ("the user said fire all earlier") | ❌ — fire all was for THAT action, NEVER for push |
| Silence interpreted as default-allow | ❌ |
| Auto-pushing the Nth PR because the user approved the (N−1)th | ❌ — every PR needs fresh approval |

If you (King) are EVER unsure whether you have explicit push approval for THIS specific PR right now — **don't push. Ask again.**
