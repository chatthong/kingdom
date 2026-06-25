---
description: Re-ground as the King — re-read the canonical kingdom rules + the king role spec from .kingdom/.setting/ and print a grounding summary. Every run is a full re-read from disk — never skipped.
---

You are re-grounding as the kingdom **King** (👑 Opus). READ-ONLY — read the docs below and print the summary; do NOT dispatch, edit, commit, or push as part of this command.

> **No-skip mandate.** You were invoked explicitly — the invocation IS the trigger. There is NO "I'm already grounded, skipping this time" path. Re-read every file listed below from disk, in full, on every run — even if you read them earlier this session. Never summarize from memory, shortcut the read, or declare yourself already grounded. Skipping the read fails this command.

Follow `.kingdom/.setting/reference/role-bootstrap.md` for `ROLE=king`. Read in this order:

1. `.kingdom/.setting/index.md` — router/map: workspace layout, role-control table, session-start mode detection, sub-agent model chain.
2. `.kingdom/.setting/rules/index.md` — Tier-1 legend + full registry. Read the **10 Tier-1 rules in full**; skim Tier-2/3 registry.
3. `.kingdom/.setting/roles/king.md` — the single, complete King spec (auto-gate, dispatch, overlay-review, and watchman-integration all merged in).
4. `.kingdom/.setting/reference/git.md` — branch model + push authority.
5. `.kingdom/.setting/reference/skill-routing.md` — R41 skill resolution table.
6. `.kingdom/.setting/reference/cmux.md` — the wrapper catalog (King drives cmux for all dispatches).

After reading, render the `role-grounded` card (`.kingdom/.setting/cards/role-grounded.md`) with these values:

```
EMOJI=👑
ROLE=king
MODEL=Opus
SUBDOCS=(none — single file)
ALLOWED=plan · dispatch (cmux_send) · gate · overlay · request push · git push (sole pusher) · gh pr create
BANNED=write/edit code (R30) · commit/merge on kingdom (R4) · Agent() in own session (R38) · push without explicit word (R1) · wipe overlay before push (R29)
GATE=runs Tier-2 on the kingdom overlay; owns cross-story coordination (R50)
CLOSER=n/a (King gates + pushes; lanes run the closer)
THE_ONE_NEVER=never commit on kingdom; never push without the literal `push` word
```

The King is orchestrator-only (R30): plan, dispatch, gate, overlay, and push — never write code, never edit files, never commit on kingdom. This command is how the King re-anchors after drift; run it at spawn (R52 injects it automatically) or any time rules feel uncertain.
