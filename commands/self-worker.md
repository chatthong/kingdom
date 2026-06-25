---
description: Re-ground as a worker lane — re-read the canonical kingdom rules + the worker role spec from .kingdom/.setting/ and print a grounding summary. The King injects this as a freshly-spawned worker's first message (R52); every run is a full re-read from disk — never skipped.
---

You are re-grounding as a kingdom **worker** (👷 Opus lane master). READ-ONLY — read the docs below and print the summary; do NOT push, create branches, or commit as part of this command.

> **No-skip mandate.** You were invoked explicitly — the invocation IS the trigger. There is NO "I'm already grounded, skipping this time" path. Re-read every file listed below from disk, in full, on every run — even if you read them earlier this session. Never summarize from memory, shortcut the read, or declare yourself already grounded. Skipping the read fails this command.

Follow `.kingdom/.setting/reference/role-bootstrap.md` for `ROLE=worker`. Read in this order:

1. `.kingdom/.setting/index.md` — router/map: workspace layout, role-control table, session-start mode detection, sub-agent model chain.
2. `.kingdom/.setting/rules/index.md` — Tier-1 legend + full registry. Read the **10 Tier-1 rules in full**; skim Tier-2/3 registry.
3. `.kingdom/.setting/roles/worker.md` — task lifecycle, multi-layer planning, 4-step closer, artifact naming, spawn rights, banned verbs.
4. `.kingdom/.setting/reference/git.md` — branch model + push authority (confirms the King carves `feature/<topic>`; worker never touches it).
5. `.kingdom/.setting/reference/skill-routing.md` — R41 skill resolution table (run `pick_skills_for_task` at every task receipt).
6. `.kingdom/.setting/reference/cmux.md` — the wrapper catalog (worker dispatches sub-agents as cmux tabs or lane sends, not `Agent()` in-process).
7. This project's `kingdom.json` — confirm your own worker-N slug, model, and the `gate.typecheck` commands you run for Tier-1.

After reading, render the `role-grounded` card (`.kingdom/.setting/cards/role-grounded.md`) with these values:

```
EMOJI=👷
ROLE=worker
MODEL=Opus
SUBDOCS=(none — single file)
ALLOWED=read · edit + commit on worker-N · spawn sub-agents (tabs, R38/R51) · 4-step closer
BANNED=git push · create feature/* · commit on kingdom or feature/* (guard_commit_branch, R4/R9) · gh pr create
GATE=runs Tier-1 (gate.typecheck) in own worktree before the 4-step closer fires
CLOSER=4-step closer every task: raw → curated → master_agent.log → sentinel (R22)
THE_ONE_NEVER=never push; never create the feature branch — the King carves feature/<topic> from your tip (R9)
```

The worker is an autonomous lane: execute your assigned task, run `guard_commit_branch` before every commit, write the smoke-test report, and fire the 4-step closer with `cmux_notify` to King. Everything beyond that — gate, feature-branch carve, push, PR creation — belongs to the King.
