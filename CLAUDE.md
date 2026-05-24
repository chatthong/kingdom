# CLAUDE.md — claude-kingdom plugin repo

This file orients future Claude sessions to the project so work can continue across conversations.

## What this repo is

`claude-kingdom` (published as the **kingdom** Claude Code plugin at `github.com/chatthong/kingdom`). A multi-agent orchestration kit: one King (Opus) coordinates N workers / co-workers / watchmen, each in its own `git worktree` on its own local-only branch, dispatched via cmux.app (primary) or raw tmux (fallback) or headless `claude -p` (last resort).

**The plugin is shape-only**: it ships role specs, slash commands, card templates, and helper bash. It does NOT bundle a runtime. The kingdom runs entirely on Claude Code + git worktrees + cmux/tmux/jq/gh — all standard dev tooling.

**Domain-agnostic by design.** Workers are generic capacity; `gate.*` commands are arbitrary bash. Same kit works for code, research, finance models, manuscripts, anything you version with git.

## Current state — v0.35.0 (2026-05-24)

The plugin is on `main`. **v0.35.0** completes the modular architecture (the big upgrade): `manifest.json` + `functions/_load.sh load_feature` (composability — features plug in/out, no core edits); role docs moved to `roles/` (king/worker/co-worker/watchman/senior, with king/watchman slimmed into `roles/king-*.md`/`watchman-*.md` sub-docs) and cross-cutting guides to `reference/` (cmux/git/skill-routing), all cross-refs rewired (0 broken links); shared mechanics de-duplicated; structure-lint added to `/kingdom:self-care` (Check 11). Only cosmetic follow-up left: deep `R##` anchor links still point at the `rules.md`/`_primitives.md` pointers. **v0.34.0** was a modular reorg (phase 1, packaging only): `rules.md` → `rules/` (one rule per file `R01`…`R50` + `rules/index.md` registry); `_primitives.md` → `functions/` (42 `*.sh` one-per-file + `functions/index.md` + `functions/_load.sh` loader). Both old files are now thin pointers, so existing references still resolve. Phase 2 (deferred): role docs → `roles/`, reference docs → `reference/`, and deep `R##` anchor rewiring. **v0.33.0** was a command-surface cleanup (breaking): `/kingdom:init` takes no flags (scaffold only); `/kingdom:work` shape is per-role (`worker=`/`co-worker=`/`watchman=`/`senior=`, plural accepted) or `lane=N` (King auto-composes a total budget); pacing is two plain ceilings `pr-limit=N` + `pod-limit=N` (`cap` renamed, `target` removed); the `cap-reached` card became `limit-reached`; pods now explicitly persist `logs/` + `tasks/` like every lane. **v0.32.0** added story pods: the **Senior** role (🎓 Opus) + local **story integration branch** (King owns cross-story R50; Senior owns within-story R48; three-tier gate R47). Spec: `docs/superpowers/specs/2026-05-23-senior-story-pods-design.md`. All releases since v0.18.0 ship per-release; no separate release branch.

Recent version history (worth reading the CHANGELOG for full detail):

