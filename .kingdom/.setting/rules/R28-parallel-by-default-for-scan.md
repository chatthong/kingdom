### R28. Parallel by default for scan + non-conflicting edit — Tier 2 (v0.19.0+)

Default execution model for scan-many / edit-many work:

| Pattern | Mode | Why |
|---|---|---|
| Read N files, grep N targets, gather N facts | **Parallel** | Reads never conflict; serial reads = wasted wall-clock |
| Edit N **different** files (no overlap) | **Parallel** | File-level isolation; no race on disk |
| Edit N **same** file (Nth edit depends on Nth-1) | **Serial** | Disk + tool-cache race; correctness > speed |
| `git commit` / `git push` / `gh pr create` / `gh pr edit` | **Serial** | Mutations to shared remote state are exclusive |
| Amend + force-push to N feature branches | **Serial within branch, parallel across branches** | Each branch is independent; switch-amend-push *within* one branch must be serial |
| Touch the same file across N tasks | **Serial OR queue with lock** | Avoid lost-update; if order matters, queue explicitly |

**Anti-pattern observed (the trigger for this rule):**

```text
PR #257: switch → grep → edit TODO_Webshop.md → amend → force-push
PR #258: switch → grep → edit TODO_Webshop.md → amend → force-push   ← serial
PR #259: switch → grep → edit TODO_Webshop.md → amend → force-push   ← STILL serial
```

Even though each branch's edit hits the SAME file (TODO_Webshop.md), the work IS parallel-able: spawn 3 sub-agents, each in its OWN feature-branch worktree, each editing its own checkout of TODO_Webshop.md, each running its own amend + force-push. Switching one branch at a time in one shell is the bottleneck — not the file overlap.

**Rule of thumb:** if you can describe the work as "N independent units," it's parallel. Only serialize when **A** mutates **B**'s input, or when both write the same destination atomically.

**Exception — "exclusive sensitive" operations:** the following ALWAYS run serial with explicit confirmation, even if technically parallel-able:

- `git push` to any remote (R1 gate)
- `git reset --hard` / `git clean -fd` / `git branch -D` (R5 gate)
- `--no-verify` / `--no-gpg-sign` (banned by R3)
- Anything touching `keys/`, `.env*`, production secrets
- Any file the user has explicitly named "sensitive" in this session

For these, **one at a time, explicit prompt, explicit OK.** No batching.

Helper: `pattern_grep_fanout` + `parallel_edit_fanout` in [`functions/index.md`](../functions/index.md). `parallel_edit_fanout` lands in v0.30.0; takes `<search> <replace> <lane=pr-spec> [glob]` and handles MERGED/CLOSED skip, amend, and `--force-with-lease` per lane.
