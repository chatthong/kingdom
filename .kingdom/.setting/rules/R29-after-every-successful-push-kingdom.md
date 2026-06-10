### R29. After every successful push, kingdom MUST be reset to `origin/develop` tip — Tier 2 (v0.19.1+, hardened v0.37.0)

**Push completes → kingdom overlay is discarded.** Not deferred to "after PR merge." The user's mental model is "push to remote → kingdom is clean like a fresh `git pull`" — the spec must match that.

> [!CAUTION]
> **Discard the overlay ONLY after the gated work is pushed — NEVER before.** This is the load-bearing half of the rule. The `kingdom` working tree is the human's review surface (R15): the user reviews the uncommitted overlay, then says `push`. Wiping it earlier destroys exactly what they need to see.
>
> 🚫 **BANNED while gated work awaits review or push approval** (anything that drops the overlay):
> - `git reset --hard origin/$BASE`
> - `git restore .` / `git checkout -- .`
> - `git clean -fd`
> - any "let me clean up / reset kingdom first" reflex before the user has reviewed + approved + the push has gone out
>
> ✅ The ONLY time to discard is **AFTER** `gh pr create` succeeds for the gated batch (the sequence below).

**Pre-existing dirty kingdom at session start ≠ garbage to wipe.** If the King finds uncommitted changes on `kingdom` it did not just overlay, STOP and classify before touching anything:
- Changes that match a gated lane's diff → that's an in-flight review surface. Keep it; do NOT wipe.
- Changes authored directly on kingdom with no matching lane → an **R4 violation already happened** (work landed on kingdom instead of a `.worktrees/<lane>/`). Recover them into a lane worktree (`git stash` → apply on the right lane), THEN reset. Never silently `reset --hard` work the user may not have seen or pushed.

**Incident that motivated the hardening (2026-05-26):** a King session repeatedly ran `git reset --hard origin/develop && git clean -fd` on the kingdom overlay *while the user was still trying to review 3 push-eligible PRs as dirty files*. Worse, a fix had been authored ON kingdom (an R4 violation) instead of in a worktree, so the reset destroyed unpushed work. The user, rightly furious: "I MUST SEE ALL THE DIRTY FILES BEFORE YOU PUSH." The overlay is sacred until push.

**Where this is already documented (but was being skipped):**

- [`king.md`](../roles/king.md) § Push approval gate Step 8: `git restore .` OR `git reset --hard origin/develop`
- [`functions/index.md`](../functions/index.md) § `carve_and_push_feature` calls `kingdom_discard_overlay` as its FINAL action
- [`functions/index.md`](../functions/index.md) § `kingdom_discard_overlay` helper

**Required sequence after the LAST PR in a push batch goes out:**

```bash
# After `gh pr create ...` returns successfully for ALL PRs in the batch:
git -C "$WORKTREE" switch kingdom
git -C "$WORKTREE" reset --hard "origin/$BASE"   # or `git restore .` if no untracked files
git -C "$WORKTREE" clean -fd                      # remove any new untracked overlay files
git -C "$WORKTREE" status                         # MUST print "nothing to commit, working tree clean"
```

**Why this is Tier 2 not Tier 1:** Skipping it doesn't lose data (work lives on `feature/*` remotes + `worker-N` locals). But the next gate-pass overlay attempts `git apply --3way` on top of stale leftover → double-application, conflict errors, or false-positive "lane has new changes" detection. It's a correctness rule, not a safety rule.

**Incident that motivated this rule (2026-05-18):** another King session pushed 4 PRs (#255 + #257 + #258 + #259) to bfg-swt successfully, but skipped this step. the user opened GitHub Desktop, saw 18 stale uncommitted files on kingdom branch, and asked "shouldn't kingdom be clean after push?" — yes, it should. Step 8 was in `king.md` but not enforced via `rules.md`, so the lane-spawned King missed it.

**Distinguished from R26:**

| Trigger | Rule | Sequence |
|---|---|---|
| `gh pr create` returns success | **R29** (this rule) | discard overlay → kingdom = `origin/develop` tip (unchanged remote SHA) |
| `gh pr view <N>` flips to MERGED | **R26** post-merge resync | fetch + ff develop → kingdom = NEW `origin/develop` tip (advanced SHA) + free merged lane |

R29 fires first (per-push, no remote movement). R26 fires later when the lead merges (advances remote, then resync).
