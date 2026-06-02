# 🧠 How it works

> Part of the [kingdom](../README.md) docs.

The King is a long-lived Claude Opus session in your project's primary checkout, on a local-only `kingdom` branch (an integration view: `develop` ⊕ every lane's tip). It **never edits files**, its job is orchestration: read `kingdom.json`, pick sub-tasks, dispatch via `cmux send` (primary), `tmux send-keys` (fallback), or `claude -p` (headless).

Each lane is a Claude teammate inside its own plain `git worktree` on its own local-only `<role>-<n>` branch. Workers pick claimable sub-tasks, execute via their own sub-agent fleet (Sonnet/Haiku/Opus, **bounded parallel** — every fan-out is wrapped by `_bounded_wait` so a stalled subshell can't hang the run, R42, and aims at a soft target of `subAgents.parallelTarget` ≈ 10; N chosen for *best result*, not 1:1 with files), and signal completion via a **4-step closer**. When the session exposes the Claude Code Workflow tool, that fan-out runs through it — one run per task in the live `/workflows` view — falling back to bounded `Agent()` otherwise (R53):

```text
1. Raw output      →  <LOGS>/raw/<ID>__<lane>.md
2. Curated digest  →  <LOGS>/<ID>.md            (## TL;DR · first 15 lines)
3. Master log line →  <LOGS>/master_agent.log   (append-only)
4. Sentinel flag   →  <LOGS>/done/<ID>__<lane>.flag  (+ optional cmux notify)
```

Where `<LOGS> = <workspace>/.kingdom/<project>/logs/`, outside any project's git, so no `.gitignore` entries leak.

Before any sub-agent dispatch, the lane master writes a **task file** at `.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`, a checkbox doc with the multi-layer plan (Discovery → Strategy → Execution → Verification), live progress, and final summary. It's the human-readable audit trail of HOW the work happened.

The King polls the sentinel, runs your **pre-commit gate** (typecheck + tests + dry-merge against develop + cross-lane file-overlap check), writes a per-lane test report, and asks you "push?". On approval, it runs a **FINAL conflict check** against `origin/develop` via `git merge-tree` (a plumbing dry-merge with zero side effects, catches drift if the lead merged something while you were deciding), carves a fresh `feature/<topic>` branch from the lane tip, and pushes. After PR merge, the lane resets for the next sub-task. That's the solo path (one worker → one `feature/<topic>` PR); when several workers attack one unit together as a **story pod**, a **Senior** instead merges the pod's lane tips into a local `story/<id>` branch and ships a single `story/<id>` → `develop` PR (see below).

The **Watchman** (Sonnet) is separate: an autonomous `/loop` agent that runs a set of surveillance duties through a findings ledger — tracking `origin/develop` tip, babysitting open PRs, running smoke when develop advances, alerting on CI transitions, posting notifications when a PR is ready to merge, cross-checking each lane's diff against documented decisions, and backfilling PR numbers. It is **change-gated and self-pruning** for week-long runs (it skips redundant recompute when nothing moved and sweeps its own old artifacts), and its cadence backs off from 5-15 min on churn down to a ~30-min deep-quiet tier when the repo is idle. Read-only + test runner + alerter. Never edits task work, never pushes.

Two more roles round out the model. A **Senior** (Opus) is a per-story sub-orchestrator and the sole within-story reviewer: it owns a pod of workers, merges their lane tips into a local `story/<id>` branch, reviews the pod's work as a whole, and marks the story push-eligible as a single PR — so the King only coordinates *across* stories and never reviews the same code twice. A **Co-worker** (Opus) is paired directly with you and stays dormant until you signal it. With pods in play the gate is **three-tier**: worker typecheck in the lane → story-branch tests/smoke/lint → Senior review → your push. The solo path keeps the two-tier gate above.

Full role specs: [`../.kingdom/.setting/index.md`](../.kingdom/.setting/index.md).

## See also

- [`branch-model.md`](branch-model.md): the git dance
- [`roles.md`](roles.md): who does what
- [`cmux-integration.md`](cmux-integration.md): how dispatch and notifications happen in cmux.app
