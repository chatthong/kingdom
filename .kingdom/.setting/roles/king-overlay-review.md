# king-overlay-review.md — Kingdom overlay review-staging protocol

> Extracted from [`king.md`](king.md) (v0.35.0 modular reorg). The working-tree overlay model: kingdom never commits (R4), each gate-pass resets to `origin/$BASE` then overlays lane changes as UNCOMMITTED files for human review, feature branches carve byte-for-byte from the lane tip (R9), overlay discarded after push.

See [`king.md`](king.md) for the King role overview, [`git.md`](../reference/git.md) for the branch model, [`_primitives.md`](../_primitives.md) for `kingdom_overlay_lane`.

---

## Kingdom as review staging — WORKING-TREE OVERLAY (never commit on kingdom)

Push approval is NOT just "gate passed → ask the user push?". The kingdom is **a local working-tree overlay for human review** — the user MUST see the full code-surface of all in-flight lane changes as UNCOMMITTED files so GitHub Desktop's "Changes" tab (or any diff tool) shows everything line-by-line.

**v0.17.0+ rule: kingdom branch never receives commits.** It's a scratch surface that gets reset to `origin/develop` each review cycle, then has the worker-N CHANGES overlaid as uncommitted modifications. After review + push, the overlay is discarded.

Review surface: **GitHub Desktop's "Changes" tab** (or `git diff` / VS Code source-control panel / lazygit) showing every file modified across all in-flight lanes as UNCOMMITTED changes. No commit history to navigate — files diffed line-by-line in one view.

### Mandatory workflow

After every gate-pass (per the v0.14.10 auto-gate rule), King's NEXT step is:

1. **Reset kingdom to `origin/develop`** (clean slate — overlay starts fresh each review cycle):
   ```bash
   git checkout kingdom
   git fetch origin
   git reset --hard "origin/$BASE"
   ```
   > [!WARNING]
   > This `reset --hard` is safe ONLY at the START of a fresh review cycle, when nothing on kingdom awaits review or push. Before running it, check `git status` on kingdom: if there are uncommitted changes you did not just overlay, STOP (R29) — those are either an in-flight review surface (keep) or work authored directly on kingdom (R4 violation — recover into a worktree first). Never reset over unreviewed/unpushed work.
2. **Overlay each gated lane's changes onto kingdom's working tree** (no commits — just files modified):
   ```bash
   # For each gated lane:
   git checkout "worker-N" -- .       # copy worker-N's tree into kingdom's working tree
   # Or, if you want to preserve other lanes' changes already overlaid:
   #   git diff "origin/$BASE..worker-N" | git apply -3
   # (3-way merge; conflicts surface as unmerged paths Ter can resolve)
   ```
   Result: kingdom's working tree has all changes from all in-flight lanes, **UNCOMMITTED**. Conflicts (typically shared TODO/CHANGELOG files) appear as merge markers in the working tree — King hand-resolves by keeping all close-suffix headers.
3. **Print the review surface** — file list + per-file diff stats from the working tree:
   ```bash
   git status --short                   # what's modified/added/deleted
   git diff --stat                      # per-file line counts
   git diff "origin/$BASE" --stat       # alternative — same view from develop's POV
   ```
4. **Run Tier-2 gate on the working tree** (tests/smoke/lint run against the overlaid state). Tests see all integrated changes even though nothing's committed on kingdom.
5. **Ask the user to review** in GitHub Desktop / VS Code / their preferred diff tool. Phrase: "All changes for <N> lane(s) overlaid onto kingdom as uncommitted modifications. Open GitHub Desktop's Changes tab (or `git diff`) to review file-by-file. Approve push?"
6. **Wait for the user's approval**.
7. **On approval — carve `feature/<topic>` from each lane's tip** (NOT from kingdom; the feature branch is the lane's commits, untouched). Push, open PR.
8. **After push — and ONLY after — discard the kingdom overlay** (R29):
   ```bash
   kingdom_discard_overlay "$PWD"       # checkout kingdom + restore . + clean -fd
   # Kingdom is back to clean = origin/$BASE. Next gate-pass starts a fresh overlay.
   ```

   > [!CAUTION]
   > **Never run step 8 before the push has gone out.** `git restore .` / `git reset --hard` / `git clean -fd` on kingdom while gated work still awaits the user's review or push approval destroys the exact review surface they asked for ("I must see all the dirty files / all N PRs before you push" — R15). Discard fires AFTER `gh pr create` succeeds for the batch, never as a "let me tidy kingdom first" reflex. If you find dirty files on kingdom you did NOT just overlay, do not wipe them — classify per R29 (in-flight review surface → keep; authored-on-kingdom → R4 violation, recover into a worktree first).

