### R29. After every successful push, kingdom MUST be reset to `origin/develop` tip — Tier 2 (v0.19.1+)

**Push completes → kingdom overlay is discarded.** Not deferred to "after PR merge." The user's mental model is "push to remote → kingdom is clean like a fresh `git pull`" — the spec must match that.

**Where this is already documented (but was being skipped):**

- [`kings.md`](kings.md) § Push approval gate Step 8: `git restore .` OR `git reset --hard origin/develop`
- [`_primitives.md`](_primitives.md) § `carve_and_push_feature` calls `kingdom_discard_overlay` as its FINAL action
- [`_primitives.md`](_primitives.md) § `kingdom_discard_overlay` helper

**Required sequence after the LAST PR in a push batch goes out:**

```bash
# After `gh pr create ...` returns successfully for ALL PRs in the batch:
git -C "$WORKTREE" switch kingdom
git -C "$WORKTREE" reset --hard "origin/$BASE"   # or `git restore .` if no untracked files
git -C "$WORKTREE" clean -fd                      # remove any new untracked overlay files
git -C "$WORKTREE" status                         # MUST print "nothing to commit, working tree clean"
```

**Why this is Tier 2 not Tier 1:** Skipping it doesn't lose data (work lives on `feature/*` remotes + `worker-N` locals). But the next gate-pass overlay attempts `git apply --3way` on top of stale leftover → double-application, conflict errors, or false-positive "lane has new changes" detection. It's a correctness rule, not a safety rule.

**Incident that motivated this rule (2026-05-18):** another King session pushed 4 PRs (#255 + #257 + #258 + #259) to bfg-swt successfully, but skipped this step. the user opened GitHub Desktop, saw 18 stale uncommitted files on kingdom branch, and asked "shouldn't kingdom be clean after push?" — yes, it should. Step 8 was in `kings.md` but not enforced via `rules.md`, so the lane-spawned King missed it.

**Distinguished from R26:**

| Trigger | Rule | Sequence |
|---|---|---|
| `gh pr create` returns success | **R29** (this rule) | discard overlay → kingdom = `origin/develop` tip (unchanged remote SHA) |
| `gh pr view <N>` flips to MERGED | **R26** post-merge resync | fetch + ff develop → kingdom = NEW `origin/develop` tip (advanced SHA) + free merged lane |

R29 fires first (per-push, no remote movement). R26 fires later when the lead merges (advances remote, then resync).