| Version | Theme | What landed |
|---|---|---|
| **0.31.1** | Consumer-test fixes + R45 doc orientation + watchman senior-dev review + worker smoke-tests | Two bugs caught in 2026-05-21 consumer testing: (1) `spawn_master_workspace` relied on `cmux new-workspace --command "claude"` which was unreliable — workspaces came up at bash prompts and the King's `cmux send` of the dispatch brief landed in shell. Fixed: explicit post-spawn `claude\n` via `cmux rpc surface.send_text` + 1.5s sleep (same pattern as `spawn_watchman_loop`). (2) `commands/work.md:555` was calling `overlay_lane_onto_kingdom` — a function that didn't exist anywhere (the v0.30.0 helper was named `kingdom_overlay_lane`, never updated). Bash function-not-found is silent → Tier-2 gate ran against an empty kingdom branch. Same fix also caught a `BASE` variable shadow in the poll loop that had been silently malforming `N_MODIFIED` in push-prompt metadata. **NEW R45 (Tier 2):** every role calls `haiku_read_docs_orientation` for big-picture context (Phase 1: scan every dir for readme/index/todo, up to 30 files, 10 parallel Haiku; Phase 2: 20 newest *.md project-wide, same fan-out). Locks model defaults: Haiku for doc reads, Sonnet for lane sub-agents. **Watchman Duty 1 expanded:** now includes a doc cross-check dimension — Haiku reviews each lane's diff against root + docs/ markdown, flagging contradictions to documented decisions as urgent. King's overlay state is reviewed as a third reviewee. **Worker smoke-test reports MANDATORY** at every task close — write `LANE_<UTC>__<lane>__<id>.md` to `<project>/docs/test-reports/`, format-discovery first (R8 spirit). **Sub-agent pool defaults to Sonnet** (was implicit Opus). Pre-commit 10-Haiku-army audit caught 16 distinct issues; 7 critical/high fixed inline. |
| **0.31.0** | Hard gates replace prose; Tier 1 capped at 10 | After v0.30.0 shipped, a 4-hour consumer session (`/kingdom:work bfg-swt cap=5`, 2026-05-20 morning) shipped 0 PRs despite all lanes spawning. The King violated R4 (committed on `feature/*` then FF-merged onto `kingdom`), R9 (feature ≠ worker-N byte-for-byte), R30+R37 (`cd .worktrees/worker-1 && git commit` in its OWN session), R36 (skipped lane spawn entirely until user asked), and re-asked execute-mode after `go`. **Diagnosis: prose rules aren't gates.** v0.31.0 picks a different lane: 5 new helpers in `_primitives.md § Hard gates` BLOCK these at call site — `guard_worker_commit_branch` (R4+R9), `guard_lane_workspace_exists` (R31+R36), `guard_no_king_session_worktree_cd` (R30+R37), `kingdom_overlay_lane` (R15 — correct overlay flow), `spawn_watchman_loop` (R39 — auto-dispatch `/loop`). Plus `rules.md` opens with a **Tier 1 cap legend**: exactly 10 iron-clad rules (R1, R2, R4, R5, R14, R22, R30, R31, R36, R42); 29 prior Tier-1 markers demoted to Tier 2 by the legend. **NEW R43 (Tier 2):** closing actions (AC flips, heading suffix, Final summary, closer) agent-owned; brief MUST NOT annotate as user-owned. **NEW R44 (Tier 2):** after user `go`, King executes — no more "pick execute mode m/a/m1/self?" questions. **R33 amended:** mandatory `git fetch` + merged-PR scan + recovery-PR detect BEFORE reading task files (the 0-jobs morning's root cause). |
| **0.30.0** | Open-thread cleanup + R42 (bounded wait) | Closed 3 v0.29.x open threads: (1) `king.md` Step 7 now calls `kingdom_resync_after_merge` (preserves worker worktree per R35, was destroy+recreate); (2) `parallel_edit_fanout` helper body + `watchman.md` rewired; (3) `/kingdom:self-care` Check 9 detects workspace files missing from plugin source. **NEW R42 (Tier 1):** every parallel fan-out uses `_bounded_wait`, never bare `wait` — diagnosed via live cmux audit (all cmux ops <0.65s; real hang was bare `wait` in 5 sites blocking on stuck git/gh subshells). `_bounded_wait` helper added; 5 sites converted (work.md ×2, save.md, watchman.md, parallel_edit_fanout itself). |
| **0.29.4** | R41 propagation + role-doc step audit (no spec changes) | Version bump only; confirms R41 propagated correctly across role docs and step sequences; no new rules or spec changes |
| **0.29.3** | Skill-aware execution: R41 + routing table expansion | R41 (Tier 1): 3-step skill resolution before any work (routing table → system-reminder fallback → skip); 15 new skill-routing.md entries (Prisma family ×7, remaining superpowers ×8); auto-discovery fallback section; ASCII wizard mascot removed from README |
| **0.29.2** | README polish: ASCII wizard mascot + `/kingdom:work` shape examples | ASCII wizard mascot added under README header (inside `[!WARNING]` amber frame); 12 expanded examples in 4 categories; 6-row shape-by-situation guide |
| **0.29.1** | Stale-reference audit + fix across 22 files | 5 parallel Haiku audits found ~50 stale old-command refs; 4 parallel Sonnet fixers patched rules.md, watchman.md, all 16 affected cards, docs/branch-model.md, docs/cmux-integration.md, CLAUDE.md (rule counts); README tightened to 4-command arc |
| **0.29.0** | Hard-break: 4-command surface + autonomous watchman + state.json save protocol | 6 commands collapsed to 4: `/kingdom:work` (replaces `day`+`start`+`update`), `/kingdom:self-care` (replaces `doctor`), `/kingdom:save` (replaces `exit`, state-snapshot-only), `/kingdom:init` (slimmer, no prereq checks); R39 (watchman autonomous); R40 (Haiku cap) |
| **0.28.0** | Visible-first execution + interactive no-args mode | R36/R37/R38 (Tier 1): King renames workspace + spawns all lanes visibly within ~10s of `/kingdom:work`; heavy processing routes to lane sessions via `cmux send`; Agent() in King's session banned; new interactive Step 0.0 + `what-to-work-on` card (21st card) |
| 0.27.0 | Multi-window cmux.app support | `kingdom.json.cmux.spawnWindow` config (`"current"` / `"new"` / `"<uuid>"`); `spawn_master_workspace` updated; documented: default-to-caller's-window is multi-window-compatible; `cmux.md` § Multi-window added |
| 0.26.0 | R34/R35 + self-detect protocol | R34 (Tier 1): Tier-1 rules override memory/feedback notes; R35 (Tier 1): King never `cp`s uncommitted changes between worktrees; self-detect protocol added (STOP → factual ack → repair → log → no dependent work without repair) |
| 0.25.0 | Resume queue + R33 task-state scan | R33 (Tier 1): King reads `.kingdom/<project>/tasks/` BEFORE dispatch every session; R31 expanded to AGENT-mode worktree check; `cards/resume-queue.md` (20th card); `/kingdom:day` Step 0.6 resume scan |
| 0.24.0 | R30/R31/R32 + King-is-dispatcher hardening | R30 (Tier 1) 60s dispatch budget; R31 (Tier 1) lane-readiness gate before dispatch; R32 (Tier 2) co-worker-only staged/waiting; `/kingdom:day` Step 0.5 lane gate; `CLAUDE.md` added to repo |
| **0.23.0** | Per-task skill routing | `skill-routing.md` (~40 keyword→skill mappings), `pick_skills_for_task` helper, `${SUGGESTED_SKILLS}` in dispatch-brief, user-override `skill=name1,name2` / `skill=none` |
| 0.22.0 | 19-card display library | All 6 slash commands wired to cards; welcome card with weather; `task-complete` random pool (20 lines); `${USER_NAME}` instead of hardcoded `Ter`; `fetch_weather_line` / `random_task_done_line` / `render_card` helpers |
| 0.21.0 | README slim + docs/ split | README 739→210 lines; 8 docs files; cmux sidebar ASCII→mermaid |
| 0.20.0 | `/kingdom:day` promotion | Always-run update; `target=N-M/<day\|week\|month>` auto-split; `cap=N`; local date+time; Suggested next task synthesis |
| 0.19.1 | R29 post-push overlay-discard | After-push overlay-discard is now an enforceable Tier-2 rule (was a Step 8 buried in `king.md`) |
| 0.19.0 | Priority-tiered rules + post-merge automation | `rules.md` (R1-R28), `_primitives.md`, R26 (post-merge kingdom resync), R27 (watchman PR-number backfill), R28 (parallel by default); bash-trim consolidation; `commands/exit.md` `close-workspace` bug fix + parallelisation |
| 0.18.x | Magic + fast | `/kingdom:day` introduced; pre-warmed sub-agent pool; auto-generated PR bodies |
| 0.17.x | Working-tree overlay model | `kingdom` branch never commits; `git apply --3way` overlay for review; feature-branch byte-for-byte from worker-N tip |