### Why never commit on kingdom?

- **Review tool friendly.** GitHub Desktop's "Changes" tab, VS Code's source-control panel, lazygit, and `git diff` all default to showing uncommitted changes. Merge-commit-based integration hid changes inside commit history; uncommitted-overlay puts everything front and center.
- **No history clutter.** Old approach left 5+ merge commits per review cycle on a branch you never push — pollution that complicated `git log` reads.
- **Clean reset.** After push, `git restore .` drops everything; kingdom is pristine for the next cycle. No accumulating cruft.
- **Tier-2 gate still works.** Tests run on the overlaid working tree. Same coverage as before.
- **Conflict handling stays the same.** Working-tree conflict markers surface during `git apply -3` or `git checkout worker-N -- file`; King hand-resolves in the working tree (typically by keeping all close-suffix headers in TODO files).

### Why carve from lane tip, not from kingdom?

Each PR should be one purpose, one commit, traceable to a single lane. Carving from `kingdom` would mix lanes (kingdom contains develop + lane-1 + lane-2 + lane-3 integrated). Carving from `worker-N` keeps the PR a clean one-commit feature branch matching exactly what that lane produced.

### STRICT: `feature/<topic>` = `worker-N` tip, byte-for-byte identical

The carved `feature/<topic>` branch is a **fast-forward checkout** from `worker-N`'s tip. **The King MUST NOT add commits on the feature branch.** Whatever is on `worker-N` at the moment of carve IS what gets pushed — no additions, no rewrites, no post-hoc edits.

This guarantees `kingdom` = source of truth for what's about to ship. After the user reviews on kingdom, the carved `feature/<topic>` branches contain EXACTLY the commits visible on kingdom from each lane. No surprises in the PR.

```bash
# Correct carve (single fast-forward; no new commits)
git checkout -b "feature/<topic>" "worker-N"
git push -u origin "feature/<topic>"
gh pr create --base develop --head "feature/<topic>" --title "..." --body "..."

# WRONG — adds a commit AFTER carving:
git checkout -b "feature/<topic>" "worker-N"
cp docs/test-reports/SMOKE_*.md .                 # ❌ post-carve edit
git add docs/test-reports/
git commit -m "add smoke report"                  # ❌ feature/* now diverges from worker-N
git push -u origin "feature/<topic>"
# → kingdom no longer reflects what's pushing; Ter's review is incomplete
```

### What to do when you want extra content in the PR

If you want something in a PR that isn't yet on the worker's branch (e.g., a smoke test report from Tier-2 gate, an updated changelog entry, a doc reference to the new feature):

**Option A — bundle into the worker's commit (preferred).** The lane writes the extra content as part of its closer. The worker's commit contains code + report + doc updates together. Single commit, single PR purpose. Clean.

**Option B — separate PR.** Create a fresh `feature/<topic>-followup` branch from `origin/develop`, add the extra content as its own commit, push as its own PR. This is the right call when the extra content is genuinely independent (e.g., a smoke report covering 3 different PRs belongs in its own `docs(test-reports)` PR, not bundled with one of the feature PRs).

**Anti-pattern: adding commits to `feature/<topic>` after carving.** This diverges from `worker-N` tip + invalidates kingdom's review surface. **Don't.**

### How King decides between A and B

| Scenario | Choice |
|---|---|
| Test report covers ONE PR's work specifically | A — worker commits it |
| Test report covers MULTIPLE PRs (smoke across feature-7/8/9) | B — separate PR |
| Doc update is about THIS PR's new feature | A — worker commits it |
| Changelog entry mentions THIS PR | A — worker commits it |
| Cross-cutting infrastructure change (e.g., `.gitignore` for kingdom worktrees) | B — separate PR (different concern entirely) |

When uncertain, default to B — separate PRs are easier to review + revert than mixed-concern PRs.

