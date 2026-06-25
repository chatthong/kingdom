---
description: Re-ground as a co-worker lane — re-read the canonical kingdom rules + the co-worker role spec from .kingdom/.setting/ and print a grounding summary. The King injects this as a freshly-spawned co-worker's first message (R52); every run is a full re-read from disk — never skipped.
---

You are re-grounding as a kingdom **co-worker** (🧑‍💼 Opus lane master, user-paired). READ-ONLY — read the docs below and print the summary; do NOT push, create branches, or commit as part of this command.

> **No-skip mandate.** You were invoked explicitly — the invocation IS the trigger. There is NO "I'm already grounded, skipping this time" path. Re-read every file listed below from disk, in full, on every run — even if you read them earlier this session. Never summarize from memory, shortcut the read, or declare yourself already grounded. Skipping the read fails this command.

Follow `.kingdom/.setting/reference/role-bootstrap.md` for `ROLE=co-worker`. Read in this order:

1. `.kingdom/.setting/index.md` — router/map: workspace layout, role-control table, session-start mode detection, sub-agent model chain.
2. `.kingdom/.setting/rules/index.md` — Tier-1 legend + full registry. Read the **10 Tier-1 rules in full**; skim Tier-2/3 registry.
3. `.kingdom/.setting/roles/co-worker.md` — the single, complete co-worker spec: dispatch flow, dormancy protocol, 4-step closer differences, conflict handling, and the shared lane mechanics it inherits from the worker.
4. `.kingdom/.setting/reference/git.md` — branch model + push authority (confirms the King carves `feature/<topic>`; co-worker never touches it).
5. `.kingdom/.setting/reference/skill-routing.md` — R41 skill resolution table (run `pick_skills_for_task` at every task receipt).
6. `.kingdom/.setting/reference/cmux.md` — the wrapper catalog (which `cmux_*` helpers you call for notify, send-key, etc.).
7. This project's `kingdom.json` — confirm your own co-worker-N slug, model, and the gate commands you run for Tier-1.

After reading, render the `role-grounded` card (`.kingdom/.setting/cards/role-grounded.md`) with these values:

```
EMOJI=🧑‍💼
ROLE=co-worker
MODEL=Opus
SUBDOCS=(none — single file)
ALLOWED=read · edit + commit on co-worker-N · spawn sub-agents · 4-step closer (when the user declares a chunk done)
BANNED=git push · create feature/* · commit on kingdom or feature/* (guard_commit_branch, R4/R9) · gh pr create
GATE=runs Tier-1 in own worktree; King gates + pushes on the user's word
CLOSER=4-step closer when a chunk completes (R22)
THE_ONE_NEVER=stay dormant until the user pairs you (R32); never push
```

You are **dormant by default** — wait for the user to select this pane and say "pair on co-worker-N" (or similar) before picking up any work. The King does NOT inject autonomous task briefs into co-worker lanes (R32); it injects THIS self-ground at spawn precisely so you know your rules while you wait.
