# Changelog

All notable changes to `kingdom` (formerly `claude-kingdom`) are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

---

## [0.26.0] — 2026-05-19

**Two more gaps caught by another incident.** Same afternoon (2026-05-19), a King session: (a) read `feedback_kingdom_cmux_dispatch_fallback.md` from auto-memory and interpreted it as "skip cmux spawn this session entirely" — conflating a dispatch-time pivot with a spawn-time exemption; (b) authored Dockerfile changes on worker-1's worktree, `cp`'d the file to `.worktrees/worker-2/`, and committed it on worker-2's branch as "part of the slice." Two more Tier-1 rules added.

### Added

- **R34 (Tier 1) Tier-1 rules override memory notes.** `MEMORY.md` and `feedback_*.md` files are advisory context, NOT authoritative protocol. When a memory note suggests behaviour that contradicts a Tier-1 rule, the rule wins. Includes a contradiction table covering the cmux-fallback memory vs R31 spawn rule, performative-apology memory vs R30 self-acknowledgement, solo-by-default memory vs R31 multi-lane ritual.
- **R35 (Tier 1) King never copies uncommitted changes between worktrees.** Each lane's `.worktrees/<lane>/` is its own work surface. Allowed cross-worktree ops: read for context; `git diff <lane> | git apply` onto kingdom (overlay only, never commits). BANNED: `cp .worktrees/worker-1/file .worktrees/worker-2/file` followed by `git commit` on worker-2. Reason: King committing into a lane's branch breaks the per-lane authorship invariant that the entire audit trail depends on. Correct alternative: dispatch a brief to worker-2 so worker-2 authors the change in its own worktree.
- **"Self-detect" protocol** (paragraph at end of rules.md, applies to all Tier-1 violations). When King catches its own Tier-1 violation mid-session: STOP, acknowledge factually in chat, repair (re-run the violated step correctly), log `[UTC] RULE_VIOLATION R<N> · <description> · repaired by <action>` to `master_agent.log`, never continue dependent work without repair.

### Incident summary (2026-05-19 afternoon, second incident)

Same bfg-swt King session, after the morning's "0 jobs" issue was supposedly addressed:

1. **WTF 1 — cmux workspaces never spawned.** King read `feedback_kingdom_cmux_dispatch_fallback.md` at session start and skipped `/kingdom:start`'s cmux spawn step. The memory note covers a dispatch-time fallback (cmux send fails → pivot to Agent()), NOT a session-start excuse to skip spawning. King self-acknowledged: "I read that as 'skip cmux spawn this session too.' That was wrong." R34 closes this by ranking Tier-1 rules above memory notes.

