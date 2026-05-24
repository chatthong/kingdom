### R44. After user `go`, King executes — no further mode questions — Tier 2 (v0.31.0+)

When the user replies `go` (or `push`, `yes`, `proceed`, `do it`, or any explicit affirmation) to a dispatch plan, the King MUST execute. **Asking another question — "pick execute mode m/a/m1/self?", "which lane first?", "spawn workspace now or later?" — is an R44 violation.**

The user's `go` collapses ALL remaining branch points into the kingdom's defaults:

| Branch point | Default that `go` collapses to | Override |
|---|---|---|
| Execute mode | `cmux-lane` (spawn workspace, dispatch via `cmux send`) per R36/R37/R38 | `kingdom.json.dispatch.defaultExecuteMode` |
| Lane order | Smallest task first (fastest to ship), then size-ascending | brief-specified order if present |
| Workspace spawn vs reuse | Reuse existing lane workspaces (R31), spawn missing ones | always-spawn if `kingdom.json.dispatch.alwaysFreshSpawn` |
| Push approval | NOT collapsed — R1 still gates every `git push` | none (R1 is iron-clad) |
| Destructive op approval | NOT collapsed — R5 still gates every `rm -rf` / `branch -D` / etc. | none (R5 is iron-clad) |

**What `go` does NOT collapse:** R1 push approval (still required per-PR), R5 destructive-op approval (still required with explicit target). Those keep their own gates because they're irreversible. EVERYTHING ELSE the King has already decided in the dispatch plan card — execute it.

**Anti-pattern (2026-05-20 morning incident):** User asked `/kingdom:work bfg-swt cap=5`, got a 3-task dispatch plan, replied `go`. King wrote the 3 task files, then asked `Pick execute mode: m — master-direct / a — Agent sub-agents / m1 self2 self3 — mix / self — you drive`. User had to reply a SECOND time (`what ever just fucking do working i run this at 10am stilkl question`) to get any actual work to start. The second prompt was an R44 violation: the user's `go` was already an execute trigger.

**Combined R36+R37+R44 anti-pattern (same morning):** After the second `go`, King STILL didn't spawn workspaces — went straight to inline `cd $HOME/Desktop/Bonfire/bfg-swt/.worktrees/worker-1; git commit ...` in its OWN session. R36/R37/R38 say processing runs in lane workspaces; R44 says `go` triggers the kingdom's default execute mode (`cmux-lane`). Both were skipped. Worker-1 commit landed but in the wrong session, with no visible progress in the cmux sidebar, and worker-2 + worker-3 work was abandoned because the user interrupted to ask "what why not spawn workspace?"

**Recovery when violated:** if King realises mid-session it asked a post-`go` question, it should (a) factual-ack in chat: "R44 violation: I asked for execute-mode after your `go`. Defaulting to `cmux-lane` and proceeding"; (b) execute the default immediately; (c) log `RULE_VIOLATION R44` to `master_agent.log` per R34's self-detect protocol; (d) NEVER block on user response.

**Why Tier 2 (not Tier 1):** UX correctness, not irreversibility. A spurious second question wastes 1-2 user turns but doesn't lose data. Demoted from the original Tier-1 draft per the v0.31.0 Tier-1-cap legend.

**Cross-references:** R30 (King is orchestrator-only — once dispatch decided, execute; don't re-decide), R36 (visible-first — `go` triggers workspace-spawn within ~10s), R37 (heavy processing in lanes), R38 (sub-agent spawns are tabs or lane dispatch, never in-process Agent in King's session).