## Directory layout

```
.claude-plugin/
  plugin.json              # name=kingdom, version=0.35.0
  marketplace.json         # registry entry

commands/                  # 4 slash commands
  work.md                  # THE daily ritual (audit + spawn + kickoff + poll + push gates)
  save.md                  # state snapshot (lane + task state → state.json; no commits/pushes)
  init.md                  # workspace + project scaffolding
  self-care.md             # prereq checker

.kingdom/.setting/         # canonical source — copied into workspace by /kingdom:init
  index.md                 # entry-point router + the map
  rules/                   # one rule per file (R01..R50) + index.md registry (Tier 1/2/3; Tier-1 capped at 10) — v0.34.0
  functions/               # one bash helper per file (42 *.sh) + index.md + _load.sh loader — v0.34.0
  manifest.json            # feature registry (core/senior/watchman) for load_feature — v0.35.0
  roles/                   # king/worker/co-worker/watchman/senior.md (+ king-*/watchman-* sub-docs) — v0.35.0
  reference/               # cmux.md git.md skill-routing.md (shared guides) — v0.35.0
  cards/                   # 24 display templates + README
  rules.md / _primitives.md  # thin pointers into rules/ and functions/ (back-compat)

docs/                      # 8 long-form topic docs (split from README in v0.21.0)
  branch-model.md  cmux-integration.md  configuration.md  work-cycle.md
  faq.md  how-it-works.md  roles.md  why.md

README.md                  # slim landing page (210 lines)
CHANGELOG.md               # Keep-a-Changelog format; entries from v0.5.0 onward
```

