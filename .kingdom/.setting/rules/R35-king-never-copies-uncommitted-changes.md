### R35. King never copies uncommitted changes between worktrees — Tier 1 (v0.26.0+)

Each lane's `.worktrees/<lane>/` is **its own work surface**. King's allowed cross-worktree operations are:

✅ **Read** any worktree (`cat .worktrees/<lane>/path/to/file`) for audit/dispatch context.

✅ **`git diff origin/<base>..<lane> | git apply --3way -`** onto kingdom's working tree (R4 overlay for review; never commits on kingdom).

❌ **BANNED:** `cp .worktrees/worker-1/some-file .worktrees/worker-2/some-file` (or any other file-move/copy between lane worktrees).

❌ **BANNED:** committing into a lane's branch any content that wasn't authored by that lane (whether by King's own hand, or copied from another lane, or pulled from an external scratch dir).

**Why:** R30 says King is orchestrator-only. Copying uncommitted content from worker-1 → worker-2 + committing on worker-2's branch makes King the author of worker-2's commit. That's worker work. The audit trail says "worker-2 did this work" but the actual editor was King. Future blame / debugging / review goes to the wrong agent.

**Correct alternative:** dispatch a brief to worker-2 explaining what the change should be. Let worker-2 author the change in its own worktree from its own context. If the change is "literally copy this Dockerfile from worker-1," the brief says so explicitly — but worker-2 does the copy + commit.

**Edge case — shared infrastructure files (Dockerfile, ci.yaml, package.json) that multiple lanes need:** the change goes to ONE lane (whichever owns the file per the task), gets reviewed, gets merged to develop, then other lanes rebase. Don't cross-pollinate uncommitted shared files between lanes via King.

**Anti-pattern caught 2026-05-19:** King authored Dockerfile changes (3 ENV lines + 4-line comment for `@workspace/db` build-env placeholders) on worker-1's worktree, then `cp`'d the modified Dockerfile to `.worktrees/worker-2/` and included it in worker-2's commit as "part of the @workspace/db enabling slice." King defended: "the modification was already in your worker-1 worktree when I scanned" — but that's not exculpatory; King STILL did the cross-worktree copy + commit on the wrong lane. The proper move would have been: leave the Dockerfile change on worker-1 OR dispatch worker-2 to make the change in its own worktree.

**Why Tier 1:** breaks the per-lane authorship invariant that the entire audit trail (master_agent.log, sentinel-to-commit mapping, blame) depends on. Once King is a hidden author on lane branches, "who did this" stops being a clean question.

### Self-detect: when King catches its own violation

If King realises it has violated R30 / R31 / R33 / R35 (or any other Tier-1 rule) mid-session:

1. **STOP immediately.** Don't continue down the violating path.
2. **Acknowledge in chat factually.** ("I violated R31 — I didn't spawn cmux workspaces despite worktrees existing in AGENT-mode-mistaken state. Repairing now.")
3. **Repair.** Re-run the violated step correctly (spawn cmux now, dispatch the missing brief, revert the cross-worktree commit, etc).
4. **Log to master_agent.log:** one line `[UTC] RULE_VIOLATION R<N> · <one-line description> · repaired by <action>`.
5. **NEVER continue dependent work without repair.** If R31 was violated by skipping spawn, do NOT proceed to Step 4 dispatch until spawn is corrected.

Per R34, performative apology is still banned. Acknowledgement is factual + repair-focused.
