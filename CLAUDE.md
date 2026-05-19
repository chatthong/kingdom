# CLAUDE.md — claude-kingdom plugin repo

This file orients future Claude sessions to the project so work can continue across conversations.

## What this repo is

`claude-kingdom` (published as the **kingdom** Claude Code plugin at `github.com/chatthong/kingdom`). A multi-agent orchestration kit: one King (Opus) coordinates N workers / co-workers / watchmen, each in its own `git worktree` on its own local-only branch, dispatched via cmux.app (primary) or raw tmux (fallback) or headless `claude -p` (last resort).

**The plugin is shape-only**: it ships role specs, slash commands, card templates, and helper bash. It does NOT bundle a runtime. The kingdom runs entirely on Claude Code + git worktrees + cmux/tmux/jq/gh — all standard dev tooling.

**Domain-agnostic by design.** Workers are generic capacity; `gate.*` commands are arbitrary bash. Same kit works for code, research, finance models, manuscripts, anything you version with git.

## Current state — v0.29.0 (2026-05-19)

The plugin is on `main` at commit `cbb677e`. Pushed to `origin/main` at `github.com/chatthong/kingdom`. All releases since v0.18.0 ship per-release; no separate release branch.

Recent version history (worth reading the CHANGELOG for full detail):

| Version | Theme | What landed |
|---|---|---|
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
| 0.19.1 | R29 post-push overlay-discard | After-push overlay-discard is now an enforceable Tier-2 rule (was a Step 8 buried in `kings.md`) |
| 0.19.0 | Priority-tiered rules + post-merge automation | `rules.md` (R1-R28), `_primitives.md`, R26 (post-merge kingdom resync), R27 (watchman PR-number backfill), R28 (parallel by default); bash-trim consolidation; `commands/exit.md` `close-workspace` bug fix + parallelisation |
| 0.18.x | Magic + fast | `/kingdom:day` introduced; pre-warmed sub-agent pool; auto-generated PR bodies |
| 0.17.x | Working-tree overlay model | `kingdom` branch never commits; `git apply --3way` overlay for review; feature-branch byte-for-byte from worker-N tip |

## Directory layout

```
.claude-plugin/
  plugin.json              # name=kingdom, version=0.29.0
  marketplace.json         # registry entry

commands/                  # 4 slash commands
  work.md                  # THE daily ritual (audit + spawn + kickoff + poll + push gates)
  save.md                  # state snapshot (lane + task state → state.json; no commits/pushes)
  init.md                  # workspace + project scaffolding
  self-care.md             # prereq checker

.kingdom/.setting/         # role docs + helpers + cards + routing (canonical source — copied into workspace by /kingdom:init)
  index.md                 # entry-point router
  rules.md                 # 40 enforceable rules (R1-R40), Tier 1/2/3
  _primitives.md           # shared bash helpers (cmux_*, kingdom_*, render_card, pick_skills_for_task, etc)
  kings.md / workers.md / co-workers.md / watchmans.md / git.md / cmux.md   # role specs
  cards/                   # 21 display templates (welcome, daily-status, task-complete, resume-queue, what-to-work-on, etc) + README
  skill-routing.md         # keyword → skill mapping (v0.23.0+)

docs/                      # 8 long-form topic docs (split from README in v0.21.0)
  branch-model.md  cmux-integration.md  configuration.md  work-cycle.md
  faq.md  how-it-works.md  roles.md  why.md

README.md                  # slim landing page (210 lines)
CHANGELOG.md               # Keep-a-Changelog format; entries from v0.5.0 onward
```

## Key architectural decisions — 24 total (don't re-debate without reading the rationale)

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

13. **Per-task skill routing** (v0.23.0). King runs `pick_skills_for_task` per dispatch, picks up to 3 from `.kingdom/.setting/skill-routing.md` keyword table, embeds in dispatch-brief. Skills are NOT lane-permanent; each task re-picks.

14. **King is orchestrator-only — never executes task work** (R30, v0.24.0). Allowed verbs: plan, dispatch, gate-fire, overlay, request push approval, read audits. BANNED: write code, draft multi-batch execution tables in chat, run gates manually for a lane. Hard 60s budget from Step 4 reaching auto-dispatch to first `cmux send`.

15. **Lane-readiness gate before every dispatch** (R31, v0.24.0). `workspace-refs.env` must list every lane; `cmux tree --all` must show them alive. Universal "lanes exist" signal is `.worktrees/<lane>/` directories (mode-agnostic). If worktrees exist but cmux refs are missing, fall to AGENT mode rather than re-spawning. No dispatch fires until lanes confirmed.

16. **Co-worker-only "staged/waiting" state** (R32, v0.24.0). Workers auto-claim from queue; idle workers show `Idle (no claimable task)` + King keeps polling. Only co-workers wait, and only for explicit `pair on co-worker-N`. Watchmen always run `/loop`.

17. **King reads existing task state BEFORE dispatching new tasks** (R33, v0.25.0). At session start AND every Step 4 dispatch round, King scans `.kingdom/<project>/tasks/*.md` newest-first, builds resume queue (in-flight, no sentinel) and decision queue (blocked). Resume takes priority. NEVER open a fresh task file for a lane with an in-flight one.