## Key architectural decisions — 28 total (don't re-debate without reading the rationale)

1. **`kingdom` branch is a working-tree overlay, never commits** (v0.17.0 → R4 + R29). King resets to `origin/develop`, then `git diff worker-N | git apply --3way` per lane. After push, `git restore .` discards. Reviewer sees all in-flight lanes as UNCOMMITTED files in GitHub Desktop's Changes tab. Push approval (R1) requires Tier-2 gate pass on the overlay.

2. **`feature/<topic>` is byte-for-byte from `worker-N` tip** (v0.16.3 → R9). NO commits added on the feature branch after carving. The PR ships exactly what's on the lane tip. Reviewers see one-commit clean PRs; lanes keep accumulating work between dispatches.

3. **Lane branches stay local; only `feature/<topic>` reaches origin** (R6). `worker-N` / `co-worker-N` / `watchman-N` / `kingdom` are local-only. Soft rule: don't manually create branches in these names (R21 namespace reserved).

4. **Two-tier gate** (v0.16.0 → R13). Tier-1 = `gate.typecheck` in lane worktree (seconds). Tier-2 = `gate.tests + smoke + lint` on the kingdom overlay (minutes). Push approval requires Tier-2 pass.

5. **Push approval is single-shot + PR-specific** (R1). The literal word `push` (or close variants) per PR. Generic `yes` / `fire all` / approval-for-another-PR do NOT count. Previous violation: another King session pushed 4 PRs without approval; R1 codified to prevent recurrence.

6. **Closer fires on EVERY task completion** (R22). 4 steps: raw → curated → `master_agent.log` line → sentinel flag. (5 steps for tab-spawned sub-agents: also close own tab.) No silent exits even on blocked/errored.

7. **Task file Step 0 is mandatory** (R23). `.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md` exists BEFORE any sub-agent dispatch, code edit, or Layer-1 grep. Required schema: Status / Brief / Plan (multi-layer) / Progress notes / Final summary.

8. **Update BOTH kingdom task file AND project task-ledger** (R25). Kingdom file = audit trail for King + user; project file (TODO_*.md / CSV / STEP.md) = public source for lead + reviewers. Both flip in worker's single task commit.

9. **Post-merge kingdom resync** (R26 + `kingdom_resync_after_merge` in `_primitives.md`). When `gh pr view <N>` flips MERGED, run 7-step resync: detect → clean overlay → fetch+ff base → reset kingdom → free merged lane → rebase remaining → log line.

10. **Watchman owns PR-number backfill** (R27, v0.19.0). Worker commits `(PR #pending)` because PR doesn't exist at commit time. Watchman's `/loop` does parallel `(PR #pending) → (PR #N)` flips per-lane in own worktrees + amends + `--force-with-lease`. Skips already-MERGED PRs.

11. **Parallel by default for scan + non-conflicting edit** (R28, v0.19.0). Reads/independent edits = parallel; `git commit`/`git push`/`gh pr create` = serial; "exclusive sensitive" ops (push, hard reset, branch delete, `keys/*`, `.env*`) = serial + explicit confirmation.

12. **Cards over inline templates** (v0.22.0). All user-facing output is `render_card "name"` against `.kingdom/.setting/cards/*.md`. Each card wraps a box-drawn body in a GitHub alert (`[!NOTE]`/`[!TIP]`/`[!IMPORTANT]`/`[!WARNING]`/`[!CAUTION]`) for coloured rendering in Claude Code chat.

13. **Per-task skill routing** (v0.23.0). King runs `pick_skills_for_task` per dispatch, picks up to 3 from `.kingdom/.setting/reference/skill-routing.md` keyword table, embeds in dispatch-brief. Skills are NOT lane-permanent; each task re-picks.

14. **King is orchestrator-only — never executes task work** (R30, v0.24.0). Allowed verbs: plan, dispatch, gate-fire, overlay, request push approval, read audits. BANNED: write code, draft multi-batch execution tables in chat, run gates manually for a lane. Hard 60s budget from Step 4 reaching auto-dispatch to first `cmux send`.

