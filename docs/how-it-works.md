# 🧠 How it works

> Part of the [kingdom](../README.md) docs.

The King is a long-lived Claude Opus session in your project's primary checkout, on a local-only `kingdom` branch (an integration view: `develop` ⊕ every lane's tip). It **never edits files**, its job is orchestration: read `kingdom.json`, pick sub-tasks, dispatch via `cmux send` (primary), `tmux send-keys` (fallback), or `claude -p` (headless).

Each lane is a Claude teammate inside its own plain `git worktree` on its own local-only `<role>-<n>` branch. Workers pick claimable sub-tasks, execute via their own sub-agent fleet (Sonnet/Haiku/Opus, **unbounded parallel**, N chosen for *best result*, not 1:1 with files), and signal completion via a **4-step closer**:

```text
1. Raw output      →  <LOGS>/raw/<ID>__<lane>.md
2. Curated digest  →  <LOGS>/<ID>.md            (## TL;DR · first 15 lines)
3. Master log line →  <LOGS>/master_agent.log   (append-only)
4. Sentinel flag   →  <LOGS>/done/<ID>__<lane>.flag  (+ optional cmux notify)
```

Where `<LOGS> = <workspace>/.kingdom/<project>/logs/`, outside any project's git, so no `.gitignore` entries leak.

Before any sub-agent dispatch, the lane master writes a **task file** at `.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`, a checkbox doc with the multi-layer plan (Discovery → Strategy → Execution → Verification), live progress, and final summary. It's the human-readable audit trail of HOW the work happened.

The King polls the sentinel, runs your **pre-commit gate** (typecheck + tests + dry-merge against develop + cross-lane file-overlap check), writes a per-lane test report, and asks you "push?". On approval, it runs a **FINAL conflict check** against `origin/develop` via `git merge-tree` (a plumbing dry-merge with zero side effects, catches drift if the lead merged something while you were deciding), carves a fresh `feature/<topic>` branch from the lane tip, and pushes. After PR merge, the lane resets for the next sub-task.

The **Watchman** is separate: a `/loop` agent (dynamic 5-15 min) that tracks `origin/develop` tip and babysits open PRs, runs smoke when develop advances, alerts on CI transitions, posts notifications when a PR is ready to merge. Read-only + test runner + alerter. Never edits, never pushes.

Full role specs: [`../.kingdom/.setting/index.md`](../.kingdom/.setting/index.md).

## See also

- [`branch-model.md`](branch-model.md): the git dance
- [`roles.md`](roles.md): who does what
- [`cmux-integration.md`](cmux-integration.md): how dispatch and notifications happen in cmux.app