```text
origin/develop:    A --- B --- C
                              \
worker-1:                      D (one commit, gated, merged to kingdom)
                              \
worker-2:                      E (one commit, gated, merged to kingdom)

kingdom (local):   A --- B --- C --- M1 --- M2 (merge commits for review)
                                  \   \
                                   D   E (still visible in kingdom)

# After Ter reviews on kingdom and approves:
feature/topic-1:   A --- B --- C --- D   ← push this (1 commit from worker-1 tip)
feature/topic-2:   A --- B --- C --- E   ← push this (1 commit from worker-2 tip)
```

### Multiple in-flight lanes — overlay order (v0.17.0+)

When ≥2 lanes are gated and ready for review at the same time, overlay them in completion order (oldest sentinel first). The kingdom branch starts at `origin/develop`, gets each lane's changes applied to its working tree:

```bash
# Reset kingdom to origin/develop tip first (clean slate)
git checkout kingdom
git fetch origin
git reset --hard "origin/$BASE"

# Overlay each gated lane's CHANGES onto the working tree (no commits).
#
# v0.31.0: route through kingdom_overlay_lane helper (in _primitives.md).
# The helper enforces R4 at call-site: refuses to apply if kingdom branch
# isn't checked out, or if kingdom HEAD ≠ origin/$BASE (which would mean
# a rogue commit landed on kingdom — common 2026-05-20 failure mode where
# the King FF-merged a feature branch onto kingdom).
for LANE in $(ls -t "$LOGS/done/"*.flag | xargs -I{} basename {} | sed 's/^.*__\([^.]*\).flag/\1/' | sort -u); do
  echo "▶ Overlaying $LANE..."
  if ! kingdom_overlay_lane "$PWD" "$LANE" "$BASE"; then
    echo "⚠️ Conflict overlaying $LANE — resolve in working tree"
    echo "   Common cases:"
    echo "     - TODO_*.md  → keep all close-suffix headers from each lane"
    echo "     - CHANGELOG.md → keep both entries; order by sub-task ID"
    echo "     - docs/test-reports/ → all keep (different filenames)"
    echo "   After resolving, continue to next lane manually."
  fi
done

# Show the review surface (working tree, not commit history)
echo ""
echo "📋 Review surface — all changes UNCOMMITTED on kingdom:"
git status --short
echo ""
git diff "origin/$BASE" --stat
```

### Common conflict patterns + canonical resolutions

| Conflict on | Cause | Resolution |
|---|---|---|
| `TODO_*.md` (or similar task-status file) | Each lane added its own close-suffix header (e.g., `### FE-P0-FOUND.7 ✅ closed 2026-05-18`) | Keep ALL the close-suffix headers — they coexist; not a real conflict |
| `CHANGELOG.md` | Multiple lanes appending to the same `## [Unreleased]` section | Keep both entries; order by sub-task ID |
| `docs/test-reports/` | Multiple lanes wrote `KING_*` reports for different sub-tasks | All keep — different filenames, no real conflict |
| Same source file edited by 2 lanes | Genuine collision — King should have caught this in pre-commit cross-lane overlap | Stop. Surface to the user. Ask which approach wins. |

### Anti-patterns

- ❌ King asks "push?" immediately after gate pass, skipping kingdom overlay + review
- ❌ **King commits on kingdom branch** (v0.17.0+ rule: kingdom never receives commits — overlay only)
- ❌ **King creates merge commits on kingdom** (`git merge --no-ff worker-N` on kingdom). Use `git diff worker-N | git apply` or `git checkout worker-N -- <files>` instead — changes overlay in working tree.
- ❌ King carves `feature/*` from kingdom (mixes lanes; each PR loses one-purpose property)
- ❌ King pushes without showing the user the review surface (`git status` + `git diff --stat`)
- ❌ King auto-resolves a genuine source-file collision instead of surfacing it
- ❌ King treats kingdom as a target for push (it's local-only; never `git push origin kingdom`)
- ❌ **King adds commits to `feature/<topic>` after carving from worker-N tip.** The feature branch must be byte-for-byte identical to worker-N. If you want extra content in the PR, put it on worker-N first (Option A) or open a separate PR (Option B). See § "STRICT: `feature/<topic>` = `worker-N` tip" above.