15. **Lane-readiness gate before every dispatch** (R31, v0.24.0). `workspace-refs.env` must list every lane; `cmux tree --all` must show them alive. Universal "lanes exist" signal is `.worktrees/<lane>/` directories (mode-agnostic). If worktrees exist but cmux refs are missing, fall to AGENT mode rather than re-spawning. No dispatch fires until lanes confirmed.

16. **Co-worker-only "staged/waiting" state** (R32, v0.24.0). Workers auto-claim from queue; idle workers show `Idle (no claimable task)` + King keeps polling. Only co-workers wait, and only for explicit `pair on co-worker-N`. Watchmen always run `/loop`.

17. **King reads existing task state BEFORE dispatching new tasks** (R33, v0.25.0). At session start AND every Step 4 dispatch round, King scans `.kingdom/<project>/tasks/*.md` newest-first, builds resume queue (in-flight, no sentinel) and decision queue (blocked). Resume takes priority. NEVER open a fresh task file for a lane with an in-flight one.

18. **Tier-1 rules override memory/feedback notes** (R34, v0.26.0). `MEMORY.md` and `feedback_*.md` are advisory context, NOT authoritative protocol. When a memory note conflicts with a Tier-1 rule, the rule wins. Self-detect protocol: STOP → factual acknowledgment in chat → repair → log `RULE_VIOLATION R<N>` to `master_agent.log` → no dependent work before repair.

19. **King never copies uncommitted changes between worktrees** (R35, v0.26.0). Each `.worktrees/<lane>/` is the exclusive work surface for that lane. Banned: `cp .worktrees/worker-1/file .worktrees/worker-2/file` + commit on worker-2. Cross-worktree read for context is allowed; `git diff <lane> | git apply` onto kingdom overlay only.

20. **Visible workspace progress within ~10s of `/kingdom:work`** (R36, v0.28.0). King renames its own workspace to `👑 King · <project>` within ~1s; ALL lane workspaces from `kingdom.json.shape` spawn in parallel before any audit/dispatch starts; `spawn-complete` card renders before processing. No "crunched for 30s while sidebar looks dead."

21. **Heavy processing runs IN lane workspaces, not King's session** (R37, v0.28.0). Audit fan-outs, pattern-grep scans, doc-digest fan-outs dispatch to lanes via `cmux send`. King's main session: read state, render cards, make dispatch decisions only. Lanes are parallel compute; use them.

22. **Sub-agent spawns are tabs or lane dispatch — never in-process Agent()** (R38, v0.28.0). Allowed: `cmux tab-action --action new-terminal-right` (visible tab, auto-closes on sentinel) OR `cmux send --workspace worker-N`. Banned: `Agent(subagent_type="general-purpose", ...)` in King's main session. The cmux "1 local agent · ctrl+t to hide tasks" bottom-pane indicator is an R38 violation signal.

23. **Watchman is fully autonomous within its duty list** (R39, v0.29.0). Watchman does not pause for King approval on low-risk fixes (stale checkbox ticks, log-line backfills, dead-link repairs). High-risk changes (digest rewrites, task-file merges) are still flagged to King. Autonomous scope defined in `watchman.md` → "Duty list" and enforced by `/kingdom:work` watchman spawn.

24. **Haiku cap per watchman tick** (R40, v0.29.0). Each watchman tick may spawn at most `kingdom.json.watchman.haikuCapPerTick` Haiku sub-agents (default 5, max 10). Prevents runaway fan-out on large repos with many open PRs. Configurable per project in `kingdom.json`; King may override for a single session by editing `state.json` before the tick fires.

25. **Auto-discover and use the right skill BEFORE any work** (R41, v0.29.3). At task receipt, every actor (King or lane) resolves a skill set via 3-step priority: (1) fast path — run `pick_skills_for_task` against `skill-routing.md` keyword table; (2) fallback — scan the system-reminder skill list and match by description; (3) no-skill is valid — skip rather than load a vaguely-related skill. A 12-row domain→skill quick map covers the main domains (frontend, prisma, supabase, stripe, figma, plugin-dev, file formats, claude api, hugging face, security, code review, git workflow); a separate 10-skill process map covers King-side planning skills (brainstorming, writing-plans, TDD, systematic-debugging, etc). Skills are resolved per-task, not per-lane.

