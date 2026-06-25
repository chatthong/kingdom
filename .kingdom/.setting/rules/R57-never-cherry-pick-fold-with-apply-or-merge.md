### R57. Never cherry-pick to fold lanes/PRs — apply or merge — Tier 2

`git cherry-pick` copies a commit under a **new SHA**, so the source and the target stop sharing history. Use it to assemble a PR branch or to fold work into `kingdom` and the two chains **silently diverge** — content present on one is absent on the other, with no conflict to warn you.

**Banned for the kingdom integration flow:**
- Folding a lane tip / PR into `kingdom`.
- Building or extending a `feature/<topic>` branch.

**Use instead:**
- **Overlay (the King's self-initiated default, R4/R15):** `git diff <lane> | git apply --3way` onto the kingdom working tree. No commits on kingdom.
- **Explicit human merge order (R4 carve-out):** `git merge --no-ff <branch>` — real merge commits that preserve shared history.
- **Rebuilding kingdom from scratch:** `git reset --hard origin/<base>` → `git merge --no-ff` **each** open PR branch in turn. This is the true post-merge integration: kingdom = base + every PR, all sharing history, nothing dropped.

**Why Tier 2:** a cherry-pick doesn't lose committed data from the source branch (the commit still exists there) or fire a remote action, so it isn't Tier 1. But it produces the *appearance* of integration while the integrated branch is missing content — the failure mode where the live build renders stale code that "should" be there, and hours get burned chasing a ghost that is pure branch divergence. Merge/apply keep the chains consistent.

**Interaction with R4:** the overlay (default) and a human merge order (carve-out) are both R57-safe — neither cherry-picks. R57 simply forbids the one fold mechanism that forks SHAs.