18. **Tier-1 rules override memory/feedback notes** (R34, v0.26.0). `MEMORY.md` and `feedback_*.md` are advisory context, NOT authoritative protocol. When a memory note conflicts with a Tier-1 rule, the rule wins. Self-detect protocol: STOP → factual acknowledgment in chat → repair → log `RULE_VIOLATION R<N>` to `master_agent.log` → no dependent work before repair.

19. **King never copies uncommitted changes between worktrees** (R35, v0.26.0). Each `.worktrees/<lane>/` is the exclusive work surface for that lane. Banned: `cp .worktrees/worker-1/file .worktrees/worker-2/file` + commit on worker-2. Cross-worktree read for context is allowed; `git diff <lane> | git apply` onto kingdom overlay only.

20. **Visible workspace progress within ~10s of `/kingdom:work`** (R36, v0.28.0). King renames its own workspace to `👑 King · <project>` within ~1s; ALL lane workspaces from `kingdom.json.shape` spawn in parallel before any audit/dispatch starts; `spawn-complete` card renders before processing. No "crunched for 30s while sidebar looks dead."

21. **Heavy processing runs IN lane workspaces, not King's session** (R37, v0.28.0). Audit fan-outs, pattern-grep scans, doc-digest fan-outs dispatch to lanes via `cmux send`. King's main session: read state, render cards, make dispatch decisions only. Lanes are parallel compute; use them.

22. **Sub-agent spawns are tabs or lane dispatch — never in-process Agent()** (R38, v0.28.0). Allowed: `cmux tab-action --action new-terminal-right` (visible tab, auto-closes on sentinel) OR `cmux send --workspace worker-N`. Banned: `Agent(subagent_type="general-purpose", ...)` in King's main session. The cmux "1 local agent · ctrl+t to hide tasks" bottom-pane indicator is an R38 violation signal.

23. **Watchman is fully autonomous within its duty list** (R39, v0.29.0). Watchman does not pause for King approval on low-risk fixes (stale checkbox ticks, log-line backfills, dead-link repairs). High-risk changes (digest rewrites, task-file merges) are still flagged to King. Autonomous scope defined in `watchmans.md` → "Duty list" and enforced by `/kingdom:work` watchman spawn.

24. **Haiku cap per watchman tick** (R40, v0.29.0). Each watchman tick may spawn at most `kingdom.json.watchman.haikuCapPerTick` Haiku sub-agents (default 5, max 10). Prevents runaway fan-out on large repos with many open PRs. Configurable per project in `kingdom.json`; King may override for a single session by editing `state.json` before the tick fires.

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

1. **`/kingdom:self-care` should detect workspace-stale files.** v0.22 introduced `cards/`, v0.23 added `skill-routing.md`. Both require `/kingdom:init` re-run to land in the workspace. Self-care doesn't currently flag the gap. Spec: scan `.kingdom/.setting/` for files referenced by current plugin version that don't exist in workspace; render `doctor-report` `partial-pass` variant with auto-fix offer. Mentioned as v0.23.1 candidate.

2. **`parallel_edit_fanout` helper** is referenced by R28 but spec-only (body unwritten). Needed for the parallel branch-amend pattern described in R27 (PR-number backfill).

3. **Wire `kingdom_resync_after_merge` call site** into `kings.md` § Push approval gate Step 7. Helper exists in `_primitives.md` (R26); the role-doc Step 7 still inlines the old per-lane cleanup pattern.

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
- Don't reuse cmux.app's `tab-action close-others` to close a workspace; the canonical command is `cmux close-workspace --workspace <ref>` (documented as a banned pattern in `.kingdom/.setting/cmux.md` § Teardown).
- Don't commit on a `kingdom` branch (R4). The plugin repo doesn't have one, but if you're testing the plugin in a consumer workspace, never commit there.
- Don't introduce ANSI escape codes in cards (they print literal in Claude Code chat). Use GitHub alerts + emoji + box-drawing instead.
- Don't add `parallel_edit_fanout` as a stub-only — if you add it, write the body too.

## Pointers for unfamiliar areas

- **cmux command reference:** `.kingdom/.setting/cmux.md` (`cmux new-workspace`, `cmux tab-action`, `cmux send`, `cmux notify`, etc).
- **Branch model + lifecycle:** `docs/branch-model.md`.
- **Card library structure:** `.kingdom/.setting/cards/README.md`.
- **Skill routing table:** `.kingdom/.setting/skill-routing.md`.
- **The 40 rules:** `.kingdom/.setting/rules.md`. Tier 1 = iron-clad (18); Tier 2 = strong defaults (17); Tier 3 = conventions (5).
- **Helper bash:** `.kingdom/.setting/_primitives.md`. Every role doc points here for shared functions.

---

*Last updated: 2026-05-19 after v0.29.0 ship. Update this file when shipping a release that changes architectural decisions (1-24 above), adds new directories under `.kingdom/.setting/`, or shifts the open-threads list materially.*