2. **WTF 2 — Dockerfile cross-worktree commit.** King authored 3 build-env placeholder ENV lines + 4-line comment on worker-1's Dockerfile, then `cp`'d the file to `.worktrees/worker-2/` and committed it on worker-2's branch as part of "the @workspace/db enabling slice." King's defence: "the modification was already in your worker-1 worktree when I scanned." Still a violation — King did the cross-worktree copy + commit. R35 closes this; correct move is dispatch a brief to worker-2 so it authors the change in its own worktree.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.26.0`.

### Apply on consumer side

Re-run `/kingdom:init` (workspace-only) to sync `rules.md` (R34 + R35 + self-detect protocol added) into the workspace copy. Then next `/kingdom:day` invocation pre-loads the new rules at R14 session-start read.

### Cumulative rules count

| Tier | Count | IDs |
|---|---|---|
| Tier 1 (IRON-CLAD) | 13 | R1-R7, R22, R23, R30, R31, R33, R34, R35 |
| Tier 2 (STRONG DEFAULTS) | 16 | R8-R16, R24-R29, R32 |
| Tier 3 (CONVENTIONS) | 5 | R17-R21 |

---

## [0.25.0] — 2026-05-19

**Critical fix: King now actually seeks existing job state at session start.** v0.24.0 added R31 to verify lanes are spawned before dispatch, but the check was cmux-centric and missed two cases: (a) AGENT-mode fallback where `.worktrees/` is the real "lanes exist" signal, and (b) **King not reading `.kingdom/<project>/tasks/` at all before deciding what to dispatch** — leading to fresh task files opened on top of in-flight ones.

### Added

- **R33 (Tier 1) King MUST read existing task state BEFORE dispatching new tasks.** At session start AND every `/kingdom:day` Step 4 dispatch round, King scans `.kingdom/<project>/tasks/*.md` newest-first, classifies each by Status + sentinel presence, builds a **resume queue** (in-flight, no sentinel) and a **decision queue** (blocked, awaiting user input). Resume takes priority over new dispatch. NEVER open a fresh task file for a lane that already has an in-flight one.
- **R31 expanded — three-mode-aware** (PRIMARY=cmux / FALLBACK=tmux / AGENT=in-process). Universal "lanes exist" check is `.worktrees/<lane>/` directories. Mode-specific dispatch mechanism verified ON TOP (cmux refs OR tmux session OR nothing extra for AGENT). If worktrees exist but PRIMARY verification fails, fall back to AGENT mode instead of re-spawning cmux workspaces. Prevents wasted re-spawn attempts when prior session left worktrees alive.
- **`/kingdom:day` Step 0.5 rewritten** for mode awareness. `.worktrees/` check first (universal), then mode detection (PRIMARY → FALLBACK → AGENT), then mode-appropriate spawn-complete card render.
- **`/kingdom:day` Step 0.6 — Resume scan** (new mandatory step BETWEEN Step 0.5 lane-readiness and Step 1 audit). Scans task files, builds resume + decision queues, renders new `resume-queue` card if either has items.
- **`cards/resume-queue.md`** (new, 20th card) — `[!IMPORTANT]` flavour, renders in-flight tasks + blocked tasks, prompts user for `resume all` / `resume <lane>` / `unblock <task-id>` / `cancel <task-id>` / `go`.

### Incident summary (2026-05-19 afternoon)

User ran `/kingdom:day bfg-swt`. Symptoms:
1. King ran R31 check, saw `workspace-refs.env` missing, said "lanes not spawned" — but `.worktrees/worker-1` through `.worktrees/watchman-1` all existed (from prior PRIMARY session). King didn't check worktrees, only cmux refs.
2. King considered spawning 5 fresh cmux workspaces, ran ~5 minutes of investigation, eventually printed a manual kickoff brief in chat instead.
3. King's "Suggested next tasks" pulled candidates from project TODO ledger while ignoring the worker-1 task file from morning marked `discovery-complete` with 2 soft blockers needing user input.
4. User: "it not event seek for kingdom latest job ... scan on current branch we start work for 3 brach already, recheck at task ... i want continue work 3 worker."

Root cause: R31 was cmux-centric (missed worktree truth in AGENT-mode); no rule required reading task state before dispatch (R33 closes this).

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.25.0`.

### Apply on consumer side

Re-run `/kingdom:init` (workspace-only) to sync new `rules.md` (R31 expanded + R33 added) and the new `cards/resume-queue.md` into the workspace copy.

---

## [0.24.0] — 2026-05-19

**Critical fix: King is dispatcher, not executor.** A King session spent ~1m48s drafting a 9-batch "Worker-1 plan (final)" execution table in chat — scope decisions, file lists, AC flip targets, verification steps — instead of dispatching to worker-1. Lane workspaces had never been spawned. Zero tasks completed in the session. This release codifies three Tier-1 rules + adds a pre-dispatch lane-readiness gate to prevent recurrence.

### Added

- **R30 (Tier 1) King is ORCHESTRATOR ONLY — never executes task work itself.** Allowed verbs: plan-the-day, dispatch (`cmux send`), gate-fire, overlay onto kingdom, request push approval, read audits. BANNED: write code, make scoping decisions in chat, draft "Batch 1..N" execution plans in chat, run gates manually for a lane. **Hard 60s time budget** from `/kingdom:day` Step 4 reaching auto-dispatch to first `cmux send` firing.
- **R31 (Tier 1) Lane workspaces MUST be spawned + verified BEFORE any dispatch.** `workspace-refs.env` must list every lane from `kingdom.json.shape`. `cmux tree --all` must show them alive. If missing, spawn first (idempotent). Render `spawn-complete` card BEFORE dispatch begins so the user visually confirms the sidebar shape. Prevents silent-failure pattern where King dispatches to non-existent workspace refs and polls forever.
- **R32 (Tier 2) "Staged / waiting / dormant" is co-worker-ONLY.** Workers auto-claim from queue (per `kings.md` § Lane utilisation). If queue empty, lane shows `🐾 Idle (no claimable task)` but King keeps polling. Workers NEVER sit "awaiting your dictation" — only co-workers wait, only for explicit `pair on co-worker-N`. Watchmen always run `/loop`, never idle/waiting.
- **`/kingdom:day` Step 0.5 — Lane-readiness gate.** New mandatory step BETWEEN Step 0 (parse args) and Step 1 (audit). Verifies every expected lane is listed in `workspace-refs.env` AND alive in `cmux tree --all`. Forces a `/kingdom:start` re-run if any lane is missing or stale. No dispatch fires until lanes are confirmed.
- **`/kingdom:day` Step 4 — R30 budget enforcement.** Explicit `DISPATCH_START` timestamp; warns at 60s elapsed without first `cmux send`. Anti-pattern call-outs in step 4 prose: no multi-batch tables in chat, no "waiting for direction" for workers.

### Incident summary (2026-05-19 morning)

User's day: zero tasks completed. Symptoms:
1. King chat history showed "Worker-1 plan (final)" 9-row markdown table with scope decisions ("Admin dropped from FE-P0-FOUND.5") + file-by-file changes + verification steps. That's worker work, not King work.
2. Screenshot showed ONE cmux pane (King only). No worker / co-worker / watchman workspace tabs in the sidebar.
3. King displayed `co-worker-1 staged · awaiting your dictation` AND treated worker-1 as if it was waiting too. User: "WTF for waiting i said that for co-working but you waiting for wtf is that shit."
4. King had been "Crunched for 1m 48s · 1 local agent still running" — local agent was King's own planning, no real lane work.

Root cause: previous rules said WHAT King does (`kings.md` § Dispatch) but didn't HARD-BAN King from executing work itself. R30/R31/R32 close those gaps as Tier-1/2 rules.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.24.0`.

### Companion file

- **`CLAUDE.md` (new at repo root)** — orients future Claude sessions to project state, recent version history, 13 key architectural decisions, working conventions, open threads, and pointers. Read this on every fresh session BEFORE touching the plugin.

---

## [0.23.0] — 2026-05-19

Per-task skill routing. King now picks up to 3 Claude Code skills per dispatch from a keyword mapping table, and the dispatch-brief carries them into the lane. Skills are **per-task, not per-lane-lifetime**: worker-2 doing a Supabase task gets `supabase:supabase`; the same worker-2 doing a shadcn task tomorrow gets `shadcn:shadcn-ui`. Previous-task skills don't persist (skills are per-invocation via the `Skill` tool anyway).

### Added

- **`.kingdom/.setting/skill-routing.md`** — canonical keyword → skill mapping table (~40 mappings across P1/P2/P3 tiers). Covers Next.js, shadcn, Tailwind, OKLCH, frontend-design; Supabase + Postgres; Stripe; Claude API; PDF/XLSX/PPTX/DOCX/lark-doc; Figma; Hugging Face; plugin-dev (commands/agents/skills/hooks/MCP); CLAUDE.md management; code review; security review; superpowers process skills (brainstorming, writing-plans, TDD, systematic-debugging, verification-before-completion); commit-commands; git worktrees; doc-coauthoring; playground.
- **`pick_skills_for_task` helper** in `_primitives.md` — reads the routing table, greps task brief + AC + linked reference files (lowercase, whole-word, case-insensitive), returns up to 3 matching skills sorted by priority. Returns multi-line text ready for `${SUGGESTED_SKILLS}` substitution in the dispatch-brief.
- **`cards/dispatch-brief.md` updated** — new `Suggested skills` block in the template + `${SUGGESTED_SKILLS}` variable. If empty (no keyword matched), the entire section is dropped from the brief.
- **User override surface** — `worker-2: skill=figma:figma-implement-design pick BE-P0-AUTH.2` short-circuits the matcher with the user's verbatim skill list. `skill=none` clears the list (no skills suggested). Multiple skills comma-separated.

### Changed

- `commands/init.md` Step 2 now copies `skill-routing.md` into the workspace scaffold alongside `cards/`.
- `index.md` doc-index table updated to register `cards/` and `skill-routing.md` (was missing both from the canonical entry-point doc).
- `plugin.json`, `marketplace.json`, README badge — version → `0.23.0`.

### Customisation note

Edit the workspace copy at `.kingdom/.setting/skill-routing.md` (not the plugin source) to add project-specific mappings. Matcher reads the workspace copy at every dispatch, so changes apply on the next task without restarting the King. Common additions: project-specific framework keywords (Vue/Nuxt, Rust), internal DSL reserved words, organisation-specific skills.

---

## [0.22.0] — 2026-05-18

Card library: 17 reusable display templates for everything the kingdom prints to the user. Plus weather card on `/kingdom:day` kickoff, random "task complete" lines from a 20-entry pool, and an explicit task-counting-unit definition that the King echoes back so `cap=N` / `target=N-M/<period>` are unambiguous.

### Added

- `.kingdom/.setting/cards/` directory with 19 card design files (all 6 slash commands now render at least one card):
  - **Kickoff (4 cards):** `welcome.md` (4 time-of-day variants + weather slot), `daily-status.md`, `suggested-task.md`, `dispatch-plan.md`
  - **Mid-day events (6 cards):** `task-complete.md` (20 random congratulatory lines), `push-prompt.md`, `gate-fail.md`, `cap-reached.md`, `blocked-lane.md`, `conflict-detected.md`
  - **End-of-cycle (3 cards):** `end-of-day.md`, `pr-merged.md`, `watchman-alert.md` (4 severity variants)
  - **Lifecycle (2 cards):** `scaffold-success.md`, `spawn-complete.md`
  - **Internal (1 card):** `dispatch-brief.md` (King → lane prompt template)
  - **Standalone-command closers (2 cards):** `audit-summary.md` (renders at end of `/kingdom:update`), `doctor-report.md` (renders at end of `/kingdom:doctor`, 3 variants)
  - **Index:** `cards/README.md` (alert-flavour mapping, width conventions, variable substitution, custom branding)
- Each user-facing card wraps a box-drawn body (`╭─╮│╰╯`) in a GitHub alert (`[!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`) so it renders with a coloured frame in Claude Code chat.
- **Weather card** (`welcome.md`): fetches local weather via ipapi.co (geolocation) + open-meteo (current conditions). Both free, no API key. 3s timeout per call; silent skip on failure. Opt-out via `kingdom.json.welcome.weather = false`.
- **Random task-done lines** (`task-complete.md`): 20-line pool that rotates on each Tier-2 pass. Ring-buffer in `<LOGS>/.last-task-done-line` prevents back-to-back repeats. Pool includes rest-reminder variants ("Did you eat?", "Walking break suggested") fired ~10% of the time so the kingdom feels like a coworker, not a drill sergeant.
- **Task-counting-unit definition** (Step 0.3 of `commands/day.md`): explicit table showing `1 task = 1 task file = 1 sentinel ≈ 1 PR`, with which units count toward `cap=` and `target=` (Story heading ✅, PR ✅; sub-task AC bullet ❌, milestone ❌). The `daily-status` card echoes this definition every kickoff so user knows what they're counting.
- **Helpers in `_primitives.md`:** `fetch_weather_line` (3s timeout, silent on failure, opt-out aware), `random_task_done_line` (ring-buffer rotation), `render_card` (template load + `${VAR}` substitution + drop-on-empty-line).

### Changed

- `commands/day.md` Step 3 (kickoff) rewritten to call `render_card "welcome/${VARIANT}"` + `render_card "daily-status"` + `render_card "suggested-task"` + `render_card "dispatch-plan"` instead of inlining the four box-drawn templates. Step 5 (poll loop) now fires `task-complete` + `push-prompt` cards on Tier-2 pass and `gate-fail` card on failure.
- `commands/init.md` Step 2 now copies `cards/` into the workspace scaffold alongside the role docs. Step 5 renders the `scaffold-success` card (workspace-only OR project variant) instead of the prior plain-text "Kingdom ready" block.
- `commands/start.md` Phase 7 renders the `spawn-complete` card.
- `commands/exit.md` final step renders the `end-of-day` card.
- `commands/update.md` final step renders the `audit-summary` card.
- `commands/doctor.md` final step renders the `doctor-report` card (variant-aware: all-pass / partial-pass / failed).
- **Public-plugin hygiene:** removed all hardcoded `Ter` references from the public-facing template content. Replaced with `${USER_NAME}` variable in `cards/welcome.md` (configurable via `kingdom.json.welcome.userName`; defaults to empty so greeting is just "Good morning" without a name) + generic "user" in `commands/*.md` and `cards/conflict-detected.md` / `cards/dispatch-brief.md`.
- `plugin.json`, `marketplace.json`, README badge — version → `0.22.0`.

### Honest scope note

The card library is a SPEC level rollout. King implementations (existing sessions running v0.21.0) will keep using the inline templates from `commands/day.md` as it was; v0.22.0 King sessions started AFTER plugin update will pick up the `render_card` flow. There's no migration step. If you want immediate visual upgrade in an existing King, restart the King session after `/plugin update kingdom`.

---

## [0.21.0] — 2026-05-18

README slimmed from 739 to ~200 lines; long-form content split into `docs/`. The cmux.app sidebar mockup is now a mermaid diagram (was a code-fence ASCII box). No behavioural changes; all moved content is reachable via the README's `## 📚 Docs` table.

### Added

- `docs/` directory with 8 focused topic files:
  - `docs/daily-ritual.md` — first-time setup, every-day command, `target=`/`cap=` reference, plugin updates
  - `docs/configuration.md` — project shape choices, `/kingdom:init` parameters, `kingdom.json` reference
  - `docs/roles.md` — King + workers + co-workers + watchmen + sub-agents
  - `docs/branch-model.md` — lifecycle mermaid, GitHub Desktop overlay mockup, three rules, what-lives-where, two-tier gate, why-this-design
  - `docs/cmux-integration.md` — cmux.app sidebar mermaid, three notification surfaces, three-tier visual hierarchy, what `/kingdom:start` does
  - `docs/how-it-works.md` — internals, the 4-step closer, task files
  - `docs/why.md` — the problem kingdom solves
  - `docs/faq.md` — common questions
- README "📚 Docs" table linking out to each of the above plus existing role specs.

### Changed

- **README rewritten as a landing page**: badges, value prop, 3-command quick start, agent topology mermaid, "Why kingdom?" 5 bullets, install, contract, roles-at-a-glance, slash commands table, docs map, contributing, license. All deep dives moved to `docs/`.
- **cmux.app sidebar mockup is now a mermaid `graph TB`** (was an ASCII code-fenced box). Same visual intent, but renders as a real diagram on GitHub.
- `plugin.json`, `marketplace.json`, README badge — version → `0.21.0`.

---

## [0.20.0] — 2026-05-18

`/kingdom:day` is promoted to THE daily ritual. Always runs `/kingdom:update` (no >24h skip-gate) + `/kingdom:start` (idempotent) + a richer kickoff brief (local date+time + Suggested next task synthesis) + the auto-gate-poll loop. New argument surface for soft budgets (`target=N-M/<period>` with auto-split across day/week/month) and a hard daily ceiling (`cap=N`). `/kingdom:update` and `/kingdom:start` remain available as standalone building blocks for power users.

### Added

- **`/kingdom:day [project] [target=N-M/<period>] [cap=N]`** as the canonical daily entry point. Argument parsing is forgiving + echoed back in Step 0.2 so the user can correct typos before the loop fires.
- **`target=N-M/<period>` auto-split** — `target=30-50/week` interprets as ~6-10/day (5 working days) and ~120-200/month; `target=5-10/day` interprets as ~25-50/week (5 working days) and ~100-200/month; `target=120-200/month` interprets as ~30-50/week and ~6-10/day. King prints all three views in the kickoff brief.
- **`cap=N` hard daily ceiling** — King stops dispatching after `N` task-completions today; idle lanes wait. Overrides `target` for the day.
- **Local date+time in kickoff brief** — `date '+%A, %B %-d, %Y · %H:%M %Z'` respects the shell's `TZ` so the user sees their actual local time (e.g. `Monday, May 18, 2026 · 18:35 +07`), not UTC.
- **Suggested next task synthesis** — King picks 1-3 candidates from (1) unfinished prior-session task files, (2) lead-requested follow-ups on open PRs, (3) unflipped acceptance criteria in `TODO_*.md` / `TODO_Master.csv` / `STEP.md` matching idle lanes, (4) watchman gap findings, (5) first unstarted heading in the task-ledger. User picks or says "go" to accept the first.

### Changed

- **`/kingdom:day` always runs `/kingdom:update`** at Step 1 — the prior >24h skip-gate is dropped. Audit is cheap relative to acting on stale information.
- **`commands/start.md` + `commands/update.md`** carry a header note marking them as building blocks; `/kingdom:day` is the recommended entry point. Standalone use cases are listed (resume-after-crash for `/kingdom:start`; mid-day re-audit for `/kingdom:update`).
- **README "Quick start" + "Every day" sections** rewritten to lead with `/kingdom:day`. The slash-command table reorders to put `/kingdom:day` first with bold formatting; `/kingdom:start` and `/kingdom:update` are tagged "*(Building block)*".
- `plugin.json`, `marketplace.json`, README badge — version → `0.20.0`.

### Tradeoff

Every `/kingdom:day` invocation eats the audit cost upfront (~1-3 min parallel fan-out) instead of starting in ~10s when the audit is fresh. Worth it if you'd rather not remember audit timing; costly if you `/kingdom:day` multiple times per day. For that workflow, use `/kingdom:start` standalone to skip the audit and drop directly into the poll loop.

---

## [0.19.1] — 2026-05-18

Closing the post-push overlay-discard loophole. The behaviour was already documented in `kings.md` Step 8 and implemented as `kingdom_discard_overlay` in `_primitives.md`, but it wasn't enforced via `rules.md` — so a lane-spawned King session could (and today did) skip it and leave the kingdom branch with stale overlay files after push.

### Added

- **R29 (Tier 2) After every successful push, kingdom MUST be reset to `origin/develop` tip** — `git reset --hard origin/develop` + `git clean -fd` fires immediately after the last `gh pr create` in the batch returns. Distinguished from R26 (post-merge resync, which fires when the lead clicks Merge and advances `origin/develop`). R29 fires per-push (no remote movement); R26 fires per-merge (remote advances).

### Incident summary (motivating R29)

A King session pushed 4 PRs to bfg-swt (#255, #257, #258, #259) successfully, but never ran `kingdom_discard_overlay` after `gh pr create`. Ter opened GitHub Desktop, saw 18 stale uncommitted files on the kingdom branch, and asked "shouldn't kingdom be clean after push?" — yes. `kings.md` Step 8 said so, but `rules.md` didn't, so the sub-King missed it.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.19.1`.

---

## [0.19.0] — 2026-05-18

Priority-tiered rules doc + post-merge automation + parallel-by-default execution model. King's session-start context-read now expanded to a full 0-7 ordered list. Closer mandate + task file lifecycle codified as Tier 1 rules. Post-merge kingdom resync + PR-number backfill move from "King's serial chores" to "watchman's parallel duty."

### Added

- `rules.md` — new canonical priority-tiered rules document King reads FIRST at session start (R0 in R14 read order). 21 → 26 rules across 3 tiers (Tier 1 IRON-CLAD, Tier 2 STRONG DEFAULTS, Tier 3 CONVENTIONS).
- `_primitives.md` — shared bash helpers (`cmux_set_state`, `kingdom_*`, `spawn_pool_slot`, `carve_and_push_feature`, etc.) as a single source of truth referenced by role docs.
- **R14 expanded** — King's session-start read list is now ordered 0-7: `rules.md` → workspace `CLAUDE.md` → project `CLAUDE.md` → project `README.md` → project `docs/` → `MEMORY.md` → personal notes (read-only) → watchman state.
- **R22 (Tier 1) Closer must fire on EVERY task completion** — even on blocked/cancelled/errored exit. Raw → curated → log line → sentinel → (tab) close own tab. No silent exits.
- **R23 (Tier 1) Task file Step 0 mandatory** — `.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md` exists BEFORE any sub-agent dispatch, code edit, or Layer-1 grep. Required schema: Status / Brief / Plan (multi-layer) / Progress notes / Final summary.
- **R24 (Tier 2) Task file continuously updated** — flip checkboxes in place, append progress notes, write Final summary before closer Step 1. Anti-pattern: write at Step 0 + never touch again.
- **R25 (Tier 2) Update BOTH kingdom task file AND project task-ledger** — kingdom file = audit-trail home for King + Ter; project file (TODO_*.md / CSV / STEP.md) = public source for lead + reviewers. Both flip in worker's single task commit.
- **R26 (Tier 2) Post-merge kingdom resync** — when `feature/<topic>` squash-merges to develop, King runs the 7-step resync: detect MERGED → clean overlay → fetch + ff base → reset kingdom → free merged lane → rebase remaining lanes → verify no duplicates → log line. Helper: `kingdom_resync_after_merge`.
- **R27 (Tier 2) Watchman owns PR-number backfill + close-suffix maintenance** — worker commits `(PR #pending)` because PR doesn't exist at commit time. Watchman's `/loop` body fans out parallel `(PR #pending) → (PR #<N>)` flips per-lane in their own worktrees + amends + `--force-with-lease`. Skips already-MERGED PRs (opens `feature/post-<N>-cleanup` instead). Also sweeps stale `.lane` claims after sentinels close.
- **R28 (Tier 2) Parallel by default for scan + non-conflicting edit** — read N files = parallel; edit N different files = parallel; amend + force-push N branches = serial *within* a branch, parallel *across* branches. Serialize only when A mutates B's input, or for "exclusive sensitive" ops (push, hard reset, branch delete, anything touching `keys/` / `.env*`).
- `watchmans.md` — new "PR-number backfill duty" section (under R27); Sonnet watchman now owns this work, not King.
- `cmux.md` — `#notify` anchor in the command index fixed to `#notification-system` (canonical GitHub heading anchor); new "Teardown / close commands" section documenting the canonical `close-workspace` / `close-surface` / `close-window` command family + the three common wrong incantations + the parallel teardown pattern (R28).

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.19.0`.
- **`/kingdom:exit` Step 5 fix** — switched from broken `cmux tab-action --action close --workspace <ref>` (errors `Unknown tab action`) to canonical `cmux close-workspace --workspace <ref>` AND parallelised the 5-lane teardown (each `close-workspace` is now `&`-backgrounded with a single `wait` at the end). Previous serial version took ~5× longer than necessary; the wrong command name also forced King to trial-and-error through `tab-action close-others`, `cmux --help`, etc.
- **Role-doc bash trim** — duplicate helper definitions inlined across `kings.md` (2 blocks) and `workers.md` (4 blocks: 3-helper pool + `cmux_set_state`) now reference `_primitives.md` as the single source of truth. Usage examples remain inline (they show HOW the helper is called for that role); the function bodies move to `_primitives.md`. Approximate trim: `kings.md` 1320 → ~1290 lines, `workers.md` 779 → ~735 lines. Behaviour unchanged — the helper names + signatures are identical.

### Pending for follow-up (not in 0.19.0)

- `parallel_edit_fanout` helper in `_primitives.md` (R28 references it; spec-only for now).
- Wiring the call site for `kingdom_resync_after_merge` into `kings.md` § Push approval gate Step 7 (helper exists in `_primitives.md`; the role-doc Step 7 still inlines the old per-lane cleanup pattern from before R26).

---

## [0.18.1] — 2026-05-18

Light doc minification — removed 3 "Why this matters" motivational sections from role docs (2 in `cmux.md`, 1 in `kings.md`). Pure prose removal; no behavioural rules changed. Saves ~12 lines / ~1KB across the role docs read by King at session start.

### Honest minification report

Role doc footprint (read by King at every `/kingdom:start` session per v0.14.8):

| File | Lines | Lines in code blocks | Notes |
|---|---|---|---|
| `kings.md` | 1327→1320 | ~540 (40%) | Bulk is canonical bash patterns; non-trivial to trim safely |
| `workers.md` | 779 | ~349 (45%) | Same — pool helper + closer templates are load-bearing |
| `watchmans.md` | 631 | ~353 (56%) | /loop body bash + scan logic dominate |
| `cmux.md` | 617→610 | ~194 (31%) | Command reference; each block is canonical |
| `index.md` | 290 | ~65 | Mostly prose; tightest doc |
| `git.md` | 258 | ~115 | Branch model reference |
| `co-workers.md` | 190 | ~33 | Already light |
| **Total** | **4092→4080** | **~1649 (40%)** | |

Going further (target -30%) would require a structural rewrite: consolidate anti-patterns across files into one shared section, move shared bash helpers (`cmux_set_state`, `spawn_pool_slot`, etc.) into a single primitives doc, deduplicate cross-references. That's a half-day v0.19 candidate, not a one-pass minification.

### Cross-reference audit

Ran on all 7 role docs. 1 ambiguous internal anchor in `cmux.md` (`#notify` — works in current GitHub rendering but doesn't match the canonical lowercase-hyphenated anchor format). Not a runtime bug.

---

## [0.18.0] — 2026-05-18

The "magic + fast" release. Three big wins shipped together:

### 🆕 `/kingdom:day` — one-command daily cycle

New slash command. Composes `/kingdom:update` (if >24h old) + `/kingdom:start` (idempotent resume) + daily kickoff + perpetual auto-gate-poll loop into a single command.

Flow:
1. Audit (only if last `/kingdom:update` was >24h ago)
2. Spin up lanes (idempotent — resumes existing)
3. Read context (CLAUDE.md + MEMORY + watchman state)
4. Auto-dispatch idle lanes against pending work (60/40 industrial rule from v0.16.0)
5. Enter the auto-gate-poll loop:
   - Sentinels detected → fire Tier-1 gate
   - Tier-1 pass → overlay onto kingdom (v0.17.0) → fire Tier-2 gate
   - Tier-2 pass → notify Ter "review live diff?" (**only blocking point**)
   - Approval → carve `feature/<topic>` (v0.16.3) → push + auto-PR-body (v0.18.0) → discard overlay
6. Loop continues until Ter says stop, runs `/kingdom:exit`, or queue empties

Result: type ONE command, the kingdom runs the full day. Block only on human decisions. New file: `commands/day.md`.

### 🆕 Pre-warmed sub-agent pool

New `kingdom.json.cmux.subAgentPool` block. Each master keeps N idle `claude -p` processes ready in hidden tabs (default `perMasterPoolSize: 2`, `models: ["sonnet"]`). Sub-agent spawn becomes `cmux send` to the existing surface (~20ms) instead of `cmux tab-action --action new-terminal-right` + full Claude boot (~10–20s).

Layer-3 fan-out of 5 Sonnet sub-agents: ~100ms total (5 × 20ms) instead of ~50–100s (5 × 10–20s boot). **Layer-3 parallelism is now effectively instant.**

Pool refills in background after each consumption so subsequent spawns also hit the fast path. Falls back to standard spawn when pool is empty. Disable via `kingdom.json.cmux.subAgentPool.enabled: false`. Only applies to tab-mode spawns; Agent() background spawns are already cheap.

New section in `.kingdom/.setting/workers.md` § "Pre-warmed sub-agent pool" with full pool management bash.

### 🆕 Auto-generated PR bodies from task files

King's push approval gate now auto-fills `gh pr create --body` from the lane's task file. No manual PR-writing — the task file's discipline (Brief / Plan / Final summary) feeds directly into the PR body.

Field mapping:
- `## Brief` → `## Summary`
- `## Plan (multi-layer)` checked items → `## Implementation` list
- `## Final summary` → `## Verification`
- `KING_*__<lane>__<id>.md` test report → linked at bottom
- Footer: `🤖 PR body auto-generated from kingdom task file: tasks/<UTC>__<lane>__<id>.md`

Override available via dispatch brief `PR body: manual` — King skips auto-generation and asks Ter to paste a body before pushing. Default: auto-generate.

New section in `.kingdom/.setting/kings.md` § "Auto-generated PR body from task file".

### Why this matters

Three "magic + fast" feelings stack:

| Win | Felt where |
|---|---|
| `/kingdom:day` | "I typed one thing and my whole day happened" — single command, full flow |
| Pre-warmed pool | "Layer-3 parallel fan-out feels instant" — 5 sub-agents in 100ms instead of 100s |
| Auto-PR-bodies | "I never write PR descriptions anymore" — task file = PR body, auto |

### Non-breaking

- All three are additive. `/kingdom:day` is a new optional command; the underlying `/kingdom:update` / `/kingdom:start` / etc. still work standalone.
- Pre-warmed pool is opt-in via config (default enabled but easily disabled).
- Auto-PR-body kicks in by default; opt-out per-task via `PR body: manual` in dispatch brief.

---

## [0.17.2] — 2026-05-18

The "lazy implementor antidote" release. Real test caught a discipline failure: King had unlimited sub-agent capacity but used them as one-shot implementers without first doing exhaustive pattern discovery. Result: worker hardcoded a canonical URL when the project's `lib/brand-defaults.ts` already documented the env-driven pattern; King claimed `scripts/000_superscript.sh` doesn't seed `APP_BASE_URL` only to discover `scripts/026_provision_frontend_env.sh` DOES.

User feedback (paraphrased): "We got many master with unlimited sub-agent but I still need to push back on common standard — it not understand project like lazy implementor."

### Changed

- **`.kingdom/.setting/workers.md` Layer-1 Discovery section rewritten** with the "lazy implementor antidote" rule:
  - **Default stance**: "The project HAS a pattern; my job is to find it. Burden of proof is on me to show one doesn't exist."
  - **Mandatory exhaustive pattern grep** before any implementation. Use sub-agents in parallel (capacity is unlimited).
  - Concrete checklist: grep across the project, read `.env*` and `.env.example`, read all relevant `scripts/`, read `lib/*-defaults.*` for HOW-TO comments, read `compose.*.yml`, read project `CLAUDE.md`.
  - Synthesise findings in task file Step 1: either "pattern found at <file:line>, reusing it" OR "no pattern found; grepped N files; confirming new approach with King BEFORE implementing".
- **`.kingdom/.setting/kings.md` dispatch brief schema gets a NEW mandatory field**: `Patterns to grep first` — King specifies the file globs / search terms the worker MUST grep before implementing. Plus a `Default stance` line: "The project HAS a pattern. Find it before inventing. Burden of proof: if 'no pattern exists' — show me the grep output that proves it."

### Added (anti-patterns)

- ❌ **Implementing without exhaustive pattern grep first.** "I assume the project doesn't have X" is forbidden without grep evidence. Real failure: worker hardcoded `canonical: "https://webshop.bonfire.gg/"` at module top-level when `lib/brand-defaults.ts` had a comment block documenting the env pattern.
- ❌ **Claiming "scripts/foo doesn't seed X" without grepping all of `scripts/`.** Real failure: King said "000_superscript.sh doesn't seed APP_BASE_URL" → user push-back → discovered `026_provision_frontend_env.sh` does.

### Why this matters

Capacity isn't the bottleneck — **discipline is**. King has unlimited sub-agents but was spawning them as "write this thing for me" rather than "find me everywhere this pattern might already live, then implement consistent with it." v0.17.2 makes pattern discovery a **mandatory first step** of every Layer-1 Discovery, with the burden of proof on the worker to demonstrate no pattern exists (via grep output) before inventing a new approach.

### Non-breaking

- No schema, command, or behaviour changes outside the procedural rules.
- Existing in-flight tasks: King's next dispatch brief should include the `Patterns to grep first` field. Workers should run the exhaustive grep at Step 1 before any code change.

---

## [0.17.1] — 2026-05-18

Docs catch-up — v0.17.0 flipped the kingdom-merge model to working-tree overlay, but the README "Branch model" diagram + TL;DR still said "King merges them into kingdom" with `git merge --no-ff` arrows.

### Changed

- **README `## 🌳 Branch model` TL;DR rewritten** for v0.17.0:
  - Was: "King merges them into kingdom (local) for Tier-2 tests + your review"
  - Now: "King overlays their changes onto kingdom's working tree as UNCOMMITTED files (never commits on kingdom) so you can review every line in GitHub Desktop's Changes tab" + adds the discard step "After push, King discards the kingdom overlay (`git restore .`)"
- **Lifecycle Mermaid diagram updated**:
  - Arrows from worker-N to kingdom relabelled `git diff worker-N | git apply (overlay, no commit)` (was `git merge --no-ff`)
  - Kingdom node label updated to `WORKING-TREE OVERLAY (never commit) · Tier-2 gate · review`
  - Develop→kingdom arrow relabelled `git fetch + reset --hard origin/develop (start of each review cycle)` (was `git fetch + merge`)
  - Worker→feature transition arrow text now mentions GitHub Desktop review + `git restore .` cleanup
- **New "What you see in GitHub Desktop after King overlays" subsection** — concrete ASCII rendering of the Changes tab showing 11 modified files line-by-line. Drives home the v0.17.0 promise: the Changes tab IS the review surface, not commit history.

### Why

User confirmed v0.17.0 logic was right but the README diagram + TL;DR still showed the old merge-based model — confusing for first-time readers. v0.17.1 brings the docs in sync with the spec.

---

## [0.17.0] — 2026-05-18

**BREAKING** — the "kingdom never commits; it's a working-tree overlay" release. Real frustration caught a fundamental design flaw: prior versions had King create merge commits on the `kingdom` branch, but GitHub Desktop's "Changes" tab (and VS Code's source-control panel) shows only UNCOMMITTED changes. So the user opened Changes tab, saw nothing, and was told to "click History tab to see commits" — exactly the wrong UX. v0.17.0 flips the model: kingdom holds the integrated changes as UNCOMMITTED files so the Changes tab shows everything line-by-line.

### Changed (breaking — but only the King's behaviour, not the schema)

- **Kingdom no longer accumulates commits.** Was: `git merge --no-ff worker-N` into kingdom per lane (5+ merge commits per review cycle). Now: `git reset --hard origin/develop` then `git diff worker-N | git apply` or `git checkout worker-N -- .` per lane — changes overlay as UNCOMMITTED working-tree modifications.
- **Review surface changed.** Was: `git log --oneline origin/develop..kingdom` + `git diff origin/develop..kingdom --stat`. Now: `git status --short` + `git diff --stat` (since kingdom has no commits, the diff is between the working tree and `origin/develop`).
- **Tier-2 gate runs on the overlay** (uncommitted working tree). Tests/smoke/lint see all integrated changes — same coverage as the merge-commit-based version, just no commits to clean up after.
- **After push, King discards the overlay.** `git restore .` (or `git reset --hard origin/develop`) drops the working-tree changes. Kingdom is back to clean. Next review cycle starts fresh.
- **King's workspace description sequence updated**:
  - was: `▶ Merging <lane> into kingdom` → `⚠ Review on kingdom?` → `✅ Pushed`
  - now: `▶ Overlaying <lane> changes onto kingdom` → `⚠ Review live diff` → `▶ Discarding kingdom overlay` → `✅ Pushed`

### Why this matters

Real test transcript (paraphrased): User opened GitHub Desktop on kingdom, saw empty "Changes" tab, was told "click History tab" — got frustrated: "at kingdom never commit, I need to see real diff real update what file I need to see." Prior model required navigating commit history; v0.17.0 makes the Changes tab the canonical review surface. **Every file Ter cares about is right there, uncommitted, line-by-line.**

### Updated anti-patterns

- ❌ King commits on kingdom branch (v0.17.0 forbids — overlay only)
- ❌ King creates merge commits via `git merge --no-ff worker-N` on kingdom — use `git apply` or `git checkout -- file` instead
- ❌ King doesn't reset kingdom to `origin/develop` before overlaying (changes from prior cycles would pollute the review surface)

### Migration

- Existing kingdoms with merge-commit history on the `kingdom` branch: King can `git reset --hard origin/develop` on first v0.17.0 run to clean up (kingdom is local-only, so no remote impact). Or leave the old commits — they're harmless; just don't add new ones.
- `kingdom.json` schema unchanged.

### Non-breaking parts

- `feature/<topic>` workflow unchanged — still carved from `worker-N` tip, byte-for-byte (v0.16.3 rule).
- Worker → King communication unchanged (sentinels, 4-step closer, notifications).
- Two-tier gate unchanged in concept; just Tier-2 runs on the overlay instead of merge-committed state.

---

## [0.16.3] — 2026-05-18

The "feature branch = worker-N tip, byte-for-byte" release. Real test caught a workflow violation: King had 5 merge commits on `kingdom` (correct), then planned to add a smoke test report as a 2nd commit on `feature/fe-p0-found-7-seo-metadata` BEFORE push (incorrect — kingdom no longer reflects what's about to ship). v0.15.1 said "carve feature/* from worker-N tip" but didn't enforce strict equality.

### Added

- **`.kingdom/.setting/kings.md` § "STRICT: `feature/<topic>` = `worker-N` tip, byte-for-byte identical"** — new subsection inside "Kingdom as review staging". Rules:
  - `feature/<topic>` is a fast-forward checkout from `worker-N` tip
  - King MUST NOT add commits on the feature branch after carving
  - Kingdom = source of truth for what's about to ship; feature branches = exact mirrors
  - Concrete correct + wrong bash snippets
- **`kings.md` § "What to do when you want extra content in the PR"** — explicit decision matrix:
  - **Option A** (preferred): worker commits the extra content as part of its closer. Single commit on worker-N includes code + report + doc updates.
  - **Option B**: separate PR. Fresh `feature/<topic>-followup` branch from `origin/develop` for genuinely independent content.
  - Decision table: which to use when (test report ONE PR → A; test report MULTIPLE PRs → B; doc update about THIS feature → A; cross-cutting infra change → B)
  - Default: when uncertain, choose B (separate PRs are easier to review + revert)
- **New anti-pattern added** to the "Kingdom as review staging" anti-patterns list:
  - "King adds commits to `feature/<topic>` after carving from worker-N tip" — with the real-test example

### Changed

- **README "Three rules to remember" rule #3** — expanded to enforce strict equality: "PRs carve from `worker-N` tip, not from `kingdom`, and stay byte-for-byte identical. Each `feature/<topic>` is a fast-forward checkout of the lane's tip — NO commits added on the feature branch after carving."

### Why this matters

Real transcript (paraphrased): King had `kingdom` at d75b85e (5 merge commits visible), Ter approved bundling a smoke report into PR #3, King's plan was "feature/fe-p0-found-7-seo-metadata · 2 commits (worker-2 commit + test report)" — that 2nd commit would only exist on `feature/*` not on `worker-N` or `kingdom`. Ter caught it: "no, merge all PR to kingdom so I can see it." v0.16.3 codifies: kingdom must reflect EXACTLY what's about to ship. If extra content needs to be in a PR, put it on worker-N first or use a separate PR. No surprises after kingdom review.

### Non-breaking

- No schema, command, or behaviour changes outside the kings.md procedural rules.
- Existing kingdoms keep working; v0.16.3 just makes the rule that was implicit in v0.15.1 explicit + enforceable.

---

## [0.16.2] — 2026-05-18

Docs polish — README three-tier hierarchy diagram fixed to show **spawn relationships**, not just topology.

### Changed

- **README `### Three-tier visual hierarchy` Mermaid diagram** — was showing all 5 workspaces as direct children of the cmux.app window (topologically correct but loses the orchestration story). Fixed to show:
  - cmux.app window → King (you launch claude here, solid bold arrow)
  - King → worker-1, worker-2, co-worker-1, watchman-1 (dashed "spawn" arrows representing `/kingdom:start`'s `cmux new-workspace` calls)
  - Lane masters → sub-agent tabs (dashed "spawn" arrows via `Agent()` or `cmux tab-action`)
  - Watchman → internal split top/bottom (solid plain — internal layout, not spawn)
- **Diagram arrow legend** added below the diagram explaining the three arrow styles (solid bold = launch, dashed = spawn, solid plain = internal layout)
- **Workspace colour names corrected** in the diagram — "violet" / "blue" / "rose" → "Purple" / "Blue" / "Rose" (matches v0.14.13 fix where cmux's named-color set was clarified — `violet` isn't a cmux color)

### Why this matters

User question: "why not worker-N co-worker-N watchman-1 spawn under king?" — the diagram was correct about cmux.app's flat topology (siblings under window) but lost the orchestration story. v0.16.2 reframes the diagram around the **spawn relationship**: King is the dispatcher that creates the lane workspaces, lane masters spawn sub-agent tabs.

### Non-breaking — diagram-only change

No spec, schema, command, or behaviour changes. Pure visual clarity.

---

## [0.16.1] — 2026-05-18

Docs polish — README branch model section rewritten for clarity.

### Changed

- **README `## 🌳 Branch model` section rewritten**:
  - **New TL;DR callout** at top — one paragraph stating the canonical flow (lanes work locally → kingdom integrates + Tier-2 tests + Ter reviews → King carves feature/* from worker-N tip → PR to develop)
  - **Mermaid diagram simplified to `graph LR`** (left-right flow) showing local-to-online progression more visually. Removed busy co-worker + watchman nodes from the diagram to keep the lifecycle clear (they're documented in the table below).
  - **"Three rules to remember"** numbered callout — the non-negotiable contract that gets confused most often:
    1. Lane branches stay local
    2. `kingdom` is local-only review + test staging (NEVER pushed)
    3. PRs carve from `worker-N` tip, not from `kingdom`
  - **New "Two-tier gate (v0.16.0+)" subsection** — explicitly documents Tier-1 (typecheck-only in lane) vs Tier-2 (full tests on kingdom) with what each catches + push approval requires Tier-2 pass
  - **Three "Why" paragraphs** at the end — work surface / PR surface / integration surface — explaining the design choice in plain language

### Why this matters

Real user check-in: "so it like commit PR to 'kingdom' then but when fire to PR feature it push from worker-N branch to develop right" — mental model was right, but the prior diagram + table required puzzling to confirm. v0.16.1 makes the rules immediately visible: TL;DR at top, three numbered rules below the diagram, two-tier gate explicit.

---

## [0.16.0] — 2026-05-18

The "60% conservative + 40% industrial scheduler" release. Real test feedback: "use master as much as possible, don't let them rest; King must plan for maximum capacity; King can run same job on two workers to compare." Calibrated as a balance — conservative core (push gates, kingdom merge, human approvals) stays non-negotiable; industrial overlay (auto-delegate big work, load idle capacity, parallel dispatch) layers on top for capacity-loading behaviour.

### Added

- **`kings.md` § "Calibrated philosophy — 60% conservative core, 40% industrial overlay"** — new top-level section defining the balance:
  - **Conservative core (60%)**: human-gated push, mandatory kingdom merge, non-skippable gate, watchman passive by default, confirmation on risky moves, small inline work allowed
  - **Industrial overlay (40%)**: big work auto-delegated, auto-load idle capacity, plan for max parallelism, parallel duplicate dispatch (Ter-initiated), watchman test-verification duty
  - **Conflict resolution**: when the two halves disagree, conservative wins (60% is the floor, 40% layers on top)
- **`kings.md` § "Two-tier gate — light per-lane, heavy on kingdom"** — formalises kingdom as test environment:
  - **Tier 1 (lane)**: typecheck only, runs in `.worktrees/<lane>`. Fast feedback in seconds.
  - **Tier 2 (kingdom)**: full tests + smoke + lint on the integrated kingdom branch. Catches cross-lane bugs Tier 1 misses.
  - Push approval requires Tier 2 pass (not just Tier 1).
- **`kings.md` § "Lane utilisation — load idle capacity"** — bash logic for the utilisation check + default behaviour rules:
  - 2+ idle lanes + 2+ pending → auto-dispatch obvious matches
  - 1 idle + 1 pending → suggest, await nod
  - Controversial work → always suggest, never auto-dispatch
- **`kings.md` § "Parallel duplicate dispatch (Ter-initiated)"** — explicit pattern for race-style exploration: same sub-task-id, different briefs/models, lanes named with `-A` / `-B` suffix in their task files. Winner ships; loser archived for audit.
- **`watchmans.md` § "On-demand test verification (King-dispatched, read-only)"** — new role expansion:
  - Request artifact at `<LOGS>/watchman-requests/<UTC>__verify-<slug>.md` with brief + commands + scope
  - Watchman picks up next `/loop` tick, runs commands, writes `WATCH_*__verify-*.md` report, notifies King
  - **Will**: run tests, read source, write report. **Won't**: edit test code, push, commit, take action on failures.

### Why this matters

User feedback: "if the job is getting big it must auto pass to the worker-N if job about test pass to watchman-N, use master as much as possible don't let them rest, and when king plan for task must plan for maximum capacity of worker that can do, don't plan for small job, sometime king can run same job on two worker to compare or to help each other find best solution." Plus the rule "king + master always send to 'kingdom' branch after task done or need to test." The 60/40 calibration captures the intent without overshooting — kingdom branch is now explicitly the test environment (Tier 2 gate runs there), idle lanes get loaded automatically, big work always delegates, and Ter-initiated duplicate dispatches are a first-class pattern.

### Non-breaking

- No schema changes. `kingdom.json.gate` block already has `typecheck` / `tests` / `smoke` / `lint` keys; v0.16.0 just splits which keys run at which tier.
- Existing single-tier gate runs continue to work — if you want pre-v0.16.0 behaviour, just keep using the lane gate. The two-tier flow is the recommended default; King applies it automatically when watchman exists.
- `watchman-requests/` directory is auto-created by watchman on first encounter; no migration needed.

---

## [0.15.2] — 2026-05-18

The "every artifact carries the lane" release. Real test surfaced drift: a lane wrote its curated digest as `2026-05-18T0443Z__other__sonnet__fe-found-7-seo-metadata.md` — no lane name! Couldn't `ls *worker-2*` to find everything that worker did. The task file spec already required `<UTC>__<lane>__<sub-task-id>.md` but the curated digest didn't include lane, and the King's behaviour drifted. v0.15.2 codifies lane-in-every-artifact strictly.

### Changed

- **Curated digest filename now includes the lane** — was `<LOGS>/<ID>.md`, now `<LOGS>/<UTC>__<lane>__<sub-task-id>.md`. Matches the task-file naming convention so `ls *__worker-3__*` from any of the artifact dirs (`tasks/`, `logs/`, `logs/raw/`, `logs/done/`, `docs/test-reports/`) returns lane-attached files only.
- **Raw output filename clarified** — `<LOGS>/raw/<UTC>__<sub>-<lane>__<sub-task-id>.md` (was `<ID>__<sub>-<lane>.md`). Same shape as before, just `<sub-task-id>` made explicit at the end so the filename is fully self-describing.
- **Sentinel filename clarified** — `<LOGS>/done/<UTC>__<sub>-<lane>__<sub-task-id>.flag` (same convention).
- **Test report filename clarified** — `<project>/docs/test-reports/KING_<UTC>__<lane>__<sub-task-id>.md` (was already this pattern; documented now).

### Added

- **`.kingdom/.setting/workers.md` § "Task-artifact naming — strict"** — new top-level section right before "Task file" subsection. Defines:
  - **Naming convention table** — every per-task artifact's exact filename pattern + where the lane appears
  - **Continuation grep patterns** — concrete `ls`/`grep` commands to find "all of worker-3's work today" / "most recent worker-3 task" / etc.
  - **Anti-patterns** — task file without lane in name, inconsistent lane positions, renaming after creation, putting two lanes in one file
  - **Non-lane artifacts carve-out** — `/kingdom:update` digests, King planning files (`<UTC>__king-plan__<slug>.md`), Watchman reports — these intentionally have no lane (artifact-type in segment 2 instead). The grep contract still holds: anything with a lane in segment 2 IS lane-attached.

### Why this matters

User feedback: "on task file can we name file name to more specific to workspace like, this task is for worker-3 (it can switch later anyway) just it get to continue work more smooth." Workers are generic capacity (v0.5.0), but each task file is a frozen snapshot of that moment's lane assignment. The lane in the filename makes continuation easy: re-running `/kingdom:start` on a paused session, King's first task-file scan can be filtered per lane (`ls tasks/*__worker-3__*`) to know exactly what work was paused mid-flight.

### Non-breaking

- Existing kingdom artifacts keep their original names — only NEW artifacts use the strict convention.
- Master read patterns (Tier 2 `Read(<LOGS>/<ID>.md, limit=15)`) still work — King reads by sub-task-id, the filename pattern just makes the lane visible alongside it.

---

## [0.15.1] — 2026-05-18

The "kingdom is the review surface, not just the integration branch" release. Real test caught a workflow gap: King had 3 gated worker branches ready, asked for push approval directly — skipping the kingdom merge that lets Ter see the integrated code surface before any push. Ter had to manually redirect to "merge to kingdom first, then review, then push." v0.15.1 makes the merge-to-kingdom-for-review step **mandatory** between gate-pass and push.

### Added

- **`.kingdom/.setting/kings.md` § "Kingdom as review staging — MANDATORY before any push"** — new top-level section right before "Push approval gate". Defines:
  - **Why**: gate catches mechanical conflicts; review catches logical conflicts, design judgement, bundle decisions
  - **Mandatory workflow** (5 steps): merge into kingdom → print review surface → ask Ter to review → wait for approval → carve `feature/*` from lane tip (NOT from kingdom) + push + PR
  - **Why carve from lane tip, not kingdom**: keeps PRs one-purpose, one-commit, traceable to a single lane
  - **Multiple in-flight lanes** — merge order (oldest sentinel first) + reset-kingdom-to-origin-develop-first
  - **Common conflict patterns table** — `TODO_*.md` (keep all close-suffix headers), `CHANGELOG.md` (keep both entries), `docs/test-reports/` (no real conflict, different filenames), same-source-file collision (STOP, surface to Ter)
  - **Anti-patterns** — King jumping straight to "push?", carving `feature/*` from kingdom, pushing without review surface, auto-resolving real collisions

### Changed

- **Auto-gate flow (v0.14.10 § "The auto-trigger rule")** — gate-PASS now flows into the kingdom merge before asking Ter. Sequence:
  1. Gate passes → merge lane into kingdom (resolve common conflicts)
  2. Print `git log --oneline origin/develop..kingdom` + `git diff origin/develop..kingdom --stat`
  3. `cmux notify --workspace $KING_WS --title "👑 King · review on kingdom?"` + ask Ter in chat
  4. Wait for Ter's review approval
  5. On approval: carve `feature/<topic>` from lane tip, push, open PR
- **Workspace description state sequence** — King's auto-gate flow workspace-description states now: `▶ Gating` → `▶ Merging <lane> into kingdom` → `⚠ Review on kingdom?` → (Ter approves) → `▶ Carving feature/<topic>` → `✅ Pushed`.
- **Anti-patterns list** — added the new failure mode ("King jumps from gate-pass directly to push, skipping kingdom merge").

### Why this matters

Real test transcript: King had 3 workers gated and ready, was about to push each directly as separate feature branches. Ter caught it: "but after all you need to merge all to kingdom to let me see all code first right". King course-corrected gracefully — but the spec didn't enforce the rule. v0.15.1 codifies it as MANDATORY. The kingdom branch is what its name suggests — the staging area where the King shows you everything before anything reaches origin.

### Non-breaking

- Pure rule-addition; no schema, command, or behavior changes outside the gate→push flow.
- Existing in-flight gates still work — King applies the new merge-to-kingdom step on its next gate-pass.

---

## [0.15.0] — 2026-05-18

The "efficient by default" release. v0.14.9 made tab the default spawn mode for visibility — but tab spawns cost ~10–20s each (full Claude session boot) while `Agent()` spawns cost ~2s (in-process). For cheap fan-outs (Haiku Layer-1 scans, `/kingdom:update`'s 4 Sonnet specialists, parallel doc digests), tab cost was 5–10× too high. v0.15.0 switches to **model-tiered defaults**: Haiku always headless, Sonnet headless by default (override to tab per-task), Opus tab by default.

### Changed

- **`kingdom.json.cmux.subAgentSpawnDefault` → `subAgentSpawnByModel` block** — per-model defaults instead of one-size-fits-all:
  ```json
  "subAgentSpawnByModel": {
    "haiku":  "background",   // always cheap → Agent()
    "sonnet": "background",   // default cheap; override per-task to "tab"
    "opus":   "tab"           // expensive + slow → tab
  },
  "subAgentSpawnFallback": "tab"
  ```
- **`workers.md` "Tab vs Agent decision" rewritten** — now explains the **spawn-cost reality** table (tab ~10–20s vs Agent ~2s), the **model-tiered defaults**, and a **per-task override** mechanism via the dispatch brief's `Spawn mode:` line.
- **`kings.md` dispatch brief schema** — added optional `Spawn mode: tab|background|split` field. Master honours the override; otherwise uses model-tiered defaults.

### Why this matters

Real-world example: `/kingdom:update`'s Layer-1 Discovery fan-out spawns 5–10 Haiku scanners. Pre-v0.15.0 (default `"tab"`) cost ~10s × 10 = 100s just for spawn. Post-v0.15.0 (Haiku → background) costs ~2s × 10 = 20s with `Agent()` running in parallel headless. Five times faster on the bottleneck step of an audit pass.

For Sonnet fan-outs (e.g., worker's Layer-3 parallel edits), the default is also `"background"` — but the **per-task override** lets Ter say "watch worker-1 do BE-AUTH-3" and the dispatch brief includes `Spawn mode: tab`, forcing visibility for that specific task.

### Communication efficiency (full picture)

| Hop | Latency |
|---|---|
| King → Master (`cmux send` text + Enter) | ~50ms (cmux requires 2 RPC calls; can't collapse) |
| Master → King (sentinel + notify) | ~10ms write + ≤5s poll worst-case |
| Master → Sub-agent (Agent, default for haiku/sonnet) | **~2s** (was 10–20s for tab) |
| Master → Sub-agent (Tab, default for opus + override) | ~10–20s (visibility tax) |
| Sub-agent → Master (closer) | ~10ms + ≤5s poll |

### Non-breaking

- Existing `kingdom.json` with `subAgentSpawnDefault: "tab"` is honoured as fallback when `subAgentSpawnByModel` is missing — graceful migration.
- Per-task override via dispatch brief is opt-in; masters without explicit Spawn mode fall back to model-tiered defaults.

### Other improvements considered (skipped)

- **Streaming between agents** — not how CC works
- **Shared memory across sub-agents** — not how CC works
- **Hooks-based auto-notify** — user's hook config is broken (recurring `Hook JSON output validation failed`); worth fixing separately, not as kingdom feature
- **Pre-warmed Claude session pool** (eliminate tab boot cost via `cmux send` to idle session) — deferred to v0.16+; model-tiered defaults capture 80% of the win without new infrastructure

---

## [0.14.13] — 2026-05-18

The "stop fighting `/kingdom:start`" release. Real test surfaced four friction points that turned an 18-min King planning phase into a 25-min flow with manual fixups. v0.14.13 codifies the hard-won patterns so the spawn is **18 min of planning + ~3 sec of execution** with no prompts and no fixups.

### Changed

- **Removed the "Proceed with the spawn?" prompt** at Phase 1 step 7. The user invoking `/kingdom:start` IS the consent for the spawn's side effects (worktree creation, workspace spawning, branch attachment). Print the resolved plan and move directly to Phase 2.
- **Phase 4 worktree creation made silently idempotent** — 3-case logic via new `attach_or_create_worktree ()` helper:
  - Case A: worktree directory exists → reuse silently
  - Case B: branch exists (created by prior kingdom session) → attach worktree to existing branch silently
  - Case C: neither exists → create fresh branch from `origin/<base>` + worktree
  Previous behaviour (`git worktree add -b` + `|| cd`) crashed when the branch existed but worktree didn't.
- **Phase 5 PRIMARY `spawn_master_workspace ()` rewritten with the hard-won 4-call pattern:**
  1. `cmux new-workspace --name "X" --cwd ... --command "claude" --focus false`
  2. `cmux workspace-action --action rename --workspace <ref> --title "X"` ← **mandatory** — without this, sidebar shows `"✳ Claude Code"` (the auto-surface title) instead of `"X"`. Hard-won from real test where King had to manually re-fire renames.
  3. `cmux workspace-action --action set-color --workspace <ref> --color <color>` (since `new-workspace` doesn't accept `--color`)
  4. `cmux workspace-action --action set-description --workspace <ref> --description "..."` (same reason as Step 2 — description can be clobbered)
- **Robust ref capture** — `grep -oE 'workspace:[0-9]+' | head -1` replaces `awk '/workspace:/ {print $2}'`. The awk pattern broke silently in real test pipelines (returned blank, broke workspace-refs.env reconstruction).
- **Default `workspaceColors.worker`: `"violet"` → `"Purple"`** — `violet` is NOT in cmux's named-color set (Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy, Indigo, Purple, Magenta, Rose, Brown, Charcoal). Prior runs required the King to substitute Indigo manually.

### Added

- **`.kingdom/.setting/cmux.md` § "Spawn → name → color → describe (the 4-call pattern)"** — explicit doc of the hard-won 4-call sequence per workspace creation, with the full `spawn_lane ()` helper and rationale for each step.
- **Color-name pitfall callout** in `cmux.md` — explicitly notes `violet` is not in cmux's set; use `Purple`.

### Why this matters

Real test transcript (paraphrased): "Cooked for 18m 5s ... Proceed with the spawn? [yes] ... cmux's `--name` didn't make name stick, had to fire `workspace-action --action rename` ... ref-capture awk pipe broke, reconstructed env file manually ... violet isn't a cmux color, substituted Indigo." Four separate manual fixups for what should be a one-command spawn. v0.14.13 puts every fixup into the spec so future runs need none.

### Non-breaking

- No schema changes, no command-name changes.
- `kingdom.json.cmux.workspaceColors.worker` default flipped from `violet` (invalid) to `Purple` (valid). Existing kingdoms with `"violet"` explicitly will still work IF cmux substitutes silently (it appears to fall back to a default colour), but updating to `"Purple"` makes the colour intent explicit.

---

## [0.14.12] — 2026-05-18

The "override cmux's wrong auto-state" release. cmux.app auto-detects "Running" / "Idle" / "Needs input" badges per workspace, but the detection is heuristic — a lane stuck on a permission prompt may still show as "Running"; a King with a pending "push?" may show as "Idle". cmux does NOT expose direct CLI control over these auto-labels. v0.14.12 wires up the **manually controllable** badge — `mark-unread` / `mark-read` — to override cmux's wrong auto-state with three explicit signals: badge + description + notify.

### Added

- **`.kingdom/.setting/cmux.md` § "Attention markers — mark-read / mark-unread"** — new section before "Dynamic workspace descriptions":
  - Explains what cmux's auto-state covers vs what `mark-unread` does
  - Three-layer state override pattern: `mark-unread` + `set-description` + `cmux notify`
  - State → markers convention table (8 kingdom states mapped to badge / description / notify settings)
  - When to clear: `mark-read` fires when the underlying attention resolves
- **Watchman blocked-lane scan** — now also fires `cmux workspace-action --action mark-unread` on detection, and `mark-read` when the lane unblocks. The badge dot now reflects the lane's true state regardless of cmux's auto-detection.
- **King auto-gate flow** — fires `cmux workspace-action --action mark-unread` on:
  - King's own workspace when "push?" is pending
  - Originating lane's workspace when gate FAILs
- **King post-push** — fires `cmux workspace-action --action mark-read` on King's workspace once Ter approves push (clears the dot).

### Why this matters

Real feedback (paraphrased): "cmux.app does the 'Running' / 'Needs input' automatic, it not always correct — มั่ว (guessed)." cmux's auto-state can't be overridden, but `mark-unread` is a separate manually-controllable attention indicator. Now when kingdom KNOWS better than cmux (lane blocked despite "Running" auto-label, King waiting despite "Idle"), the kingdom's three signals (badge + description + notify) tell the truth.

### Non-breaking

- No schema changes, no command changes.
- All `cmux workspace-action` calls are silent-on-failure — descriptions/badges are cosmetic, not load-bearing.

---

## [0.14.11] — 2026-05-18

The "sidebar reads itself" release. cmux.app workspace descriptions are live-updatable via `cmux workspace-action --action set-description` — but the kingdom was setting them once at spawn time and never touching them again. v0.14.11 wires up dynamic descriptions so the sidebar shows a real-time status line per lane: progress bar, current layer, state emoji, blocked status, push prompts. Glance at the sidebar → know what's happening across the whole kingdom.

### Added

- **`.kingdom/.setting/cmux.md` § "Dynamic workspace descriptions"** — full reference for live state lines:
  - **State-emoji vocabulary**: `▶` running · `⏸` waiting · `⚠` needs attention · `✅` done · `❌` failed · `🐾` idle · `▰▰▰▱` progress bar
  - **Per-role description schema** with concrete examples for King / Worker / Co-worker / Watchman
  - **Update-site table** — when each role rewrites its description (12 trigger points across roles)
  - **`cmux_set_state` bash helper** — common pattern across all role docs
  - **Watchman-cross-update** — when the blocked-lane scan finds a stalled lane, it ALSO updates that lane's description to `⚠ Blocked · permission prompt` (visible immediately in sidebar)
- **`workers.md` "Live workspace description" subsection** — workers update at every layer transition (L1 → L2 → L3 → L4) + closer + idle, with the 4-layer progress bar `▰▰▰▰`.
- **`kings.md` "Live workspace description" subsection** — King updates at idle / gate-start / gate-pass / gate-fail / pushed. Push-state holds for 5 min then reverts to idle.

### Why this matters

Real test feedback: "can you use description of workspace cmux.app more benefit like if it running show progress bar ascii/emoji or tell it need input or etc". cmux.app's sidebar IS the kingdom's dashboard — descriptions were under-used. With v0.14.11 live updates, you can see at a glance:

```text
👑 King · Bonfire           ⚠ Push? · worker-2 · BE-AUTH-3 · gate pass
👷 worker-1                 ▶ BE-AUTH-3 · ▰▰▰▱ L3 Execution
👷 worker-2                 ✅ FE-P0-FOUND.7 done · sentinel written
👷 worker-3                 🐾 Awaiting dispatch
🧑‍💼 co-worker-1            🐾 Dormant · activate with "pair on co-worker-1"
🕵️ watchman-1               ▶ develop green · 2 PRs open · last tick 02:30Z
```

No clicks. Just glance.

### Non-breaking

- Description updates are **optional** — failures are silent (work continues without them).
- Schema is additive — no `kingdom.json` changes.
- Existing kingdoms get the updated role-doc behaviour next time the King reads them (or via `/kingdom:init` re-sync after `/plugin update`).

---

## [0.14.10] — 2026-05-18

The "King never sits on an un-gated sentinel" release. Prior versions had the King poll sentinels DURING dispatch (in-session flow) but had no rule for the cross-session case: King resumed, read state, saw a sentinel written in a prior session, reported the state... and stopped. Ter had to manually nudge "run the gate." v0.14.10 fixes this with mandatory auto-gate-on-detection.

### Added

- **`kings.md` § "Auto-gate on completion (King never sits on an un-gated sentinel)"** — new top-level section before "Working WITH the Watchman". Defines:
  - **Detection rule**: an un-gated sentinel = `<LOGS>/done/<ID>__*-<lane>.flag` with NO matching `KING_*__<lane>__<sub-task-id>.md` test report.
  - **Auto-trigger rule**: King auto-fires the pre-commit gate (non-destructive: typecheck + tests + dry-merge) on every un-gated sentinel detected. Gate PASS → `cmux notify "push?"` to Ter. Gate FAIL → `cmux notify "gate FAIL"` to lane's workspace + may dispatch fix-task.
  - **When this fires**: session resume, pre-Ter-interaction sweep, post-dispatch polling, watchman done-notify.
  - **Daily kickoff Step 0.5**: synthesis now includes "Un-gated work (auto-firing gates)" section listing what's being gated right now.
  - **Anti-patterns**: 4 things King MUST NOT do (report-and-stop, wait-for-Ter, ignore-old-sentinels, auto-push).

### Why this matters

Real test feedback (paraphrased): "after master done, king still idle. It not auto trigger king. King + master must always [be active]." Cross-session resume was the failure mode: King saw sentinels written in prior sessions, summarised, sat there. v0.14.10 makes the rule explicit: **every sentinel without a test report → auto-gate, no asking**. Push approval still requires human "push" word.

### Non-breaking

- No schema changes, no command changes.
- Gate is non-destructive (read-only commands inside the lane's worktree), so auto-firing is safe.
- Push approval gate is unchanged — still human-gated with FINAL `git merge-tree` conflict check.

---

## [0.14.9] — 2026-05-18

The "parallel work is now visible" release. v0.13.0 introduced tab-spawned sub-agents but defaulted to `"background"` (headless `Agent()`) — meaning by default, you couldn't see lane masters fanning out. v0.14.9 flips the default to **`"tab"`** so masters' parallel sub-agent work appears live in their workspace, auto-closing when each finishes. Also strengthens auto-close guarantees with a Watchman orphan-tab sweep.

### Changed

- **`kingdom.json.cmux.subAgentSpawnDefault` default flipped: `"background"` → `"tab"`** — every sub-agent spawn now opens a visible tab inside the master's workspace by default. Auto-closes on sentinel via 5-step closer Step 5.
- **`.kingdom/.setting/workers.md` "Spawning sub-agents" section restructured.** Tab is now the documented default; `Agent(...)` is the **opt-in** exception for cheap Haiku fan-outs (Layer-1 Discovery scans, doc digests, fan-outs of >3 short agents where N tabs would be cramped). Three options total: `"tab"` (default), `"background"`, `"split"`.
- **Visual fan-out example added** — concrete ASCII diagram of worker-1's workspace as 3 Sonnet sub-agents spawn for Layer 3 parallel code edits, then disappear cleanly when each writes its sentinel.

### Added

- **5-step closer robustness clarified** — Step 5 (`cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`) MUST fire on every exit path (success / blocked / error). Documented as a wrapper-pattern in the sub-agent's brief template.
- **Watchman orphan-tab sweep** — new `/loop` tick duty. Enumerates each lane master workspace's surfaces, finds tabs with title prefix `"🐱 sub"` whose recent output mentions "sentinel written" / "closer complete" AND have been idle ≥5 min → closes them via `cmux tab-action --action close`. Belt-and-suspenders for the rare case Step 5 fails (cmux unreachable, killed process). Sweeps logged to `master_agent.log`.

### Why this matters

Real test feedback: "and when master working i don't see it parallel work with sub-agent yet, if sub-agent running it will split screen or it will make more tab, tab or screen must auto close tho". Two fixes in one release: (1) make the default visible (flip default to `"tab"`), (2) make auto-close bulletproof (Step 5 + watchman sweep).

### Compatibility notes

- **`kingdom.json` schema is additive** — existing kingdoms without `cmux.subAgentSpawnDefault` get the new `"tab"` default automatically. To preserve v0.14.8 behaviour, set `"subAgentSpawnDefault": "background"` in your kingdom.json.
- **Cost note** — tabs are full Claude Code sessions; spawning many simultaneously costs more than headless Agent() calls. For cheap Haiku fan-outs (Layer-1 scans, doc digests), masters should explicitly use `Agent(...)` — documented in workers.md.

### Also bundled (small cleanup)

- **`kings.md` kickoff synthesis** — removed the duplicate "Good morning. Checking watchman state..." paragraph that was left dangling after v0.14.8. Now there's exactly one synthesis block (the merged Context loaded + Watchman state version).

---

## [0.14.8] — 2026-05-18

The "King reads ALL context at session start" release. v0.14.7 made the King read watchman state at every decision point — but that's only half the picture. The other half is the foundational context Ter has written down: workspace CLAUDE.md, project CLAUDE.md, auto-memory entries, personal notes. Without those, the King may dispatch tasks against rules Ter explicitly documented ("never use Prisma migrations", "confirm before every edit", "no source-project attribution in commits") — burning trust + cycles re-correcting.

### Added

- **`kings.md` Step −1 — Session-start context load (mandatory)** — King reads, in this order, before doing ANYTHING else (including watchman state):
  1. **Workspace CLAUDE.md** at `$PWD/CLAUDE.md` — workspace rules, project map, cross-cutting conventions
  2. **Project CLAUDE.md** at `$PWD/<project>/CLAUDE.md` — local stack, gate commands, project-specific rules
  3. **Auto-memory MEMORY.md** at `~/.claude/projects/<workspace-key>/memory/MEMORY.md` — durable user preferences, feedback rules, project facts. King skims the index + decides which specific entries to load JIT during planning.
  4. **Personal notes** (`TER.md`, `TER_WEEK.md`, etc. at workspace OR project root) — read for situational awareness; NEVER quoted, NEVER committed.
- **Kickoff synthesis** now leads with a **"Context loaded"** block before the watchman state block, so Ter can verify King actually read the right files.
- **Mandatory reads table** updated to include CLAUDE.md (workspace + project) + MEMORY.md + personal notes alongside the watchman files in the daily kickoff row.

### Why this matters

Real test feedback: "king must read all claude.md (workspace) skill memory, claude.md(project) skill memory, when start to make sure everything in place." Prior versions had the King jumping straight to watchman state — fast, but missing the human-authored rules. A King that doesn't know "never use Prisma migrations" will keep suggesting Prisma migrations even though Ter has that as a permanent memory entry. v0.14.8 closes this gap by making context load **Step −1** (before everything else) and surfacing what was loaded in the kickoff synthesis.

### Non-breaking

- No schema changes, no command changes. King-behaviour update only.
- HEADLESS-only kingdoms still benefit (Step −1 is independent of watchman or cmux).
- Kingdoms without CLAUDE.md / MEMORY.md / personal notes just skip those reads — no error, just nothing to load.

---

## [0.14.7] — 2026-05-18

The "King actually uses the Watchman" release. Prior versions treated watchman as background noise — it wrote `WATCH_*.md` reports, maintained `watchman_state.json`, surfaced `WATCH_DOCS_AUDIT.md` Gap findings, but nothing in the King's flow REQUIRED reading any of it. This release makes watchman first-class: King must read watchman outputs at every major decision point, otherwise the kingdom is "worse than running solo."

### Added

- **`.kingdom/.setting/kings.md` § "Working WITH the Watchman (mandatory when one exists)"** — new top-level section right after King's responsibilities. Defines:
  - **Mandatory reads table** — what watchman files King must read before each major action (daily kickoff, dispatch, gate, "push?" prompt, status questions, long idle)
  - **Pre-dispatch checks** — bash snippet King runs before `cmux send`: (1) is develop green per latest `WATCH_*develop_*.md`, (2) is target lane blocked per `watchman_state.json.blocked_lanes`, (3) PR queue informational
  - **Daily kickoff routine** — single synthesis paragraph aggregating all watchman state on first message of the day; auto-fires after `/kingdom:start`
  - **Reading patterns** — bash helpers for the 5 common watchman lookups
  - **No-watchman case** — what changes when `kingdom.json.shape.watchman: 0` (King skips watchman reads; loses safety net)
  - **Anti-patterns** — 4 things King MUST NOT do (dispatch on RED develop, skip Gap reads, ignore blocked-lane alerts, push without latest watchman state)
- **King's planning task file Step 0 — Watchman state read** — explicit step BEFORE the usual Layer-1 Discovery fan-out. Synthesis written here; planning sub-agents inherit the context.

### Why this matters

The kingdom ships watchman by default, watchman does a lot of work each tick (smoke checks, PR state snapshots, gap audits, blocked-lane scans as of v0.14.6) — but if the King doesn't READ those outputs, none of that work matters. Real test feedback: "King is like never use watchman when it has — king must use watchman as max benefit auto." v0.14.7 wires it in as mandatory at every decision point.

### Compatibility notes

- **Non-breaking** — no schema changes, no command changes. Behaviour change in how King plans + dispatches.
- **Watchman==0 kingdoms** — entire new section becomes no-op. King falls back to old behaviour (read `master_agent.log` only).

---

## [0.14.6] — 2026-05-18

The "lanes never silently stall" release. Fixes two related gaps: (1) Claude Code prompts for permission on every read of `.kingdom/**` and `.worktrees/**` files (lanes block until you approve), and (2) when a prompt DOES fire, cmux.app still shows the lane as "Running" — no notification, no badge, no way to know without clicking each lane.

### Added (prevention)

- **Expanded `.claude/settings.json` permissions allow-list.** Doctor Check 10 + Init Step 4.5 now also include path-scoped reads/writes:
  ```
  Read(.kingdom/**), Write(.kingdom/**), Edit(.kingdom/**),
  Read(.worktrees/**), Write(.worktrees/**), Edit(.worktrees/**)
  ```
  Pre-empts the most common interactive permission prompt — lanes reading task files at `.kingdom/<project>/tasks/` or worktree files at `.worktrees/<lane>/`. Existing kingdoms get the patch on next `/kingdom:doctor` run.

### Added (detection)

- **Watchman blocked-lane scan** — new duty in `watchmans.md`. Every `/loop` tick, watchman `cmux capture-pane`s each lane workspace and pattern-matches the last 30 lines against:
  - `Do you want to proceed\?` — Claude Code's standard permission prompt
  - `Esc to cancel` — same prompt's footer
  - `\[y/N\]` — common interactive y/n confirmations
  - `allow .* during this session` — session-scoped permission option
  - `Press Enter` — generic "press enter to continue" prompts

  When any pattern matches, watchman fires **dual** `cmux notify`:
  - `--surface <lane>` → blue ring on the lane's pane + tab lights up
  - `--workspace $KING_WS` → sidebar badge on King's workspace + bell-panel entry

  Idempotent + debounced via `watchman_state.json.blocked_lanes` — won't re-notify the same blocked lane every tick. Clears when the lane unblocks.
- **`.kingdom/.setting/cmux.md` § Read pane contents** — documents `cmux capture-pane` + `cmux read-screen`, the watchman pattern set, and the prevention-vs-detection split (prevention preferred via expanded allow-list; detection catches what slips through).

### Why this matters

Real test case: a lane was reading `.kingdom/bfg-swt/tasks/FE-P0-FOUND.8.md`, Claude Code asked "Do you want to proceed? 1. Yes / 2. Yes allow reading from tasks/ / 3. No". The cmux.app sidebar kept showing the worker as "Running" — silent stall. Ter only found out by clicking into the worker workspace. v0.14.6 prevents the most common case (path-scoped allow-list expansion) AND detects the rest (watchman scan + dual notify).

---

## [0.14.5] — 2026-05-18

### Changed

- **README: `## ⚡ Quick start` block added right after the hero** — popular-GitHub style. 4 commands you can copy-paste-and-go, plus a one-line "you now have 5 AI agents in cmux.app's sidebar" payoff, plus jump-links to the detail sections. Replaces the need to scroll past the cmux showcase + pillars to find install. The detail sections (Install, First time, Every day, The contract) stay where they are for users who want the full read.
- **Hero quick-links updated** — now includes `[Quick start]` as the first link, `[Every day]` instead of `[Setup]`, and drops `[Compare]` (no comparison section yet).

---

## [0.14.4] — 2026-05-18

Docs polish — SEO + tighter install/setup/start. README hero gets a subtitle that includes the keywords people actually search for ("Multi-agent orchestration kit for Claude Code — parallel AI coding with Git worktrees + native cmux.app"). Install/setup/start sections trimmed to feel like a confident daily routine, not a tutorial. New "🛡 The contract" callout lists exactly what kingdom will not touch.

### Changed

- **README hero** — H3 subtitle added: "Multi-agent orchestration kit for Claude Code — parallel AI coding with Git worktrees + native cmux.app". Plus two new badges (`multi-agent · orchestration`, `cmux.app · native`). Plus quick-link to "Compare". Plus an HTML comment with extended SEO keywords (claude code plugin, ai agent fleet, autonomous coding agent, composio agent-orchestrator alternative, etc.).
- **Install section** — collapsed to 3 commands. No more dependency-list paragraph in the install section (doctor handles that).
- **First-time setup** — trimmed to ~10 lines. One `mkdir`, one `claude`, one `/kingdom:init`. The detail moved to `cmux.md`.
- **Resume work** → renamed to **"Every day — your Monday-morning ritual"**. Tight pitch: `/kingdom:start` Monday, same Tuesday, `/kingdom:update` after vacation, `/kingdom:exit` end of day. Single paragraph at the end stating "it replaces the daily overhead of what-was-I-doing / did-anyone-push / is-develop-green / is-PR-reviewed."
- **New `## 🛡 The contract` callout** — 6 explicit promises about what kingdom won't modify (project files, develop/main, pushes, shell config, git config, .gitignore beyond one line) plus the reversibility guarantee.

### Why this matters

Prior README install/setup felt like a tutorial — walked through every concept inline. Real users want the confidence of "this is my daily ritual + here's exactly what it won't break." Pure docs change, no behaviour difference.

---

## [0.14.3] — 2026-05-18

Docs polish — show off the cmux.app integration that landed in 0.13.0–0.14.2. README now has a "What it looks like in cmux.app" section that visually demonstrates the workspace-per-master sidebar, the three notification surfaces (ring / badge / panel), the three-tier visual hierarchy, and the other cmux features the kingdom hooks into.

### Changed

- **README "Why kingdom?"** gets a new pillar: **Native cmux.app feel** (colour-coded workspaces, native notifications, no tab-multiplexing or custom UI).
- **New section: `🪟 What it looks like in cmux.app`** between "Why kingdom?" and "Install". Includes:
  - ASCII mockup of the cmux.app sidebar showing 5 colour-coded workspaces, pinned King, blue-ring + bell-badge indicators in context
  - "Three visible cmux notification surfaces" table — rings, badges, bell panel
  - New Mermaid diagram: three-tier visual hierarchy (Workspace → Tab → Split)
  - Table of cmux features the kingdom uses: workspace colours, pinning, descriptions, layout JSON, `cmux send --workspace`, `cmux tree --all`
  - "What `/kingdom:start` does in PRIMARY mode" — 6-step explanation tying it all together

### Why this matters

Prior README didn't make the cmux.app integration concrete. Users had to read 5 role docs + `cmux.md` to see how it all fits visually. Now the hero pillars + one visual section show off the feature set — what they see in the sidebar, what fires when, why it's better than dashboard-driven fleet ops.

---

## [0.14.2] — 2026-05-18

The "actually wire up cmux.app notifications" release. Prior spec mentioned `cmux notify` but inconsistently — `--pane` (wrong flag), missing for some events, no dual-target pattern. This patch threads notifications through every kingdom event that needs Ter's attention, using cmux.app's three visible surfaces: blue ring on pane, sidebar badge on workspace, bell-panel entry.

### Changed (notifications now mandatory in PRIMARY mode)

- **4-step closer Step 4** in `workers.md` and `co-workers.md` — mandatory dual `cmux notify` calls:
  - `--surface "$CMUX_SURFACE_ID"` → blue ring on the lane's own pane + tab lights up
  - `--workspace "$KING_WS"` → badge on King's sidebar entry + bell-panel logs the event
  - Previously was an optional "+ optional `cmux notify --pane <self>`" with the wrong flag (`--pane` doesn't exist; correct is `--surface`).
- **Watchman alerts** in `watchmans.md` — schema standardised: `--title "🕵️ watchman-N"` + `--subtitle "<event class>"` (e.g., `develop RED`, `CI failed · PR #N`, `Ready to merge · PR #N`) + `--body "<one-line context>"`. All target `--workspace "$KING_WS"`.
- **King gate notifications** in `kings.md`:
  - Pre-commit gate FAIL → notify originating master's workspace (so the lane gets a sidebar badge + ring)
  - Pre-commit gate PASS, asking "push?" → notify `$KING_WS` (Ter may be in another workspace; sidebar badge surfaces the prompt)

### Added

- **`.kingdom/.setting/cmux.md` § Notification system** — fully rewritten with three visible surfaces table (ring / badge / panel), kingdom notification schema (8 canonical events), targeting cheat-sheet, "what NOT to notify" list. Single source of truth for every notification call across the kit.

### Why this matters

cmux.app's notification UX is its strongest feature — blue rings, tab lights, sidebar badges, bell-icon panel with jump-to-recent. Prior versions used the wrong flag (`--pane` instead of `--surface`), missed events, and didn't use the dual-target pattern. v0.14.2 makes the kingdom's notification surface as polished as cmux.app's.

---

## [0.14.1] — 2026-05-18

### Fixed

- **`/kingdom:start` PRIMARY mode was renaming the wrong thing.** The King-workspace rename added in v0.13.1 used `cmux tab-action --action rename --workspace <ws>` — that actually renames the focused **surface** in workspace context, NOT the workspace's sidebar label. Sidebar kept showing whatever Claude Code auto-titled the active conversation. Now uses the correct `cmux workspace-action --action rename --workspace <ws> --title "…"` (the dedicated workspace-level command).
- **Pin command similarly corrected** — `tab-action --action pin --workspace <ws>` → `workspace-action --action pin --workspace <ws>`. (cmux accepts both; `workspace-action` is canonical for workspace ops.)

### Added

- **Workspace colors applied per role.** After spawning each lane workspace, `/kingdom:start` now runs `cmux workspace-action --action set-color --workspace <ref> --color <named>` to apply the color from `kingdom.json.cmux.workspaceColors`. Defaults: King=amber, Worker=violet, Co-worker=blue, Watchman=rose. Visible as left-edge color bars in the cmux.app sidebar — visual role discrimination at a glance.
- **King workspace gets a description** — `cmux workspace-action --action set-description` sets "Your conversation · pinned · `<UTC>`" so the sidebar shows context under the King's name.
- **`.kingdom/.setting/cmux.md` updated** with the workspace-action vs tab-action distinction (new "Rename" section table, new "Set workspace color + description" section, new "Common pitfalls" row for the renamed-wrong-thing case).

### Why this matters

Real test: user could see `👑 King · bfg-swt` correctly appear when manually running `cmux workspace-action --action rename --workspace workspace:17 --title "👑 King · bfg-swt"`. The spec was using `tab-action` which silently no-op'd the sidebar label. Two near-identical commands (`tab-action --action rename --workspace …` vs `workspace-action --action rename --workspace …`) do completely different things — the spec needed the explicit fix.

---

## [0.14.0] — 2026-05-18

The "graceful teardown" release. New `/kingdom:exit` command for safely closing a kingdom session — checks in-flight work, notifies each lane, gracefully exits Claude in each workspace, closes lane workspaces, writes a session-end log marker. Keeps the King's workspace by default.

### Added

- **`/kingdom:exit`** — new slash command for graceful kingdom teardown. Signature: `/kingdom:exit [project=<name>] [--force] [--include-king] [--audit]`.
  - 6-step flow: resolve project + source workspace-refs → in-flight check → optional audit → notify each lane → graceful Claude exit per lane (sends `/clear`) → close lane workspaces → session-end log line.
  - **Default**: keeps King's workspace (your conversation persists); pass `--include-king` for full teardown.
  - **In-flight handling**: always asks (Option C) — 3 choices: (1) wait up to 5 min for sentinels to appear, then force-close, (2) force-close immediately, (3) abort. Override with `--force` to skip the prompt.
  - **Idempotent** — re-running on an already-exited kingdom prints "nothing to close" and updates only the session-end line.
  - **Safe by design** — never runs `git push` or `git commit`; never removes worktrees; never deletes audit artifacts. Just closes cmux workspaces and writes a log line.
- **`commands/exit.md`** scaffolded into the plugin; added to README slash command table.

### Compatibility notes

- **Non-breaking** — purely additive. Existing kingdoms work as-is.
- **PRIMARY mode only for workspace closing** — FALLBACK (raw tmux) closes via `tmux kill-session`; HEADLESS has no workspaces to close. Spec covers all three but Step 5 (close workspaces) only does cmux work.

---

## [0.13.1] — 2026-05-18

### Fixed

- **`/kingdom:start` PRIMARY mode forgot to rename the King's own workspace.** After spawning master workspaces (workers/co-workers/watchman) with proper emoji-prefixed names, the King's workspace stayed at the default `Claude Code` label. Real test: sidebar showed 👷 worker-1, 👷 worker-2, 🧑‍💼 co-worker-1, 🕵️ watchman-1 — but the King's session was just `Claude Code · Idle`. Now Phase 5 PRIMARY runs `cmux tab-action --action rename --workspace "$KING_WS" --title "👑 King · <project>"` before pinning. Renames before pinning so the pin operation reflects the correct title immediately.

---

## [0.13.0] — 2026-05-18

The "three-tier cmux hierarchy" release. Big spec correction + new cmux reference doc. PRIMARY mode now uses cmux.app properly: each master gets its own workspace (sidebar entry), sub-agents spawn as tabs (auto-close on sentinel) when visibility is wanted, watchman gets a predefined dual-view split. Fixes the broken `cmux claude-teams` flow from prior versions.

### Added

- **`.kingdom/.setting/cmux.md`** — new canonical cmux reference doc for every role. 300+ lines covering: three-tier hierarchy (Workspace → Tab → Split), every cmux command kingdom uses (`new-workspace`, `tab-action`, `new-split`, `send`, `notify`, `rename-tab`, `identify`, `tree`, `list-panes`), env vars (`CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`), common pitfalls, and reference URLs. All other role docs link here for cmux details instead of repeating commands inline. Scaffolded by `/kingdom:init` into every workspace.
- **Three-tier hierarchy** (PRIMARY mode):
  - 🏢 **Workspace** per master — King + every worker + co-worker + watchman gets its own cmux.app workspace (sidebar entry, full screen, native session restore).
  - 📑 **Tab** for visible sub-agent spawns inside a master's workspace — auto-closes on sentinel flag (new 5-step closer).
  - 🪟 **Split** for predefined dual-view (watchman's claude + `gh pr watch`).
- **`kingdom.json.cmux` block** — controls layout behaviour: `pinKingWorkspace` (true), `workspaceColors` (per role), `subAgentSpawnDefault` ("background" — Agent calls; alternative "tab"), `watchmanLayout` (vertical split with top=claude, bottom=`gh pr list --watch`).
- **5-step closer for tab-spawned sub-agents** — extends the standard 4-step closer with Step 5: `cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`. Tabs self-destruct after the sentinel flag; master doesn't clean up. Agent-spawned sub-agents (default, headless) skip Step 5 (no tab to close).
- **`commands/start.md` Phase 5 + 6 rewrite** — PRIMARY mode uses `cmux new-workspace --name --cwd --command "claude"` per lane (no more broken `cmux claude-teams`). Returns workspace refs which persist to `$LOGS/workspace-refs.env` so King + watchman can address lanes by stable refs across session restarts.
- **`commands/doctor.md` Check 1 expanded** — now verifies the 9 specific cmux commands kingdom uses (`new-workspace`, `new-split`, `tab-action`, `send`, `notify`, `rename-tab`, `identify`, `tree`, `list-panes`). Catches cmux versions too old for kingdom v0.13.
- **King dispatch via workspace refs** — `kings.md` updated: `cmux send --workspace "$WORKER_WS_1" -- "<brief>"` replaces the broken `cmux send --lane "worker-1"` (which doesn't exist in manaflow/cmux).

### Changed

- **`commands/start.md` Phase 5 + 6** — full rewrite. PRIMARY mode uses workspace-per-master; FALLBACK (raw tmux) tightened with pane-title emoji prefixes; HEADLESS unchanged.
- **`.kingdom/.setting/kings.md` dispatch templates** — `--lane <name>` → `--workspace <ref>` everywhere; ref sourced from `$LOGS/workspace-refs.env`.
- **`.kingdom/.setting/workers.md`** — new "Spawning sub-agents — Tab vs Agent decision" section at top; 5-step closer added inline after the 4-step closer doc (5-step applies only to tab-spawned sub-agents).
- **`.kingdom/.setting/watchmans.md`** — documents the optional vertical split layout for the watchman workspace.
- **`commands/init.md`** — also scaffolds the new `cmux.md` role doc.

### Fixed

- **Broken `cmux claude-teams` reference** in `commands/start.md` — that command exists in manaflow/cmux but is a thin pass-through to `claude --print` requiring a prompt arg; kingdom doesn't use it. Replaced with `cmux new-workspace --command "claude"`.
- **`cmux pin-pane` reference** — that command doesn't exist in manaflow/cmux (it was from `craigsc/cmux`, an unrelated tool). Pinning is implicit via `--cwd` at workspace creation.
- **`cmux current-workspace` reference** — replaced with `cmux identify --json` (the actual command name).
- **`cmux send --lane <name>` reference** — `--lane` flag doesn't exist; correct flag is `--workspace <ref>` or `--surface <ref>`.

### Why this matters

Real test feedback: `/kingdom:start` errored in PRIMARY mode because `cmux claude-teams` needed a prompt arg the spec didn't provide. Investigation revealed several other commands in the spec (`cmux new`, `cmux start`, `cmux pin-pane`, `cmux current-workspace`, `--lane`) belonged to a different cmux tool entirely. v0.13.0 corrects every cmux reference + adds a central reference doc so this doesn't drift again.

### Compatibility notes

- **Breaking** for anyone who ran kingdom in PRIMARY mode on prior versions — the spec was broken; PRIMARY actually only worked if you manually edited the start.md to use tmux fallback. v0.13.0 makes PRIMARY work for the first time.
- **`kingdom.json` schema additive** — new optional `cmux` block; existing configs without it use sensible defaults (workspace-per-master, watchman split enabled, sub-agents headless).
- **Workspace refs are NOT stable across cmux.app force-quit** — kingdom persists refs to `$LOGS/workspace-refs.env`, but if cmux.app was killed (not gracefully closed), refs may need rebuilding. Doctor Check 1 flags this scenario.

---

## [0.12.0] — 2026-05-18

The "everyday workflow" release. Three small UX cleanups that fall out of real testing.

### Changed

- **`/kingdom:start` no longer accepts shape override args.** Was: `/kingdom:start <project> [workers=N] [co-workers=M] [watchman=K]` — the optional args were redundant since `kingdom.json` is the source of truth, and they cluttered the slash-menu argument hint to look more complex than it is. Now: `/kingdom:start <project>` only. To change shape, edit `.kingdom/<project>/kingdom.json` directly or re-run `/kingdom:init <project> workers=N`.
- **`/kingdom:start` confirmation prompt** dropped the "adjust counts" branch — was: `Proceed? (yes / no / adjust counts)` · now: `Proceed? (yes / no)`. Adjusting counts mid-start is no longer supported (edit `kingdom.json` instead).
- **README slash command table** — `/kingdom:start` row reflects the simpler signature with a note pointing at `kingdom.json` for shape changes.

### Added

- **`## 🔁 Resume work (5 seconds)` README section** — between First-time setup and `/kingdom:init` shape docs. Covers:
  - cmux.app persistence (close terminal, panes survive)
  - Cold restart: `claude` + `/kingdom:start my-app` (idempotent — resumes existing worktrees)
  - Away-a-while case: run `/kingdom:update` first to see Gap A / Gap B before resuming work
- **`## 🔄 Updating the plugin` README section** — after Slash commands. Two-layer flow:
  1. `/plugin update kingdom` (auto — pulls new code + templates)
  2. `/kingdom:init` (manual — re-syncs workspace role docs from new templates, asks before overwriting)

  Plus a table documenting which assets survive a plugin update (everything user-written; nothing they configured).

### Why this matters

Real test feedback (paraphrased): "the `/kingdom:start` slash hint shows `[workers=N] [co-workers=M] [watchman=K]` — those look required, but they're already in kingdom.json — confusing." Same person's other gap: "after First-time setup, the README doesn't tell me how to come back tomorrow." Both addressed in one release.

---

## [0.11.0] — 2026-05-18

The "one init to rule them all" release. Consolidates `/kingdom:init` (workspace) + `/kingdom:new` (project) into a single smart `/kingdom:init` that handles both layers args-driven. One fewer command in the kit.

### Changed

- **`/kingdom:init` now does both workspace + project scaffolding.** Args determine which mode:
  - `/kingdom:init` (no args) — workspace layer only: `.kingdom/.setting/` role docs + `.claude/settings.json` permissions allow-list (the Step 4.5 check from v0.10.0).
  - `/kingdom:init <project>` — workspace scaffold (if missing) + project layer: `.kingdom/<project>/kingdom.json` + `tasks/` + `logs/`. Optional `workers=N co-workers=M watchman=K base=<branch>` shape overrides.
  - Idempotent in both modes — re-running on existing scaffolding prints status without overwriting unless explicitly confirmed.
- **README install/setup flow simplified.** The 90-second setup section now shows `/kingdom:init my-app` as a single call that handles both layers, with a callout for users who want to run them separately. Slash command table consolidated.
- **All cross-references updated** — `commands/start.md`, `commands/update.md`, `commands/doctor.md`, `.kingdom/.setting/*.md` swept for `/kingdom:new` → `/kingdom:init` where appropriate. CHANGELOG historical entries (pre-v0.11) keep the original `/kingdom:new` names since they describe past releases.

### Removed

- **`/kingdom:new`** — retired. Its functionality is now under `/kingdom:init <project>`. The file `commands/new.md` is deleted from the plugin. Any scripts / aliases / muscle memory pointing at `/kingdom:new` need to update to `/kingdom:init <project>`.

### Compatibility notes

- **Breaking** for anyone with scripts or aliases pointing at `/kingdom:new`. Migration is a search/replace — same arg syntax (`<project> workers=N co-workers=M watchman=K base=<branch>`), just a different command name.
- **Non-breaking** for `kingdom.json` schema — same template, same fields.
- **Non-breaking** for the workspace + project scaffold output — same file layout (`.kingdom/.setting/`, `.kingdom/<project>/{kingdom.json,tasks/,logs/}`, `.claude/settings.json` permissions).

### Why this matters

Two-step setup (`init` then `new`) was an artificial split that surfaced "wait, which one do I run?" friction every time. One command, two args-driven modes — fewer things to remember, same end state, idempotent re-runs.

---

## [0.10.0] — 2026-05-18

The "settings permissions + branch tree polish" release. Fixes a real failure mode where background sub-agents stalled silently because workspace `.claude/settings.json` had no `permissions.allow` list. Also polishes the README branch model diagram and fixes a stale config example.

### Added

- **`/kingdom:doctor` Check 10 — Workspace `.claude/settings.json` permissions.** Verifies the workspace-scoped settings file has `permissions.allow ⊇ {Bash, Read, Write, Edit, Grep, Glob, Agent}`. Without this, background sub-agents spawned by `/kingdom:update`'s parallel fan-out, by worker dispatches, by watchman alerts, etc., stall on permission prompts that nobody sees — sentinels never appear, audits never complete. Auto-patches with `jq` after user approval; preserves any existing keys; dedupes the allow-list.
- **`/kingdom:init` Step 4.5 — Workspace permissions scaffold.** Same check + patch as doctor's Check 10, but runs at scaffold time so the kingdom is usable on first dispatch without a separate doctor visit. Asks before writing.

### Changed

- **README hero branch diagram** — was a minimal abstract sketch (worker-1..N → feature/topic with one arrow). Now shows a concrete worked example: 3 features in flight (`feature/auth-refactor` from worker-1, `feature/checkout-flow` from co-worker-1, `feature/db-migrate` from worker-2) with every transition labelled: `git fetch + merge` (develop → kingdom), `git worktree add` (kingdom → lanes), `King carves + push + gh pr create` (lane → feature), `PR review → squash merge` (feature → develop), `release cycle` (develop → main). Uses role emojis (👑 👷 🧑‍💼 🕵️). Adds a "What lives where" table summarising each branch's lifetime + writer + whether it reaches origin.
- **README configure example** — stale v0.4-era config with `workers[i].focus` + `ownsPaths` removed (those were deprecated in v0.5.0 — workers are now generic capacity). Example now shows the actual current schema: `workers: [{slug, model}]`, `coworkers: [{slug, model}]`, `watchmen: [{slug, model, docsAudit}]`.

### Why this matters

Real failure: a user ran `/kingdom:update bfg-swt`, the Lead dispatched 4 parallel specialists in background, and nothing ever completed. Workspace `.claude/settings.json` was empty `{}` — every Bash call from each specialist hit a permission prompt, but background mode doesn't surface them. Sentinels never wrote. The fix (add `permissions.allow`) is one line of JSON; the cost of forgetting it is total system stall. Now both `/kingdom:init` and `/kingdom:doctor` check it.

---

## [0.9.0] — 2026-05-18

The "fan out the audit, stop waiting" release. Restructures `/kingdom:update` from "Lead does steps 3.1-3.7 sequentially" to "Lead spawns 4 specialists in parallel, then synthesizes gaps". Target wall-clock: under 2 minutes for typical mid-size projects (was ~5 min sequential).

### Changed

- **`/kingdom:update` is now Sonnet Lead + 4 parallel specialists + Haiku scanner fan-out.** The 4 specialists, all dispatched in one Agent batch and polled via a single blocking Bash loop:
  - 🐱 **A · Project scanner** (Sonnet sub-Lead) — owns Step 3.0 (Layer-1 project state scan). Itself fans out ≤10 Haiku scanners reading `.md`/`.txt`/`.csv` files with 1-hop transitive reads.
  - 🐱 **B · Task reconciler** (Sonnet) — owns Step 3.1 (checkbox reconciliation against `git log`). Writes only `tasks/*.md`.
  - 🐱 **C · Logs reconciler** (Sonnet) — owns Steps 3.2 + 3.3 + 3.5 (orphan digests + log backfill + digest re-understanding flags). Writes only new `logs/<ID>.md` + appends `master_agent.log`.
  - 🐱 **D · Organization audit** (Sonnet) — owns Steps 3.4 + 3.6 (stale `[[name]]` links + merge/archive candidates). Writes only additive footnotes.
- **Disjoint write sets.** B/C/D write to non-overlapping paths, so the parallel fan-out is race-safe without locks or coordination beyond the Lead's poll-and-aggregate.
- **Lead does Step 3.7 (gap synthesis) directly** after all 4 specialists complete. Uses Specialist A's project reality picture + B's task results + C's log results. Writes the aggregate `logs/kingdom-update-<UTC>.md` with two top-level `## Gap A` / `## Gap B` sections + counts.
- **4 specialist sub-digests survive** at `logs/audit-{A,B,C,D}-<...>-<UTC>.md` — King can drill into any of them when investigating a specific section of the aggregate.

### Why this matters

Real-test feedback on v0.8.0: the audit on bfg-swt was running every step sequentially inside one Sonnet, ~5 minutes wall-clock. With 4 parallel specialists, the same audit completes in under 2 minutes (longest-running specialist gates the rest). No correctness changes — only speed. Same digest structure, same gap surfacing.

---

## [0.8.0] — 2026-05-17

The "auto-switch" patch on top of v0.7.0. Refines `/kingdom:update` Step 0.5 to remove the off-branch prompt entirely — switching to `kingdom` is a local-only no-side-effect operation, so the audit just does it.

### Changed

- **`/kingdom:update` Step 0.5 — auto-switch to `kingdom`, never prompt.** Was: prompted `continue anyway? (y/n)` on off-expected-branch (e.g., `working` / `feature/*`). Now: auto-checkout `kingdom` (creates from `origin/<base>` if missing) + merges `origin/<base>` into it. No prompt. Reasoning: `kingdom` is local-only (never pushed), so switching to it has zero side effects on the user's work — uncommitted changes either follow the checkout cleanly or git refuses the switch (in which case audit STOPS and tells the user to `git stash`, not retry-on-press-Y).
- **Dirty working tree is now informational only.** No prompt — audit always proceeds. Step 3.1 footnotes every newly-ticked checkbox with `verify manually` when matching against a dirty tree, so the trust signal is in the audit output rather than a gate at the start.
- **`--force` flag scope narrowed.** v0.7.0 used `--force` to skip dirty/off-branch prompts (now removed since there are no prompts). `--force` now serves one purpose: continue auditing on the current branch when an `origin/<base>` merge into `kingdom` produces conflicts — used for stuck-merge investigation, rare.

### Why this matters

Real test case: bfg-swt was on its sanctioned scratch branch `working` (per `bfg-swt/SPEC-Git.md`). v0.7.0 flagged this as "off-expected-branch" and asked. v0.8.0 just switches to `kingdom`, pulls develop, and runs the audit — same answer the user would have given anyway, without the round-trip.

---

## [0.7.0] — 2026-05-17

The "git-aware + role-themed" release. Two user-driven additions: `/kingdom:update` now sanity-checks git state before auditing (dirty tree or off-branch surfaces immediately), and every role gets a distinctive emoji that flows through tab titles, dispatch templates, and chat conventions.

### Added

- **`/kingdom:update` Step 0.5 — Git state precheck.** Before any audit work, verify the project worktree is clean, on a recognised branch (`base` / `kingdom` / `worker-N` / `co-worker-N` / `watchman-N`), and report drift vs `origin/<base>`. Dirty tree or off-branch triggers an interactive `continue anyway? (y/n)` prompt. New `--force` flag skips prompts (warnings still log to the audit digest). When dirty, Step 3.1 footnotes every newly-ticked checkbox with `verify manually` so you don't trust an audit run against uncommitted code.
- **`/kingdom:doctor` Check 9 — Git state across projects.** Informational across-the-board sweep — for every project with a `kingdom.json`, reports `clean|DIRTY on <branch>` + drift indicator. Doesn't block; flags projects where `/kingdom:update` will prompt.
- **Role emoji convention** — new section in `.kingdom/.setting/index.md` documenting:
  - 👑 King
  - 👷 Worker
  - 🧑‍💼 Co-worker
  - 🕵️ Watchman
  - 🐱 Sub-agent

  Convention flows through: cmux/tmux tab titles (`👑 King`, `👷 worker-1`, …), dispatch templates, log line prefixes, chat replies relaying role activity, README hero diagram, and all role docs. Emojis are used WITHOUT skin-tone modifiers for cross-terminal stability.

### Changed

- **Role docs and templates** — bulk-swapped `⚙️` → `👷` (Worker), `🤝` → `🧑‍💼` (Co-worker), `👁` → `🕵️` (Watchman), `🧩` → `🐱` (Sub-agent) across `README.md`, `.kingdom/.setting/*.md`, and Mermaid hero diagrams. King's `👑` is unchanged.
- **`commands/start.md` Phase 6** — pane title setup now uses role-emoji prefixes (`cmux rename-tab "👷 worker-1"`, `tmux select-pane -T "👑 King"`, etc.) for visual scan-ability in the sidebar / pane-border-status row.

---

## [0.6.0] — 2026-05-17

The "learn first, then update" release. `/kingdom:update` becomes a true Layer-1 Discovery pass — it reads the project's own docs before reconciling logs/tasks, so the audit catches gaps between what the project claims and what the kingdom recorded. Also fixes a real over-count bug in `/kingdom:doctor` Check 8.

### Added

- **`/kingdom:update` Step 3.0 — Project state scan (Layer-1 fan-out).** Audit Lead (Sonnet) now spawns Haiku scanners in parallel (≤10) to read every `.md` / `.txt` / `.csv` file in the project tree. Each scanner extracts completion markers (`[x]`, `✅`, `Status: done`, "Shipped on YYYY-MM-DD", dated done-bullets), pending markers, and cross-file references. **Transitive read (1 hop):** when a file flags a referenced doc as load-bearing for completion status, the scanner reads that doc too — but no deeper, preventing recursion blow-up. Excluded dirs: `.git/`, `node_modules/`, `.next/`, `dist/`, `build/`, `.venv/`, `__pycache__/`, `.kingdom/`.
- **`/kingdom:update` Step 3.7 — Gap synthesis.** Cross-references the project reality picture against `master_agent.log` + `tasks/*` + curated digests. Two new sections in every audit digest:
  - `## Gap A — Project says done, kingdom has no record` — surfaces out-of-band work (manual commits, ad-hoc changes) where the project doc claims completion but no kingdom log entry exists.
  - `## Gap B — Kingdom logged it, project docs don't reflect it` — surfaces docs that need updating after shipped work.
- **King action table** (in `kings.md` → "Reviewing watchman audit findings") gets two new rows for Gap A and Gap B with the recommended follow-up per row (backfill log line vs dispatch doc-update task).
- **Watchman project-state scan (bounded)** — watchman's idle docs audit now does a small 5-file scan of project docs per tick, contributing to `## Gap A` / `## Gap B` sections of `WATCH_DOCS_AUDIT.md`. Flag-only — never edits project source.

### Changed

- **`/kingdom:update` is now Sonnet Lead + Haiku fan-out.** Mechanical reconcile (Steps 3.1-3.6) still happens, but the new Step 3.0 fan-out and Step 3.7 gap synthesis make the audit a proper Discovery pass — not just a mechanical sweep. Lead stays Sonnet; Haiku for parallel reads; Opus reserved for King-dispatched digest rewrites (Step 3.5 follow-up).
- **`/kingdom:doctor` Check 8 orphan-counting heuristic** — was using naïve `cut -d'_' -f1-2` which over-counted when raw filenames had lane-shard suffixes (e.g. `__kimi-p<N>`). Now strips known shard suffixes (`__kimi-p<N>`, `__shard-<N>`, `__pane<N>(-…)?`) before matching, then falls back to `<UTC>` timestamp-prefix match for leftovers. Tested case: bfg-swt audit dropped from 19 false-orphans → 12 actual orphans.

### Fixed

- File-path corruption from the v0.4.0 rename — `kingdom-update-<UTC>.md` filenames in `commands/update.md` had been incorrectly rewritten to `kingdom:update-<UTC>.md` (colon) by an over-broad sed. Restored to hyphen form.

---

## [0.5.0] — 2026-05-17

The "generic workers, any domain" release. Workers are no longer pre-specialised — every worker is identical capacity. King assigns task scope at dispatch time. Bonus: the kit is now explicitly domain-agnostic — code, research, finance, science, manuscripts.

### Changed

- **Workers are generic capacity.** Removed `workers[i].focus` and `workers[i].ownsPaths` from `kingdom.json` (and the same for `coworkers[i]`). Every worker starts identical; `worker-1` and `worker-2` are interchangeable. Same worker can do backend today, frontend tomorrow, finance-model audit the day after.
- **King assigns task scope per dispatch**, not per config. New "Dispatch brief schema" section in `kings.md` documents what King sends each worker. Cross-lane conflict prevention shifted entirely to (a) King's Layer-1 planning (sub-agents scan candidate task overlap) + (b) FINAL `git merge-tree` check at push gate. The combination replaces what `ownsPaths` did in v0.4.0 without the path-staleness problem.
- **`gate.*` keys are now explicitly arbitrary.** Template still ships `typecheck`/`tests`/`smoke`/`lint` as dev-friendly defaults, but role docs + template comments make clear the keys are user-defined. Finance kingdoms use `validate`/`audit`; science kingdoms use `reproduce`/`peer-review`; writing kingdoms use `spellcheck`/`fact-check`. Same `kingdom.json` schema, different vocabulary.
- **Domain-agnostic framing.** README hero + tagline + workers.md now state explicitly: kingdom works for any domain that uses git for versioning, not just software dev.
- **`kingdom.json.template` simplified.** Per-lane entries now have only `slug` + `model` (was: `slug` + `model` + `focus` + `ownsPaths`). Significantly smaller, faster to read.

### Compatibility notes

- **Breaking** for anyone who has filled in `workers[i].focus` or `workers[i].ownsPaths` in their `kingdom.json` for v0.4.0 or earlier. Migration:
  ```bash
  # Open .kingdom/<project>/kingdom.json
  # Delete every "focus" and "ownsPaths" key from workers[] and coworkers[]
  # Leave shape + git + gate untouched
  ```
  No re-install needed; the schema change is read-side only.
- **Non-breaking** for v0.4.0 users who did NOT customise focus/ownsPaths.
- **Behavioural change:** King now writes scope into each dispatch brief (lives in the task file at `tasks/<UTC>__<lane>__<id>.md`, not in `kingdom.json`). Audit trail is per-task instead of per-config — finer-grained, no staleness.

---

## [0.4.0] — 2026-05-17

The "rename" release. Drops the `claude-` prefix everywhere — plugin name, marketplace name, GitHub repo, and command names. Slash commands now read `/kingdom:doctor` instead of `/claude-kingdom:kingdom-doctor`.

### Changed

- **Plugin name** — `claude-kingdom` → `kingdom`. The slash-command namespace prefix is now `/kingdom:` instead of `/claude-kingdom:`. Reads cleaner and matches the brand.
- **Marketplace name** — `claude-kingdom` → `kingdom`. Install becomes `/plugin install kingdom@kingdom` (plugin@marketplace, both `kingdom`).
- **GitHub repo** — `chatthong/claude-kingdom` → `chatthong/kingdom`. Old URL auto-redirects via GitHub.
- **Command files** — dropped the redundant `kingdom-` prefix. The plugin namespace already provides the qualifier:
  - `commands/kingdom-doctor.md` → `commands/doctor.md` (slash: `/kingdom:doctor`)
  - `commands/kingdom-init.md` → `commands/init.md` (slash: `/kingdom:init`)
  - `commands/kingdom-new.md` → `commands/new.md` (slash: `/kingdom:new`)
  - `commands/kingdom-start.md` → `commands/start.md` (slash: `/kingdom:start`)
  - `commands/kingdom-update.md` → `commands/update.md` (slash: `/kingdom:update`)
- **All docs** — README, CHANGELOG intro, role docs in `.kingdom/.setting/`, CMUX-Guide.md, TMUX-Guide.md — all references to `/kingdom-<cmd>` updated to `/kingdom:<cmd>`.

### Compatibility notes

- **Breaking** for anyone on v0.3.x or earlier. To upgrade:
  ```
  /plugin marketplace remove claude-kingdom
  /plugin uninstall claude-kingdom
  /plugin marketplace add chatthong/kingdom
  /plugin install kingdom@kingdom
  ```
  Any of your scripts, aliases, or notes referencing `/kingdom-doctor` (etc.) need to become `/kingdom:doctor`.
- **GitHub auto-redirect** — `github.com/chatthong/claude-kingdom` still resolves to the new location, so old clones can `git remote set-url origin https://github.com/chatthong/kingdom.git` to keep working.
- **No functional changes** — every command does exactly what it did in v0.3.0. Pure rename.

---

## [0.3.0] — 2026-05-17

The "audit safety net" release. Adds a forced sweep command + extends watchman with scoped write authority for idle-time docs cleanup. Also adds `marketplace.json` so the repo is installable directly via `/plugin marketplace add chatthong/kingdom`.

### Added

- **`.claude-plugin/marketplace.json`** — makes this repo serve as its own single-plugin marketplace. Install flow is now `/plugin marketplace add chatthong/kingdom` followed by `/plugin install kingdom@kingdom`. (Local-path install — `/plugin install /path/to/repo` — still works for development.)
- **`/kingdom:update`** — new slash command that forces a docs/log/task audit pass on one project. Spawns a Sonnet sub-agent that re-reads every task file in `.kingdom/<project>/tasks/`, cross-checks each checkbox against `git log`, backfills orphan raw artifacts (raw with no curated digest), repairs missing `master_agent.log` summary lines, and flags higher-risk items (stale digests, merge candidates, archive candidates, suspect entries) for King review. Idempotent; current project only.
- **Watchman docs audit duty** — new section in `watchmans.md` granting watchman scoped write authority on its own project's `tasks/`+`logs/` for low-risk fixes during idle `/loop` time (stale checkboxes, missing log lines, dead `[[name]]` links). Higher-risk findings (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md` for King review.
- **`WATCH_DOCS_AUDIT.md`** — new single-file-per-project rolling artifact at `<workspace>/.kingdom/<project>/logs/WATCH_DOCS_AUDIT.md`. Watchman appends findings; King reviews + clears bullets after acting.
- **"Reviewing watchman audit findings" section** in `kings.md` — documents how/when King consumes `WATCH_DOCS_AUDIT.md` and what to do with each finding category.
- **`/kingdom:doctor` Check 8** — informational scan for orphan raw artifacts (raw with no curated digest). Suggests `/kingdom:update` when found.
- **README FAQ entries** — `/kingdom:update` purpose + watchman write-authority scope.

### Changed

- **Watchman is no longer purely read-only.** Watchman now has WRITE authority scoped to `<workspace>/.kingdom/<project>/{tasks,logs}/`, low-risk fixes only. Project source code, role specs, `kingdom.json`, and `.git/` remain forbidden.
- **Role Control table in `index.md`** — watchman row's `Writes` cell expanded to include `WATCH_DOCS_AUDIT.md` + low-risk fixes during docs audit duty.
- **Watchman's "What watchmen DO / DO NOT do" tables** — clarified that source code remains read-only; low-risk audit writes are allowed; high-risk audit fixes (digest rewrite, merge, archive, role-doc rewrite) are flag-only.

### Compatibility notes

- **Behaviour change** — anyone running v0.2.x watchmen will see the watchman make small edits to `tasks/*.md` and `master_agent.log` during idle time. These are bounded (newest 20 task files + 20 digests per scan) and always low-risk. To opt out, set `watchmen[i].docsAudit = false` in `kingdom.json` (defaults to `true`).
- **Non-breaking** for `kingdom.json` schema — the new `docsAudit` field is optional and defaults to enabled.
- **`WATCH_DOCS_AUDIT.md` is new** — existing kingdoms won't have one until watchman's next idle tick creates it.

---

## [0.2.0] — 2026-05-17

The "actually opinionated" release. Major architectural changes that lock in how the kingdom thinks about work, model selection, and audit trails.

### Added

- **Task files** — new per-task audit artifact at `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`. Checkbox doc capturing the multi-layer plan (Discovery → Strategy → Execution → Verification), in-progress progress notes, and final summary. Lane master is sole writer; sub-agents and everyone else read only. One file per task; never deleted, never reused.
- **Multi-layer planning** — explicit recursive fan-out pattern in lane master execution. Layer 1 (Discovery, Haiku fan-out) → Layer 2 (Strategy, Sonnet/Opus) → Layer 3 (Execution, Sonnet parallel) → Layer 4 (Verification). Documented as the canonical pattern in `workers.md`; cross-referenced from `kings.md`, `co-workers.md`, `index.md`.
- **Role Control authoritative table** in `index.md` — single source of truth for what each role can/can't do (writes / reads / spawns / pushes / edits / plans). Per-role files now document HOW; this table defines WHAT.
- **Auto-detect outer host mode** — `/kingdom:start` and `/kingdom:doctor` now auto-detect PRIMARY (manaflow/cmux.app) vs FALLBACK (raw tmux) vs HEADLESS (`claude -p`). No user config needed; King adapts to what's installed.
- **Native Mermaid diagrams** — every ASCII chart in role docs, README, and git.md converted to Mermaid (16 diagrams total: 2 in README + 4 in git.md + 4 in kings.md + 3 in workers.md + 2 in watchmans.md + 1 in co-workers.md + 1 in index.md). No theme directive — GitHub auto-adapts to user's light/dark theme.
- **King's own task files for planning sessions** — slug `king-plan` (e.g., `2026-05-17T0900Z__king-plan__pick-todays-3-tasks.md`). Same schema as lane-master task files.
- **CHANGELOG.md** (this file).

### Changed

- **Lane master model defaults** — Worker and Co-worker now default to **Opus** (was Sonnet). King is unchanged (Opus). Watchman remains Sonnet (passive monitor; doesn't need top-tier reasoning). Sub-agents continue to follow the P1/P2/P3 chain (Sonnet/Haiku/Opus).
- **Priority chain semantics clarified** — "P1 = Sonnet (default)" now explicitly applies to sub-agents only, not to lane masters. Two-tier framing documented in `index.md`.
- **Repo layout restructured** to mirror the consumer workspace layout:
  - `templates/role-files/*.md` → `.kingdom/.setting/*.md`
  - `templates/kingdom.json.template` → `.kingdom/templates/kingdom.json.template`
  - Slash commands updated to reference the new paths.
- **README rewritten** — replaced the "What a session looks like" transcript with role intros ("Meet the King — and the masters that work for it"). Expanded `/kingdom:new` documentation to a 5-use-case block (mid-size, large, solo, UI-heavy, unattended) with concrete `workers=N co-workers=M watchman=K` examples. Added FAQ entry for task files.
- **All worker / co-worker slug examples** swapped from `sonnet-worker-1` to `opus-worker-1` to match the new model defaults. Watchman slugs remain `sonnet-watchman-1`.
- **kingdom.json.template** — each `workers[i]` and `coworkers[i]` entry now has explicit `"model": "opus"`; each `watchmen[i]` entry has `"model": "sonnet"`. `_comment` documents the convention.

### Removed

- **craigsc/cmux dependency** — kingdom no longer requires the worktree-CLI wrapper. Worktree management now uses plain `git worktree add/remove` (built into git ≥ 2.5). One less install step; no PATH collision risk.
- **"What a session looks like" transcript** in README — replaced with the role intro section (see Changed).
- **Common shapes table** in README's `/kingdom:new` section — replaced with 5 per-use-case blocks (each its own emoji + heading + code block) for cleaner rendering at narrow widths.
- **AGENTS.md mirror pattern** — never used in v0.x; kit is Claude-only. Documented retirement in role files.

### Fixed

- Stale `templates/role-files/` and `templates/kingdom.json.template` path references in slash commands and README after the layout restructure.
- Inconsistent model labels across role docs (some still said "Sonnet" for lane masters after the Opus default was set).
- README's branch-model ASCII diagram had wrapping issues at narrow viewports → replaced with side-by-side Mermaid subgraphs.

### Compatibility notes

- **Breaking** for anyone who installed v0.1.x and customised paths under `templates/role-files/` — those moved to `.kingdom/.setting/`. Re-run `/kingdom:init` after upgrading to pick up the new layout.
- **Non-breaking** for anyone who used v0.1's `kingdom.json` — schema is additive (new optional fields, defaults kept compatible).
- **Behaviour change**: Worker / Co-worker lanes now spawn Opus by default. Cost-per-lane increases. Override in `kingdom.json.workers[i].model` if you want Sonnet for cost reasons (Sonnet is still valid for these roles; just no longer the default).

---

## [0.1.0] — 2026-05-16

Initial public release.

### Added

- 4 slash commands: `/kingdom:doctor`, `/kingdom:init`, `/kingdom:new`, `/kingdom:start`.
- 6 role docs in `templates/role-files/`: `index.md`, `kings.md`, `workers.md`, `co-workers.md`, `watchmans.md`, `git.md`.
- `kingdom.json.template` config template.
- `CMUX-Guide.md` (manaflow/cmux reference).
- `TMUX-Guide.md` (tmux 101 for the fallback path).
- README with install + usage + role overview.
- LICENSE (MIT).
