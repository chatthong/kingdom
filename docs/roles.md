# 👋 Meet the King and the masters that work for it

> Part of the [kingdom](../README.md) docs.

One King, N masters. You talk to the King; the King talks to the masters; the masters do the work. Each is a real Claude Code session, no daemons, no orchestrator runtime, no magic. Just role discipline. When several workers attack one unit (a story, milestone, or issue) together, a **Senior** steps in as a per-story sub-orchestrator and the sole reviewer for that story pod.

## 👑 The King, Opus

Lives in your primary checkout on a local-only `kingdom` branch. **Holds your conversation.** Plans. Gates. Pushes. **Never edits files directly.** When you say "King, plan today's work," the King spawns parallel planning agents (Haiku to scan tasks, Sonnet to triage), writes its own task file with the multi-layer plan, then dispatches sub-tasks to the masters. Before any `git push`, the King runs the pre-commit gate (typecheck + tests + dry-merge + cross-lane overlap), reports back to you, and waits for explicit approval. **It's the only role with push authority, and only after you say "push."**

Full spec: [`king.md`](../.kingdom/.setting/roles/king.md).

## 👷 Workers, Opus, autonomous masters

Three (or N) parallel lanes, each a long-lived Claude Code session inside its own `git worktree` on its own local-only `worker-N` branch. Workers pick claimable sub-tasks from your task source (`TODO_Master.csv`, GitHub issues, whatever you configure), then **plan first**: every assignment begins with a task file capturing the multi-layer plan (Discovery → Strategy → Execution → Verification) before any code change happens. Inside each layer, workers spawn their own sub-agent fleet (Sonnet for edits, Haiku for bulk reads, Opus for sensitive files) with no eco-mode cap. N is chosen for best result, not for parallelism's sake. When done, the worker signals the King via a 4-step closer.

Full spec: [`worker.md`](../.kingdom/.setting/roles/worker.md).

## 🎓 Senior, Opus, story sub-orchestrator + sole reviewer

When multiple workers attack one unit (a story, milestone, or issue) in parallel, a Senior owns that pod. It is a per-story sub-orchestrator: it dispatches its workers, then merges their `worker-N` tips into a local `story/<id>` branch as real merge commits. The Senior is the **sole within-story reviewer** — it runs the story-branch gate, reviews the integrated work, routes fixes back to the owning worker, re-reviews, and repeats until the story is clean (capped). When the story passes, the Senior marks it push-eligible. The story branch stays local; only the final `story/<id>` PR reaches origin, so the whole pod ships as exactly **one PR**. The King keeps cross-story coordination; the Senior keeps within-story depth, so the same code is never reviewed twice.

Full spec: [`senior.md`](../.kingdom/.setting/roles/senior.md).

## 🧑‍💼 Co-workers, Opus, paired with you

The lanes you drive yourself. Dormant by default; activate when you say *"pair on co-worker-1, I'll redesign the checkout flow."* Inside that pane you type the brief, the co-worker assists interactively, you make the calls. Same task file convention. Same pre-commit gate. Same push approval. The difference: **you** set the scope, **you** set the pace.

Full spec: [`co-worker.md`](../.kingdom/.setting/roles/co-worker.md).

## 🕵️ Watchmen, Sonnet, always-on monitors

Passive. Continuous. Each watchman runs `/loop` in dynamic-pacing mode: 5-15 min while work is churning, backing off to a deep-quiet tier (~30 min) when nothing is moving, so a week-long run stays cheap. It runs a set of surveillance duties through a findings ledger, change-gated so quiet duties don't recompute: it watches `origin/develop` tip, runs your smoke tests on every advance, babysits open PRs (CI rollup, review state, mergeability), cross-checks lane diffs against the docs, and writes `WATCH_*.md` reports + sidebar notifications. **Read-only + test-runner + alerter.** Never edits, never pushes.

Full spec: [`watchman.md`](../.kingdom/.setting/roles/watchman.md).

## 🐱 Sub-agents, Sonnet / Haiku / Opus, one-shot

The leaves of the tree. Spawned by the King (for planning) or by any master (for execution), short-lived, single-task. Each runs its own 4-step closer. Model picked per task: Sonnet for standard work (P1), Haiku for bulk reads (P2), Opus for sensitive files (P3). Lane masters fan them out in parallel and synthesise the outputs — through the Workflow tool (the live `/workflows` view, one run per task) when the session exposes it, otherwise bounded `Agent(model=…)` calls (R53).

Full spec: [`worker.md`](../.kingdom/.setting/roles/worker.md) § Sub-agent dispatch.

## The pattern in one sentence

The King reasons about WHAT, the masters reason about HOW, and the sub-agents do the doing. You stay in one chat. Everything else is the kingdom.

## At a glance

| Role | Model | What it does | Spec |
|---|---|---|---|
| 👑 **King** | Opus | Orchestrator. Holds your conversation. Sole pusher. Never edits files. | [`king.md`](../.kingdom/.setting/roles/king.md) |
| 🎓 **Senior** | Opus | Per-story sub-orchestrator + sole within-story reviewer. Merges a worker pod into a local `story/<id>` branch, ships one PR. | [`senior.md`](../.kingdom/.setting/roles/senior.md) |
| 👷 **Worker** | Opus | Autonomous lane. Picks + executes sub-tasks. Spawns own sub-agents (no eco cap). | [`worker.md`](../.kingdom/.setting/roles/worker.md) |
| 🧑‍💼 **Co-worker** | Opus | Paired with you. Dormant until you signal. | [`co-worker.md`](../.kingdom/.setting/roles/co-worker.md) |
| 🕵️ **Watchman** | Sonnet | Passive `/loop` monitor (5-15 min, deep-quiet ~30 min). Surveillance duties via a findings ledger. Never edits, never pushes. | [`watchman.md`](../.kingdom/.setting/roles/watchman.md) |
| 🐱 **Sub-agent** | Sonnet/Haiku/Opus | One-shot via `Agent(model=…)`. Spawned by King or a lane. | [`worker.md`](../.kingdom/.setting/roles/worker.md) |

## See also

- [`cmux-integration.md`](cmux-integration.md): how roles show up in cmux.app
- [`branch-model.md`](branch-model.md): which branch each role works on
- [`configuration.md`](configuration.md): pick how many of each