26. **Every parallel fan-out uses `_bounded_wait`, never bare `wait`** (R42, v0.30.0). Bare `wait` blocks until every backgrounded subshell exits — if one stalls (`git worktree add` blocked on `.git/index.lock`, `gh pr view` on stale network, `cmux send` to not-yet-ready workspace), the parent script hangs forever and the Claude Code harness auto-pushes the bash call to background. User sees "Job's output is empty and files weren't written." Diagnosed via live cmux audit (2026-05-20): every cmux command itself returns in <0.65s; the perceived hangs across v0.27-v0.29.4 were all downstream subshells. Spec: collect PIDs (`PIDS="$PIDS $!"`), pass to `_bounded_wait <budget> $PIDS`, helper `kill -9`'s survivors and returns 124 on timeout. Helper is pure-bash + portable (macOS lacks GNU `timeout` and `gtimeout`). Default budgets: 5s cosmetic cmux fan-outs, 15s teardown, 45s `parallel_edit_fanout`, 60s lane spawn cycle. Five call sites converted: `commands/work.md` ×2 (King rename + lane spawn), `commands/save.md`, `watchman.md` PR-backfill, `_primitives.md` `parallel_edit_fanout` self.

27. **Hard gates beat prose; Tier 1 capped at 10** (v0.31.0). Prior versions encoded critical rules as prose in `rules.md` with anti-pattern callouts and "why Tier 1" justifications. The 2026-05-20 morning consumer session showed this has a ceiling: a King operating in real-time chat will pattern-match the surface shape of the task and not re-read 700 lines of `rules.md` between Bash calls. v0.31.0 picks a different lane — keep the rules as documentation, but make load-bearing rules call-site blocks. Five new helpers in `_primitives.md § Hard gates` BLOCK violations: `guard_worker_commit_branch` (R4+R9), `guard_lane_workspace_exists` (R31+R36), `guard_no_king_session_worktree_cd` (R30+R37), `kingdom_overlay_lane` (R15 — correct overlay flow), `spawn_watchman_loop` (R39 — auto-`/loop`). Same release caps Tier 1 at exactly 10 rules (R1, R2, R4, R5, R14, R22, R30, R31, R36, R42) — Tier 1 should mean "violation = kingdom worse than running solo," not "important enough to add a tier marker." 29 prior Tier-1 markers demoted to Tier 2 via a legend at the top of `rules.md` (per-rule heading sweep deferred). Adds R43 (closing actions agent-owned; no "Ter's hand" in briefs) and R44 (after `go`, King executes — no execute-mode follow-up) as Tier 2.

