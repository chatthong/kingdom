# 👋 Meet the King and the masters that work for it

> Part of the [kingdom](../README.md) docs.

One King, N masters. You talk to the King; the King talks to the masters; the masters do the work. Each is a real Claude Code session, no daemons, no orchestrator runtime, no magic. Just role discipline.

## 👑 The King, Opus

Lives in your primary checkout on a local-only `kingdom` branch. **Holds your conversation.** Plans. Gates. Pushes. **Never edits files directly.** When you say "King, plan today's work," the King spawns parallel planning agents (Haiku to scan tasks, Sonnet to triage), writes its own task file with the multi-layer plan, then dispatches sub-tasks to the masters. Before any `git push`, the King runs the pre-commit gate (typecheck + tests + dry-merge + cross-lane overlap), reports back to you, and waits for explicit approval. **It's the only role with push authority, and only after you say "push."**

Full spec: [`king.md`](../.kingdom/.setting/roles/king.md).

## 👷 Workers, Opus, autonomous masters

Three (or N) parallel lanes, each a long-lived Claude Code session inside its own `git worktree` on its own local-only `worker-N` branch. Workers pick claimable sub-tasks from your task source (`TODO_Master.csv`, GitHub issues, whatever you configure), then **plan first**: every assignment begins with a task file capturing the multi-layer plan (Discovery → Strategy → Execution → Verification) before any code change happens. Inside each layer, workers spawn their own sub-agent fleet (Sonnet for edits, Haiku for bulk reads, Opus for sensitive files) with no eco-mode cap. N is chosen for best result, not for parallelism's sake. When done, the worker signals the King via a 4-step closer.

Full spec: [`worker.md`](../.kingdom/.setting/roles/worker.md).

## 🧑‍💼 Co-workers, Opus, paired with you

The lanes you drive yourself. Dormant by default; activate when you say *"pair on co-worker-1, I'll redesign the checkout flow."* Inside that pane you type the brief, the co-worker assists interactively, you make the calls. Same task file convention. Same pre-commit gate. Same push approval. The difference: **you** set the scope, **you** set the pace.

Full spec: [`co-worker.md`](../.kingdom/.setting/roles/co-worker.md).

## 🕵️ Watchmen, Sonnet, always-on monitors

Passive. Continuous. Each watchman runs `/loop` in dynamic-pacing mode (5-15 min). It watches `origin/develop` tip, runs your smoke tests on every advance, babysits open PRs (CI rollup, review state, mergeability), and writes `WATCH_*.md` reports + sidebar notifications. **Read-only + test-runner + alerter.** Never edits, never pushes.

Full spec: [`watchman.md`](../.kingdom/.setting/roles/watchman.md).

## 🐱 Sub-agents, Sonnet / Haiku / Opus, one-shot

The leaves of the tree. Spawned by the King (for planning) or by any master (for execution). `Agent(model=…)` calls, short-lived, single-task. Each runs its own 4-step closer. Model picked per task: Sonnet for standard work (P1), Haiku for bulk reads (P2), Opus for sensitive files (P3). Lane masters fan them out in parallel and synthesise the outputs.

Full spec: [`worker.md`](../.kingdom/.setting/roles/worker.md) § Sub-agent dispatch.

## The pattern in one sentence

The King reasons about WHAT, the masters reason about HOW, and the sub-agents do the doing. You stay in one chat. Everything else is the kingdom.

## At a glance

| Role | Model | What it does | Spec |
|---|---|---|---|
| 👑 **King** | Opus | Orchestrator. Holds your conversation. Sole pusher. Never edits files. | [`king.md`](../.kingdom/.setting/roles/king.md) |
| 👷 **Worker** | Opus | Autonomous lane. Picks + executes sub-tasks. Spawns own sub-agents (no eco cap). | [`worker.md`](../.kingdom/.setting/roles/worker.md) |
| 🧑‍💼 **Co-worker** | Opus | Paired with you. Dormant until you signal. | [`co-worker.md`](../.kingdom/.setting/roles/co-worker.md) |
| 🕵️ **Watchman** | Sonnet | Passive monitor (`/loop`, 5-15 min). Smoke + PR babysitting. Never edits, never pushes. | [`watchman.md`](../.kingdom/.setting/roles/watchman.md) |
| 🐱 **Sub-agent** | Sonnet/Haiku/Opus | One-shot via `Agent(model=…)`. Spawned by King or a lane. | [`worker.md`](../.kingdom/.setting/roles/worker.md) |

## See also

- [`cmux-integration.md`](cmux-integration.md): how roles show up in cmux.app
- [`branch-model.md`](branch-model.md): which branch each role works on
- [`configuration.md`](configuration.md): pick how many of each
