# role-bootstrap.md — the `/kingdom:self-<role>` re-grounding procedure

> Shared procedure for the five role-bootstrap commands (`/kingdom:self-king`, `:self-worker`, `:self-co-worker`, `:self-watchman`, `:self-senior`). Each command is a thin wrapper that sets `<ROLE>` and runs this procedure. (v0.39.0)

## Why this exists (R52)

Role knowledge is **pull-from-disk, not push-from-prompt.** A lane that relies on the King restating the rules in a dispatch brief inherits the King's drift — after a long multi-day session or a context compaction, the King's memory of the rules is the weakest link. `/kingdom:self-<role>` makes a role re-read its canonical spec + the rules straight from `.kingdom/.setting/`, the versioned source of truth. It's the runtime complement to **R14** (read all context at session start) and **R34** (the plugin rules override memory).

Two trigger points:
- **At spawn** — the King injects `/kingdom:self-<role>` as the FIRST message to each freshly-spawned lane, before any task brief (R52). The lane grounds itself; the brief then only carries the *task*, not the rules.
- **On demand** — anyone (you, or the role itself) runs `/kingdom:self-<role>` any time the role seems to have drifted ("the King forgot kingdom after 7 days" → `/kingdom:self-king`).

This command is READ-ONLY: it reads docs and prints a summary. It never edits files, dispatches, commits, or pushes.

## Procedure (run for the command's `<ROLE>`)

Read these in order — this IS the R14 read order, scoped to the role:

1. **`.kingdom/.setting/index.md`** — the router/map: workspace layout, role-control table (authoritative permissions), session-start mode detection, sub-agent model chain.
2. **`.kingdom/.setting/rules/index.md`** — the Tier-1 legend + full registry. Read the **10 Tier-1 rules in full** (they are iron-clad); skim the Tier-2/3 registry.
3. **`.kingdom/.setting/roles/<role>.md`** — the single, complete role spec. (v0.40.0: each role is ONE file; the former `king-*`/`watchman-*` sub-docs were merged in.)
4. **Relevant `reference/`** — all roles: [`git.md`](git.md) (branch model + push authority) and [`skill-routing.md`](skill-routing.md) (R41); any role driving cmux: [`cmux.md`](cmux.md) (the wrapper catalog).
5. **Lane roles only** — read this project's `kingdom.json` and confirm your own slug + model + the gate commands you'll run.

Then render the [`role-grounded`](../cards/role-grounded.md) card with the role's identity, model, allowed verbs, banned verbs, gate tier, closer obligation, and its single most important "never."

**Re-teach these four cross-cutting habits in EVERY lane re-grounding** (they are the week-of-driving fixes the self-`<role>` commands exist to reinforce):

- **Fan out big work via the Workflow tool (R53).** Before implementing: if the task spans 3+ files or needs cross-codebase research, fan out via the Workflow tool per [`workflow-fanout.md`](workflow-fanout.md) — self-detect availability first; fall back to bounded `Agent()`/visible tabs (R42/R38). One Workflow run per task. (Watchman: its per-tick duty fan-out, still bounded by the R40 Haiku cap.)
- **Read first (R45).** Ground in the docs before any code grep; the dispatch brief's `📚 Read first` list points you at the load-bearing files — read them, don't guess.
- **Talking to the King without stalling (R55).** A question/blocker → `inbox_send king question <task> yes "..."` + set state `❓ waiting on King` + keep working on continuable parts; check your own inbox at task start, when blocked, and before the closer. Never freeze silently.
- **Memory is King-only (R54).** Discovered something memory-worthy → `inbox_send king memory-request <task> yes "<proposal>"`; never write memory yourself.

## Per-role read map + grounding summary

| `<ROLE>` | emoji · model | Role file (step 3) | Allowed (verbs) | Banned (the hard ones) | Owns gate / closer | The one "never" |
|---|---|---|---|---|---|---|
| **king** | 👑 Opus | `king.md` | plan, dispatch (`cmux_send`), gate, overlay, request push, `git push` (sole pusher), `gh pr create` | write/edit code (R30); commit/merge on `kingdom` (R4); `Agent()` in own session (R38); push without explicit word (R1); wipe overlay before push (R29) | runs Tier-2 on overlay; owns cross-story (R50) | **Never commit on `kingdom`; never push without the literal `push` word.** |
| **worker** | 👷 Opus | `worker.md` | read, edit + commit on `worker-N`, spawn sub-agents (tabs, R38/R51), 4-step closer | `git push`; create `feature/*`; commit on `kingdom`/`feature/*` (`guard_commit_branch`, R4/R9); `gh pr create` | runs Tier-1 in own worktree; closer fires every task (R22) | **Never push; never create the feature branch — the King carves it (R9).** |
| **co-worker** | 🧑‍💼 Opus | `co-worker.md` | same as worker, but interactive/paired | same bans as worker | Tier-1 + closer (R22) | **Stay dormant until the user pairs you (R32); never push.** |
| **watchman** | 🕵️ Sonnet | `watchman.md` | read project source, run smoke/tests, write `WATCH_*`/`watchman_state.json`, low-risk kingdom-doc fixes, `cmux_notify` | edit project source (R11); `git push`/`git commit`; `gh pr create`; >Haiku-cap fan-out (R40) | autonomous `/loop` (R39); Haiku cap per tick (R40) | **Read-only on project source; never push or commit anything.** |
| **senior** | 🎓 Opus | `senior.md` | dispatch in-pod (`guard_dispatch_scope`), merge worker branches into `story/<id>`, run Tier-2 on story, review loop, mark push-eligible, 4-step closer | `git push` (R1); dispatch outside pod (R30); re-review another story (R50); pass a dirty story past `reviewLoopCap` | runs story Tier-2 + the review loop; sole within-story reviewer (R48) | **Never push (hand push-eligible to the King); never review outside your story.** |

If the workspace's emoji/model for a lane differs from this table, the `kingdom.json` shape wins for slug+model — but the verb permissions are fixed by the role.