28. **Story pods: Senior role + story integration branch + three-tier gate** (v0.32.0). Multiple workers attack one unit (story/milestone/issue, `kingdom.json.integration.unit`) in parallel, get reviewed as a whole, and ship as one PR. A new **Senior-N** (Opus, `senior.md`) is a per-story sub-orchestrator and the SOLE within-story reviewer: it owns a worker pod, merges their `worker-N` tips into a local `story/<id>` branch (real merge commits, R46), runs Tier-2 on the story branch, runs an autonomous review loop (route fixes back to the owning worker, re-review, cap `integration.reviewLoopCap`, R48), then marks the story push-eligible. The King delegates per-story orchestration (R30 amended: King + Seniors dispatch; Seniors in-pod + visible only via `guard_senior_dispatch_scope`) and owns ONLY cross-story coordination (partition scopes, sequence dependencies, resolve drift at push, fed by the watchman's `crossStoryScan` duty, R50). Quality + speed via specialization: review never happens twice on the same code (Senior owns within-story depth, King owns cross-story breadth), and the only serial bottleneck is the human push. Gate is three-tier (R47): worker Tier-1 -> story Tier-2 -> Senior review -> human push. Story branch stays local; only the final `story/<id> -> develop` PR reaches origin (solo `worker -> feature/<topic>` path retained for one-worker tasks). Adds R46-R50. Design spec: `docs/superpowers/specs/2026-05-23-senior-story-pods-design.md`.

## Working conventions for THIS repo

- **English only in chat** (per memory rule `feedback_communication`).
- **No hardcoded "Ter"** in public-facing template content. Use `${USER_NAME}` (configurable via `kingdom.json.welcome.userName`, empty default) in cards, or generic "the user" in prose.
- **No source-project attribution** in commits / PR bodies / in-repo docs. Don't name `AssayGrid`, `pull/SWT-Fontend`, `bfg-swt`, etc. when discussing the kingdom plugin itself. Frame imported patterns as "templates" or "examples."
- **No personal notes (`TER.md`, `TER_*.md`) referenced in repo docs.** Those live in the user's private workspace, not in the plugin.
- **Mockup file names should be generic.** Replace bfg-swt-specific paths (`apps/swt-frontend/apps/webshop/...`) with `src/app/shop/...` in examples.
- **Em-dashes are OK but not as a stylistic AI-tic.** Prefer commas/colons/periods for sentence-internal separation; use em-dash only for parenthetical asides.

### Git workflow for this repo

- **Branch:** `main` only. No develop / feature workflow. The kingdom plugin itself is shipped per-release directly on `main`.
- **Commit message format:** `<type>: v<version> — <theme>` followed by a bullet-point body. Examples in `git log`.
- **Push gate (R1 applies here too):** never push without the user's explicit `push` word. Even though this is the kingdom repo itself, the rule holds. Confirmation pattern: stage → commit → wait → push only on go-ahead.
- **No force-push on main, ever.**
- **Version bumps:** `plugin.json`, `marketplace.json`, `README.md` badge, `CHANGELOG.md` — all four together. Don't split.

## Open threads (things to pick up next session)

~~1. **`/kingdom:self-care` should detect workspace-stale files.**~~ — **CLOSED in v0.30.0** (Check 9: scans plugin's `.kingdom/.setting/` vs workspace, prompts for one-keystroke import, routes through existing partial-pass card).

~~2. **`parallel_edit_fanout` helper.**~~ — **CLOSED in v0.30.0** (body landed in `_primitives.md`; `watchman.md` PR-number backfill rewired to call it).

~~3. **Wire `kingdom_resync_after_merge` call site into `king.md` Step 7.**~~ — **CLOSED in v0.30.0** (Step 7 now calls the helper; behavioural fix — worker worktree preserved per R35 instead of destroy+recreate).

~~7. **Wire the v0.31.0 hard-gate helpers into the role docs.**~~ — **CLOSED in v0.31.0** (same release as the helpers). Wires landed: `commands/work.md` Step 0.4 chains `spawn_watchman_loop` after `spawn_master_workspace` for watchman lanes; `commands/work.md` Step 4 (resume + new dispatch) calls `guard_lane_workspace_exists` before each `cmux send`; `king.md` § Parallel duplicate dispatch and § Primary cmux send both call `guard_lane_workspace_exists`; `king.md` § Overlay loop replaces inline `git diff \| git apply` with `kingdom_overlay_lane` (R4-guarded); `worker.md` adds a new "Pre-closer: the task commit" section mandating `guard_worker_commit_branch` before any lane `git commit`. Explicitly skipped: `watchman.md` PR-backfill (R27 exception to R9 — watchman is allowed to amend `feature/*`); `commands/save.md` teardown (no commit/dispatch/cd to guard); orphan-tab sweep (only `cmux tab-action`, no guard target).

8. **`guard_no_king_session_worktree_cd` exists but isn't yet wired** — the helper is defined in `_primitives.md` but no role doc currently calls it. The natural insertion point is the `king.md` overlay/audit flow that historically `cd`'d into worker worktrees. v0.30.0+ refactored most of those to `git -C "$WT"` form (which doesn't change cwd, so the guard doesn't apply). Pending: a sweep to add the guard at the few remaining `cd "$PROJ/.worktrees/...` sites in `king.md` (line ~120, ~747) for defence in depth.

8. **Per-rule heading sweep for the Tier 1 cap** — `rules.md` v0.31.0 has the Tier-1-cap legend at the top declaring exactly 10 iron-clad rules, but the per-rule headings (e.g. `### R33. King MUST read existing task state — Tier 1`) still carry their old `— Tier 1` suffix. The legend is authoritative for now, but a sweep should update each demoted rule's heading suffix to `— Tier 2`. Mechanical edit across ~19 rules.

9. **R45 candidate — pre-commit hook installed by `/kingdom:init`** — install `guard_worker_commit_branch` as a real `.git/hooks/pre-commit` in each lane worktree at `/kingdom:init` time. The helper guards the action only if the calling script chooses to call it; a real pre-commit hook catches the failure mode even if the script forgets. Deferred to v0.31.1 pending consumer test of the v0.31.0 helpers first.

10. **R34 hardening — session-start memory-vs-Tier-1 conflict scan** — today R34 says "rules win when memory and rules conflict" but the King session must self-detect conflicts; no automatic scan. Design needed for what the scan output looks like in chat (and how the King reads it without becoming a turn-eater).

11. **Stale `cmux send` / `cmux notify` / `cmux tree` references** — grep across plugin source shows 11+11+4 hits. Live cmux 0.64.6+ accepts these as undocumented subcommands but `cmux capabilities` lists the RPC methods (`surface.send_text`, `notification.create_for_target`, etc.) as the documented surface. Audit + standardize in v0.32.0.

4. **Companion app discussion (open)** — user asked about forking ghostty / building a richer UI vs sticking with cmux.app cards. Two paths explored:
   - **(a)** Thin web dashboard reading kingdom's audit files (`master_agent.log`, sentinel flags, task files, `watchman_state.json`). Ships in days, read-mostly, chat stays in cmux.app.
   - **(b)** Upstream PRs to cmux.app for richer notifications + workspace previews + inline diff. Slower but keeps everything in one app.
   - Forking ghostty was discussed and rejected (ghostty's mission is terminal speed, not agent UX).
   - No decision made yet; user said "what you think." Did NOT fire as a sub-project.

5. **`/kingdom:save` parallel teardown** (v0.19.0, now `/kingdom:save` as of v0.29.0) wasn't actually retested after the fix. The `close-workspace` bug fix is documented in CHANGELOG but a real-world `/kingdom:save` cycle should be observed to confirm the parallel `&` + `wait` pattern works as written.

6. **bfg-swt PRs still open** (as of last work session, 2026-05-18 evening):
   - PR #255 — `chore(roadmap): BE-P1-EMAIL provider = Tencent SES`
   - PR #257 — `feat(swt-frontend): per-app SEO metadata + close FE-P0-FOUND.7`
   - PR #258 — `feat(webshop): middleware refresh-on-expiry + close FE-P0-FOUND.8`
   - PR #259 — `docs(webshop): REST-only data access note + close FE-P0-FOUND.9`
   - All waiting on `@eruditus-vir` (lead) merge. When merged, R26 resync fires (per lane).

## How to pick up work next session

1. **Read `rules.md` first** (per R14). Then this CLAUDE.md. Then the role docs for the area you're working in.
2. Check `git log --oneline -10` to see what landed since you last had context.
3. Look at the "Open threads" list above for natural next-step candidates.
4. If user says `/kingdom:work` on this repo: there's no real lane setup for the plugin repo itself; the plugin scaffold is for *consumer* projects. The plugin repo is developed traditionally (single-branch `main`, no lanes, no kingdom overlay).

## What NOT to do

- Don't add Ter-specific content to public template files. The plugin is `github.com/chatthong/kingdom`, public.
- Don't `git push` without explicit user confirmation. Even if a previous push in the same session was approved, R1 is single-shot + PR-specific.
- Don't reuse cmux.app's `tab-action close-others` to close a workspace; the canonical command is `cmux close-workspace --workspace <ref>` (documented as a banned pattern in `.kingdom/.setting/reference/cmux.md` § Teardown).
- Don't commit on a `kingdom` branch (R4). The plugin repo doesn't have one, but if you're testing the plugin in a consumer workspace, never commit there.
- Don't introduce ANSI escape codes in cards (they print literal in Claude Code chat). Use GitHub alerts + emoji + box-drawing instead.
- Don't add `parallel_edit_fanout` as a stub-only — if you add it, write the body too.

## Pointers for unfamiliar areas

- **cmux command reference:** `.kingdom/.setting/reference/cmux.md` (`cmux new-workspace`, `cmux tab-action`, `cmux send`, `cmux notify`, etc).
- **Branch model + lifecycle:** `docs/branch-model.md`.
- **Card library structure:** `.kingdom/.setting/cards/README.md`.
- **Skill routing table:** `.kingdom/.setting/reference/skill-routing.md`.
- **The 50 rules:** `.kingdom/.setting/rules/` (one per file + `index.md` registry). Tier 1 = iron-clad (10, capped — see legend); Tier 2 = strong defaults (35); Tier 3 = conventions (5).
- **Helper bash:** `.kingdom/.setting/functions/` (one helper per file + `index.md` + `_load.sh`). `manifest.json` groups them into features.

---

*Last updated: 2026-05-24 after v0.33.0 ship (command-surface cleanup). Update this file when shipping a release that changes architectural decisions (1-28 above), adds new directories under `.kingdom/.setting/`, or shifts the open-threads list materially.*
