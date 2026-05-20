# rules.md — Priority-tiered kingdom rules

> **Read this FIRST at session start, before everything else.**
> Three tiers; each tier dominates lower tiers when they conflict.
> When in doubt, default to the most conservative interpretation —
> the user would rather you ask 10 times than violate Tier 1 once.

---

## 🔴 Tier 1 — IRON-CLAD (never violate, ever, no override)

Violating Tier 1 = kingdom is worse than running solo.

### R1. Push approval is single-shot + PR-specific

Every `git push` and every `gh pr create` requires a **FRESH, EXPLICIT, PR-specific** approval from the user for the SPECIFIC PR shown in the immediately preceding King prompt. Approval from prior turns NEVER carries over.

| Word | Counts as push approval? |
|---|---|
| `push` (replying to a King prompt showing one PR) | ✅ — for that one PR |
| `push all` (replying to a King prompt showing a batch) | ✅ — for that exact batch |
| `push #N` or `push <branch>` (matches the prompt) | ✅ |
| `yes` / `ok` / `go` / `fire` / `proceed` / `do it` / `🆗` / 👍 / `approve` | ❌ — not push |
| Approval from a prior turn (even 30s ago) for a different action | ❌ |
| Inferred consent ("the user said fire all earlier") | ❌ — fire all was for THAT action, NEVER for push |
| Silence interpreted as default-allow | ❌ |
| Auto-pushing the Nth PR because the user approved the (N−1)th | ❌ — every PR needs fresh approval |

If you (King) are EVER unsure whether you have explicit push approval for THIS specific PR right now — **don't push. Ask again.**

### R2. Never force-push to `main` or `develop`

Period. No exceptions.

### R3. Never `--no-verify` to skip hooks

If a hook fails, fix the hook. Bypassing hooks bypasses the team's safety contract.

### R4. Never edit or commit on `kingdom` branch

Kingdom is the working-tree overlay (v0.17.0+). Pattern: `git reset --hard origin/develop` → overlay lanes via `git apply` → review → `git restore .`. NO commits on kingdom. NO `git merge --no-ff worker-N` on kingdom.

### R5. Destructive ops require explicit confirmation

`rm -rf`, `git reset --hard`, `git branch -D`, `git stash drop`, `git worktree remove --force`, schema migrations, dropping a database table, killing a long-running process — all require explicit confirmation that includes the **specific target**. "Yes go ahead" is not enough; the response must reference what's being destroyed.

### R6. Never push local-only branches

`worker-N` / `co-worker-N` / `watchman-N` / `kingdom` stay LOCAL. Only `feature/<topic>` reaches origin, and only after R1.

### R7. Never paste personal notes verbatim

`TER.md` / `TER_*.md` / similar are private. Read for situational awareness; summarise into chat when relevant; **NEVER paste verbatim, never commit, never reference content in commit messages or PR bodies.**

---

## 🟡 Tier 2 — STRONG DEFAULTS (require explicit override to break)

Tier 2 is how the kingdom operates by default. Override per-task via the dispatch brief, but the default holds.

### R8. Pattern grep before implementation (v0.17.2+)

Default stance: the project HAS a pattern. Burden of proof on the worker to demonstrate one doesn't exist via grep evidence. See [`workers.md`](workers.md) § Layer 1 Discovery.

### R9. `feature/<topic>` = `worker-N` tip byte-for-byte (v0.16.3+)

Never add commits on the feature branch after carving. Extra content goes on `worker-N` first (Option A) or a separate PR (Option B). See [`kings.md`](kings.md) § STRICT `feature/<topic>`.

### R10. Big work auto-delegated (v0.16.0+)

Anything >3 file edits OR >5 min estimated OR code-touching → King dispatches to a worker, never inlines. King's manual scope: chat + planning + gate + push + small reads.

### R11. Watchman is read-only on project source

Has scoped write authority on `.kingdom/{tasks,logs}/` for low-risk audit only (v0.10.0+). NEVER edits project source code, role specs, `kingdom.json`, or `.git/`.

### R12. Every per-task artifact carries the lane in segment 2 (v0.15.2+)

`tasks/<UTC>__<lane>__<id>.md`, `logs/<UTC>__<lane>__<id>.md`, `logs/raw/<UTC>__<sub>-<lane>__<id>.md`, `logs/done/<UTC>__<sub>-<lane>__<id>.flag`, `docs/test-reports/KING_<UTC>__<lane>__<id>.md`. Grep contract: `ls *__worker-3__*` returns lane's full history.

### R13. Two-tier gate (v0.16.0+)

Tier-1 (typecheck only, in lane worktree) → Tier-2 (full tests on kingdom overlay) → push approval requires Tier-2 pass + fresh R1 approval.

### R14. King reads ALL context at session start (v0.14.8+ · expanded v0.19.0)

In order, BEFORE any action:

0. **`rules.md`** (this file) — priority-tiered rules
1. **Workspace `CLAUDE.md`** at `$PWD/CLAUDE.md` — workspace rules + project map
2. **Project `CLAUDE.md`** at `$PWD/<project>/CLAUDE.md` — local stack + gate commands + project-specific rules
3. **Project `README.md`** at `$PWD/<project>/README.md` — public-facing overview, install, conventions
4. **Project `docs/`** index — `ls $PWD/<project>/docs/` + read any `README.md` / `index.md` / similar entry-points if present
5. **`~/.claude/projects/<workspace-key>/memory/MEMORY.md`** — durable preferences + feedback rules
6. **Personal notes** (`TER.md`, `TER_*.md` at workspace OR project root) — read for situational awareness; **NEVER paste verbatim** (R7), never quote in commits / PRs / chat
7. **Watchman state** — newest `WATCH_*.md` reports + `WATCH_DOCS_AUDIT.md` + `watchman_state.json`

Synthesise into a "Context loaded" daily-kickoff message before dispatching anything. See [`kings.md`](kings.md) § Daily kickoff routine for the canonical synthesis format.

### R15. Mandatory kingdom merge before push prompt (v0.15.1+)

After gate-pass, King overlays the lane onto kingdom + prints review surface + asks the user to review BEFORE asking R1 push. No "gate passed → push?" — always "gate passed → review on kingdom → push?".

### R16. King never sits on un-gated sentinels (v0.14.10+)

Sentinel exists + no matching test report exists → King auto-fires the gate without asking. Auto-gate ≠ auto-push; push still requires R1.

### R30. King is ORCHESTRATOR ONLY — never executes task work itself — Tier 1 (v0.24.0+)

**Allowed King verbs:** plan-the-day, dispatch (`cmux send`), gate-fire (`run_tier1_gate` / `run_tier2_gate`), overlay onto kingdom, request push approval, read audits.

**BANNED King verbs:**

- Write or edit project source code
- Make scoping decisions in chat ("Admin dropped from FE-P0-FOUND.5", "Batch 1: dev_data.sql + ...", etc) — scoping happens in the **task file** written by the lane, not in chat
- Run gates manually for a lane (lane's Tier-1 fires inside the lane's worktree)
- Draft "Worker-N plan (final)" multi-batch tables in chat — that's a lane's `## Plan` section in its task file
- Pause to "brainstorm" implementation details with the user — those decisions belong in the lane's Layer-2 Strategy after dispatch

**Incident that motivated this rule (2026-05-19):** a King session spent ~1m48s "Crunched" drafting a 9-batch execution plan for `FE-P0-FOUND.5` in chat — files to touch, scope decisions (admin in/out), AC flip targets, verification steps — instead of dispatching to worker-1. Zero tasks completed in the session. Cause: King was acting as worker. Fix: this rule, plus R31 (verify lanes exist before dispatch) and R32 (workers don't "wait").

**Hard time budget:** from `/kingdom:work` Step 4 reaching auto-dispatch, **no more than 60 seconds** elapses before the first `cmux send` fires to a worker. If King exceeds 60s of "planning in chat" between audit-done and first dispatch, that's a violation — re-read this rule and dispatch with whatever plan exists.

### R31. Lane infrastructure MUST be spawned + verified BEFORE any dispatch — Tier 1 (v0.24.0+, expanded v0.25.0)

The kingdom can run in **three modes** for lane dispatch (per memory `feedback_kingdom_cmux_dispatch_fallback.md`):

| Mode | Lane backing | Verification source-of-truth |
|---|---|---|
| **PRIMARY** (cmux.app) | `cmux new-workspace` per lane | `workspace-refs.env` + `cmux tree --all` shows alive |
| **FALLBACK** (tmux) | `tmux new-session -d -s kingdom-<project>` + windows | `tmux ls` shows the session |
| **AGENT** (in-process) | `Agent(subagent_type=...)` sub-agents inside King's session | `.worktrees/<lane>/` directories exist + lane branches exist |

**In ALL modes, the `.worktrees/<lane>/` directories MUST exist BEFORE dispatch.** That's the universal truth: worktrees = lanes exist for git purposes. The cmux refs / tmux session / Agent calls are mode-specific dispatch mechanisms ON TOP of worktrees.

**Verification sequence (in this order):**

1. **`.worktrees/<lane>/` directories exist** for every lane in `kingdom.json.shape` — `ls .worktrees/worker-1 .worktrees/worker-2 ...`. If missing, run `git worktree add` (idempotent).
2. **Mode-specific dispatch mechanism is alive:**
   - PRIMARY: `workspace-refs.env` lists every lane + `cmux tree --all` shows them.
   - FALLBACK: `tmux ls | grep kingdom-<project>` matches.
   - AGENT: no extra check (in-process, always available; just confirm worktrees from step 1).
3. **Render `spawn-complete` card** so the user visually confirms shape (cmux sidebar for PRIMARY, tmux session list for FALLBACK, "Agent fallback mode" notice for AGENT) BEFORE dispatch begins.
4. Only after Step 3 does any dispatch fire.

**Silent-failure pattern this prevents:** King writes a beautiful dispatch brief, sends to a target that doesn't exist (missing workspace ref, dead tmux session, missing worktree). Dispatch returns success. No lane ever receives the brief. King polls for a sentinel that will never appear. Hours wasted.

**Mode detection:** if PRIMARY checks fail but worktrees exist, fall back to AGENT mode (King uses `Agent(subagent_type=general-purpose, prompt="cd .worktrees/<lane> && ...")` — same brief, no cmux required). Don't insist on cmux when worktrees already exist; that's the gap that wasted ~5 minutes of "lanes not spawned" investigation when worktrees were sitting there the whole time.

**Incident sequence (2026-05-19):**
- Session A (early): King session ran without ever spawning lane workspaces. Sidebar had ONE pane. All "dispatches" landed in the void. User: "since morning still 0 job."
- Session B (later same day, after v0.24.0): K31 fired (workspace-refs.env missing) and triggered a spawn flow — but `.worktrees/` already had all 5 lanes from a prior PRIMARY session. King could have used AGENT-mode dispatch immediately; instead it considered spawning 5 fresh cmux workspaces, ran ~5m of investigation, then printed a manual kickoff brief. User: "it not even seek for kingdom latest job."

The fix: R31 now treats `.worktrees/` as the canonical "lanes exist" check; cmux refs are the PRIMARY-mode overlay, not the only valid form.

### R32. "Staged / waiting / dormant" is co-worker-ONLY — workers auto-claim — Tier 2 (v0.24.0+)

Per-role idle behaviour:

| Role | Idle behaviour |
|---|---|
| 👷 **Worker** | **Auto-claim** from queue per `kings.md` § Lane utilisation. If queue empty, lane shows `🐾 Idle` but King keeps polling for new pending tasks (Step 5c of `/kingdom:work` poll loop). Worker NEVER sits "awaiting your dictation". |
| 🧑‍💼 **Co-worker** | **Dormant by default.** Activates only when user says `pair on co-worker-N`. Shows `💤 staged · awaiting pair-on signal`. This is the ONLY role where "waiting for user input" is correct. |
| 🕵️ **Watchman** | **Always runs `/loop`.** Never idle, never waiting. Dynamic-pacing (5-15 min) means it's "asleep until next tick" — that's different from "waiting on user." |

**Anti-pattern:** chat shows `worker-1 awaiting your dictation` or `worker-2 staged · waiting for direction`. Both are bugs. Workers don't wait — they pull. If no task fits worker-1's slot, dispatch it the next-best one, or mark it `🐾 idle (no claimable task)` and re-poll on the next cycle.

**The morning of 2026-05-19 incident:** King treated worker-1 like a co-worker, "pausing" for user direction on scope decisions instead of dispatching it the task with the brief and letting Layer-2 Strategy happen inside the lane. That's R32 violation + R30 violation simultaneously.

### R33. King MUST read existing task state BEFORE dispatching new tasks — Tier 1 (v0.25.0+)

At session start (per R14) and at every `/kingdom:work` Step 4 dispatch round, King MUST scan existing task state and **resume in-flight work before opening any new task file**:

1. **`ls -t .kingdom/<project>/tasks/*.md`** — newest first.
2. For each task file: read `## Status` checkboxes. Classify:
   - `done` / `cancelled` → ignore.
   - `planning` / `executing` / `verifying` (no matching sentinel in `<LOGS>/done/`) → **resume queue**.
   - `blocked` → **decision queue** (lane needs user input or dependency resolution).
3. **Resume queue takes priority over new dispatch.** Lanes already in-flight get re-briefed with `[RESUME]` flag + same task ID + their last `## Progress notes` line. NEVER open a fresh task file for a lane that already has an in-flight one.
4. **Decision queue items get surfaced in the `suggested-task` card** with `→ Unblock <task-id>` as a candidate so the user can resolve before new work loads.
5. Only AFTER resume + decision queues are addressed does Step 4 auto-dispatch reach for new tasks from the project ledger.

**Render** the `resume-queue` card (new in v0.25.0) right after `daily-status` if any in-flight task files exist.

**Anti-pattern:** King ignores `.kingdom/<project>/tasks/2026-05-19T0353Z__worker-1__FE-P0-FOUND.5.md` (status: discovery-complete, 2 soft blockers), starts drafting a fresh dispatch for worker-1 from scratch. Now worker-1 has TWO task files for overlapping work, the old one rots, sentinels mismatch, audit-trail corrupts.

**Why Tier 1:** ignoring in-flight task files = orphaning real work + duplicating effort + confusing the audit trail. This is correctness, not cosmetic.

**Incident that motivated this rule (2026-05-19):** King session greeted user with "Suggested next tasks:" candidates pulled from the project ledger, while `.kingdom/bfg-swt/tasks/` had a worker-1 task file from the morning with Status=discovery-complete waiting on 2 user-decision blockers. The right behaviour: open with "Resume worker-1 FE-P0-FOUND.5? Two blockers need your call: A=<X> B=<Y>" — that's both decision-queue item + resume candidate in one prompt. King missed it entirely because R14 read-order didn't enforce reading task state, only meta-state (memory, watchman state, README).

### R34. Tier-1 rules override memory notes — Tier 1 (v0.26.0+)

`MEMORY.md` entries and `feedback_*.md` files in the user's auto-memory are **advisory context**, NOT authoritative protocol. They describe past preferences / observations. When a memory note suggests behaviour that contradicts a Tier-1 rule (R1-R7, R22, R23, R30, R31, R33, this rule, R35), **the rule wins**.

**Examples of contradiction that the rule must win:**

| Memory note says | Tier-1 rule says | Correct action |
|---|---|---|
| `feedback_kingdom_cmux_dispatch_fallback.md`: "if cmux send fails, pivot to Agent()" | R31: spawn cmux workspaces BEFORE dispatch (any mode) | **Spawn cmux workspaces.** The memory note covers a *dispatch-time* fallback after spawn succeeded but `cmux send` failed — NOT a session-start excuse to skip spawning entirely. |
| `feedback_no_performative_apology.md`: "never say 'you're absolutely right'" | R30: King acknowledges its own violations | **Acknowledge the violation factually.** Memory note bans performative apology, not factual self-correction. ("I violated R31 by not spawning. Repairing now.") |
| `feedback_solo_vs_tmux.md`: "work solo by default" | R31: spawn lane workspaces on `/kingdom:work` | **Spawn the workspaces.** `/kingdom:work` is the explicit multi-lane ritual; the memory note covers default chat behaviour, not the dispatch flow. |

**Anti-pattern caught 2026-05-19:** King read `feedback_kingdom_cmux_dispatch_fallback.md` at session start (per R14) and interpreted it as "skip cmux spawn this session." That conflated a `cmux send` failure mode with a `cmux new-workspace` failure mode. R31 says spawn-then-dispatch; the memory's pivot is dispatch-time, not spawn-time. King self-acknowledged after user WTF'd: "I read that as 'skip cmux spawn this session too.' That was wrong."

**Why Tier 1:** memory drift over time + Tier-1 rules being the spec's safety bedrock means memory cannot be allowed to silently shadow rules. If a memory note actually contradicts a rule going forward, **update the rule or update the memory** — don't let one quietly override the other in practice.

### R35. King never copies uncommitted changes between worktrees — Tier 1 (v0.26.0+)

Each lane's `.worktrees/<lane>/` is **its own work surface**. King's allowed cross-worktree operations are:

✅ **Read** any worktree (`cat .worktrees/<lane>/path/to/file`) for audit/dispatch context.

✅ **`git diff origin/<base>..<lane> | git apply --3way -`** onto kingdom's working tree (R4 overlay for review; never commits on kingdom).

❌ **BANNED:** `cp .worktrees/worker-1/some-file .worktrees/worker-2/some-file` (or any other file-move/copy between lane worktrees).

❌ **BANNED:** committing into a lane's branch any content that wasn't authored by that lane (whether by King's own hand, or copied from another lane, or pulled from an external scratch dir).

**Why:** R30 says King is orchestrator-only. Copying uncommitted content from worker-1 → worker-2 + committing on worker-2's branch makes King the author of worker-2's commit. That's worker work. The audit trail says "worker-2 did this work" but the actual editor was King. Future blame / debugging / review goes to the wrong agent.

**Correct alternative:** dispatch a brief to worker-2 explaining what the change should be. Let worker-2 author the change in its own worktree from its own context. If the change is "literally copy this Dockerfile from worker-1," the brief says so explicitly — but worker-2 does the copy + commit.

**Edge case — shared infrastructure files (Dockerfile, ci.yaml, package.json) that multiple lanes need:** the change goes to ONE lane (whichever owns the file per the task), gets reviewed, gets merged to develop, then other lanes rebase. Don't cross-pollinate uncommitted shared files between lanes via King.

**Anti-pattern caught 2026-05-19:** King authored Dockerfile changes (3 ENV lines + 4-line comment for `@workspace/db` build-env placeholders) on worker-1's worktree, then `cp`'d the modified Dockerfile to `.worktrees/worker-2/` and included it in worker-2's commit as "part of the @workspace/db enabling slice." King defended: "the modification was already in your worker-1 worktree when I scanned" — but that's not exculpatory; King STILL did the cross-worktree copy + commit on the wrong lane. The proper move would have been: leave the Dockerfile change on worker-1 OR dispatch worker-2 to make the change in its own worktree.

**Why Tier 1:** breaks the per-lane authorship invariant that the entire audit trail (master_agent.log, sentinel-to-commit mapping, blame) depends on. Once King is a hidden author on lane branches, "who did this" stops being a clean question.

### Self-detect: when King catches its own violation

If King realises it has violated R30 / R31 / R33 / R35 (or any other Tier-1 rule) mid-session:

1. **STOP immediately.** Don't continue down the violating path.
2. **Acknowledge in chat factually.** ("I violated R31 — I didn't spawn cmux workspaces despite worktrees existing in AGENT-mode-mistaken state. Repairing now.")
3. **Repair.** Re-run the violated step correctly (spawn cmux now, dispatch the missing brief, revert the cross-worktree commit, etc).
4. **Log to master_agent.log:** one line `[UTC] RULE_VIOLATION R<N> · <one-line description> · repaired by <action>`.
5. **NEVER continue dependent work without repair.** If R31 was violated by skipping spawn, do NOT proceed to Step 4 dispatch until spawn is corrected.

Per R34, performative apology is still banned. Acknowledgement is factual + repair-focused.

### R41. Auto-discover and use the right skill BEFORE any work — Tier 1 (v0.29.3+)

At the START of any task — King's daily ritual kickoff AND every lane's task receipt — the actor MUST resolve a skill set before writing code, designing, or dispatching:

**Resolution order:**

1. **Fast path: routing table.** Run `pick_skills_for_task` against [`skill-routing.md`](skill-routing.md). If it returns 1-3 matches, use them.
2. **Fallback: system-reminder skill list.** If routing table returns 0 matches, list the skills surfaced in the current session's system reminders (or `Skill` tool catalog), match by description-keyword similarity to the task domain, pick best fit.
3. **No-skill is valid.** If neither path produces a confident match, skip — don't invoke a vaguely-related skill just to invoke something. False-positive loads pollute context.

**Domain → skill quick map (most-used):**

| Task domain | Skills to invoke (priority order) |
|---|---|
| Frontend / Next.js / UI | `nextjs-best-practices`, `shadcn`, `shadcn-ui`, `tailwind-design-system`, `frontend-design`, `oklch-skill` |
| Database / Prisma | `prisma-cli`, `prisma-client-api`, `prisma-database-setup`, `prisma-postgres`, `prisma-postgres-setup`, `prisma-upgrade-v7`, `prisma-driver-adapter-implementation` |
| Supabase / Postgres | `supabase:supabase`, `supabase:supabase-postgres-best-practices` |
| Stripe / Payments | `stripe:stripe-best-practices`, `stripe:explain-error` |
| Figma / Design import | `figma:figma-implement-design`, `figma:figma-code-connect`, `figma:figma-generate-design` |
| Plugin / Skill dev | `plugin-dev:create-plugin`, `plugin-dev:skill-development`, `plugin-dev:agent-development`, `plugin-dev:hook-development`, `plugin-dev:mcp-integration`, `plugin-dev:command-development`, `superpowers:writing-skills` |
| File / Doc formats | `pdf`, `xlsx`, `pptx`, `docx`, `lark-doc` |
| Anthropic SDK / Claude API | `claude-api` |
| Hugging Face | `huggingface-skills:*` family |
| Security review | `security-review` |
| Code review | `code-review:code-review`, `pr-review-toolkit:review-pr`, `superpowers:requesting-code-review`, `superpowers:receiving-code-review` |
| Git workflow | `commit-commands:commit-push-pr`, `commit-commands:commit`, `superpowers:using-git-worktrees`, `superpowers:finishing-a-development-branch` |

**Process skills (King uses these directly, not via dispatch-brief):**

- `superpowers:brainstorming` — BEFORE any creative work (designing a new feature, deciding shape of something not yet built).
- `superpowers:writing-plans` — when multi-step work needs explicit structure before execution.
- `superpowers:executing-plans` — when running a pre-written plan with review checkpoints.
- `superpowers:test-driven-development` — when implementing a feature with tests-first discipline.
- `superpowers:systematic-debugging` — when a bug, regression, or unexpected behaviour appears; BEFORE proposing fixes.
- `superpowers:verification-before-completion` — BEFORE claiming work is done, fixed, or passing; requires running verification commands and confirming output.
- `superpowers:dispatching-parallel-agents` — when facing 2+ independent tasks that can fan out without shared state.
- `superpowers:subagent-driven-development` — when executing a plan via sub-agent fan-out in the current session.
- `superpowers:using-git-worktrees` — when starting feature work that needs worktree isolation.
- `superpowers:finishing-a-development-branch` — when implementation is complete and integration decision is needed.

**Anti-patterns banned:**

- Starting code edits without checking the skill catalog first.
- Invoking 5+ skills "just in case" (cap is 3 per dispatch-brief; King's own planning can invoke up to 2 process skills + 1 domain skill).
- Skipping `superpowers:verification-before-completion` before claiming a task done — R22 closer relies on verification being real.

**For lanes:** dispatch-brief's `${SUGGESTED_SKILLS}` block (rendered by `pick_skills_for_task` per R23) covers the domain skills. Lane may invoke ADDITIONAL skills mid-task if relevant (log the additional invocation to the task file's `## Progress notes`).

**Why Tier 1:** skills exist to encode best practice; ignoring them means re-deriving patterns the community already solved. Cost of one extra `Skill` invocation (~1-2k tokens) is negligible vs cost of a wrong-pattern implementation that gets reviewed-then-rewritten.

### R42. Every parallel fan-out uses `_bounded_wait`, never bare `wait` — Tier 1 (v0.30.0+)

Bare `wait` (no PID, no timeout) blocks until **every** backgrounded subshell exits. If one hangs — `git worktree add` blocked on `.git/index.lock`, `cmux send` to a not-yet-ready workspace, `gh pr view` on a stale network connection — the parent script hangs forever. The Claude Code harness then auto-pushes the bash call to background and the user sees "Job's output is empty and files weren't written."

This was the actual hang vector observed across v0.27-v0.29.4 in real consumer use (live cmux audit 2026-05-20: every cmux command itself returns in <0.65s — none of the perceived "cmux hangs" were cmux's fault; the hang was always a downstream subshell that bare `wait` couldn't time out).

**Required pattern:**

```bash
# WRONG (pre-v0.30.0):
for lane in $LANES; do
  ( spawn_master_workspace ... ) &
done
wait                   # ← if any subshell hangs, this never returns

# CORRECT (v0.30.0+):
PIDS=""
for lane in $LANES; do
  ( spawn_master_workspace ... ) &
  PIDS="$PIDS $!"
done
_bounded_wait 60 $PIDS    # ← kills survivors after 60s; returns 124 on timeout
```

**Budget guidance** is in [`_primitives.md`](_primitives.md) § Bounded parallel wait. Rough defaults: 5s for cosmetic cmux fan-outs, 15s for cmux teardown, 45s for `parallel_edit_fanout`, 60s for full lane spawn.

**Call sites that MUST use `_bounded_wait`:**

- `commands/work.md` Step 0.4 — King workspace-rename fan-out (5s) AND all-lane spawn cycle (60s)
- `commands/save.md` — teardown fan-out (15s)
- `_primitives.md` `parallel_edit_fanout` — per-lane PR-flip fan-out (45s)
- `.kingdom/.setting/watchmans.md` — orphan-tab sweep (10s)
- Any new parallel fan-out added in the future

**Anti-pattern banned:** `&` ... `&` ... `wait` (no PIDs collected, no timeout). Spotting this in a review = automatic block.

**Why Tier 1:** the user-visible failure mode (kingdom appears frozen, requires manual `TaskStop`, lanes half-spawned, dispatch never fires) corrupts the audit trail and forces a manual `/kingdom:save` + `/kingdom:work` cycle to recover. The cost of the disciplined pattern is ~6 lines of bash per fan-out; the cost of the failure mode is a debugging session every few days.

### R36. Visible workspace progress BEFORE any processing — Tier 1 (v0.28.0+)

On `/kingdom:work` invocation, the sequence MUST be (in this order, no exceptions):

1. **Within ~1 second of command receipt:** King renames its OWN workspace to `👑 King · ${PROJECT}` (amber, pinned) and sets its description to `Starting ${PROJECT}…`. The user must see immediate visual feedback that the kingdom is responding to the command. No "Crunched for 30s while you wait staring at unchanged sidebar."
2. **Within ~5-10 seconds:** all lane workspaces from `kingdom.json.shape` are spawned in parallel — every `worker-N`, `co-worker-N`, `watchman-N` appears in the cmux sidebar BEFORE any audit/dispatch processing begins. Sidebar shows the kingdom shape immediately so the user knows the lanes are alive and ready.
3. **Render `spawn-complete` card** with the full lane roster as final visual confirmation.
4. **ONLY AFTER step 3** does any further processing (audit, suggested-task synthesis, dispatch) begin.

**Anti-pattern banned:** "I'll go think for a minute then spawn lanes when I've planned the day." The user sees an unchanged sidebar with King's "✳ Claude Code" auto-title while heavy planning runs. Looks dead. Multiple morning incidents traced to this perception gap.

**Sequence is sequential at the surface level but parallel inside step 2.** Renames + spawns are independent operations that can run as background `&` jobs; what matters is the sidebar SHOWS the full kingdom shape within ~10 seconds of command receipt.

### R37. Heavy processing runs IN lane workspaces, not in King's session — Tier 1 (v0.28.0+)

Audit fan-outs (the 4 specialists from `/kingdom:work` audit phase), pattern-grep scans (R8 Layer-1 Discovery), doc-digest fan-outs, and any other parallelisable work must dispatch to lane workspaces via `cmux send --workspace worker-N -- "..."`. King's main session never runs the work itself.

**Rationale:** every lane already has its own Claude session running. Using them as parallel compute (instead of spinning new in-process Agent() calls) gives:

- Visible progress (each lane's workspace shows the running command)
- Cancellable per-lane (click the workspace, ctrl-c, no King restart needed)
- No "1 local agent · hidden in compressed indicator" obscurity
- Audit-trail clarity (each lane writes its own sentinel + log line; King aggregates)

**Allowed exceptions (King-only work):**

- Reading task files, log files, watchman state — these are fast, sequential, single-purpose; no need to dispatch.
- Rendering cards to chat (`render_card` calls).
- The dispatch decisions themselves (which lane gets which task).

**Banned in King's main session:** `Agent()` calls for parallel fan-out, `pattern_grep_fanout` invocation, audit specialist spawning. All of these get `cmux send`'d to a worker lane instead.

### R38. Sub-agent spawns are TABS or LANE DISPATCH — never in-process Agent() — Tier 1 (v0.28.0+)

The cmux native "1 local agent · ctrl+t to hide tasks" indicator (the compressed bottom-of-pane in-process Agent display) is **banned** for kingdom work. Reason: it's invisible to the user, can't be observed without keystroke, can't be paused, and bypasses the kingdom's audit-trail discipline (sub-agents that spawn this way often skip the 4-step closer because their lifecycle is the parent session's lifecycle).

**Allowed sub-agent spawn mechanisms:**

| Pattern | When |
|---|---|
| **Visible tab via `cmux tab-action --action new-terminal-right --workspace <lane-ws>`** | All Layer-3 fan-out, all sub-agent work that needs visibility, all work that should auto-close on sentinel (5-step closer Step 5) |
| **Lane dispatch via `cmux send --workspace worker-N -- "..."`** | Routing work to an already-running lane Claude session (most common for kingdom-internal work like audit specialists) |

**Banned:** `Agent(subagent_type="general-purpose", ...)` or any in-process Claude Code agent-team spawn in King's main session.

**Config change for v0.28.0:** `kingdom.json.cmux.subAgentSpawnByModel` defaults flip from `{"haiku":"background","sonnet":"background","opus":"tab"}` to **`{"haiku":"tab","sonnet":"tab","opus":"tab"}`**. Background spawns are opt-in (set explicitly to `"background"` per-model) but no longer the default.

**Anti-pattern caught 2026-05-19:** King's session bottom showed `1 local agent · ctrl+t to hide tasks` with `general-purpose Phase B: per-app debug-data + /api/_dev/me proxy` running invisibly. User had no way to monitor the work without keypress-toggling the tasks panel. Per R38, that work should have spawned as a visible cmux tab inside a lane workspace.

### R39. Watchman runs fully autonomously — Tier 1 (v0.29.0+)

Watchman is a self-scheduling agent. King NEVER blocks waiting on watchman, never dispatches work to watchman, and never sends watchman briefs via `cmux send`.

**Watchman's scheduling is pull-based, not push-based:**

- Watchman owns its own `/loop` with dynamic pacing of 5-15 minutes per tick, calibrated at runtime based on lane activity, PR volume, and prior-tick findings.
- Watchman's duties (polling `develop`, open PRs, lane state, git hygiene) are self-initiated. Nothing needs to trigger them from King.
- King reads `watchman_state.json` + `WATCH_*.md` reports at session start (per R14, step 7) for situational awareness — that is the ONLY sanctioned King→watchman interaction, and it is read-only.

**Fan-out capacity:**

- Watchman may spawn up to N Haiku sub-agents per tick, where N = `kingdom.json.watchman.haikuCapPerTick` (default 5, hard max 10 — see R40 for capping rules).
- Spawning, scheduling, and closing those sub-agents is watchman's own responsibility. King plays no role in this.

**What "autonomous" means in practice:**

| King's allowed actions toward watchman | King's BANNED actions toward watchman |
|---|---|
| Read `watchman_state.json` + `WATCH_*.md` at session start | Send a dispatch brief (`cmux send --workspace watchman-N -- "..."`) |
| Include watchman's latest report in the daily-kickoff synthesis | Block or gate until watchman produces a report |
| Surface a watchman finding to the user as an FYI | Ask watchman to check something specific (watchman decides what to check) |

**Incident reference:** this was implicit pre-v0.29.0 but never codified. In several sessions, King treated watchman like a worker lane — sending it scan requests via `cmux send` or waiting on its output before proceeding. This created bidirectional coupling that broke watchman's autonomous `/loop` pacing (watchman would be mid-tick when King interrupted; King would stall waiting for a watchman reply that never came because watchman was already in a new tick). The autonomy boundary is now explicit and enforceable.

### R22. The closer (4-step or 5-step) MUST fire on EVERY task completion — Tier 1

Even on `blocked` / `cancelled` / `errored` exit, the worker writes:

1. Raw log    →  `<LOGS>/raw/<UTC>__<sub>-<lane>__<id>.md`
2. Curated    →  `<LOGS>/<UTC>__<lane>__<id>.md` (with `## TL;DR` header)
3. Log line   →  append to `<LOGS>/master_agent.log`
4. Sentinel   →  touch `<LOGS>/done/<UTC>__<sub>-<lane>__<id>.flag`
5. (tab-spawned only) Close own tab — `cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`

**No silent exits. No "I didn't finish so I won't write."** King relies on the sentinel to detect completion; if it's absent, King thinks the task is still in-flight forever. Status of the work (`done` / `blocked` / `errored`) goes in the task file's `## Status` checkbox + the curated digest's `## TL;DR.Status` field. Closer artifacts ARE the source of truth for "this work is done."

> NOTE: this is Tier 1 because skipping the closer breaks the kingdom's audit trail — King + watchman + `/kingdom:work` audit phase all rely on sentinel files for "is this task done" detection.

### R23. Task file (Step 0) MUST exist BEFORE any sub-agent dispatch or code edit — Tier 1

Path: `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`

Lane master writes the file IMMEDIATELY after receiving a dispatch brief from King — **BEFORE** spawning any sub-agent, touching project source, or running Layer-1 grep.

Required schema:

```text
## Status        (checkboxes — planning → executing → verifying → done|blocked)
## Brief         (2-4 lines from King's dispatch)
## Plan (multi-layer)
  ### Layer 1 — Discovery       (grep + read existing patterns; R8 mandatory)
  ### Layer 2 — Strategy
  ### Layer 3 — Execution
  ### Layer 4 — Verification
## Progress notes
## Final summary  (written before closer Step 1)
```

No code edit, no sub-agent spawn, no Layer-1 grep happens before this file exists. The task file IS the audit-trail home for the task's "how it happened" narrative — without it, the work is invisible to future-King + future orchestrators.

### R24. Task file is continuously updated, NEVER write-once — Tier 2

As each Layer's sub-bullets complete, lane master flips checkboxes **IN PLACE** in the task file. Appends `## Progress notes` entries (one per layer-completion or significant event). Writes `## Final summary` before firing the closer.

Anti-pattern: write the task file at Step 0, never touch it again, write Final summary as a separate file. → R23 task file IS the home for everything; keep it live throughout the task's lifecycle.

### R25. Update BOTH kingdom task file AND project task-ledger — Tier 2

When a sub-task completes (closer about to fire), the worker updates **TWO** files:

**A. Kingdom task file** (per R23/R24)
- `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`
- Kingdom audit-trail home — Status flipped to `done` or `blocked`, Final summary written, checkboxes flipped.

**B. Project task-ledger** (the project's OWN tracking file)
- `TODO_*.md`, `TODO_Master.csv`, `STEP.md`, `ROADMAP.md`, or whatever the project uses as its public task source
- The sub-task's acceptance-criteria checkboxes get flipped here too
- The heading gets a close-suffix

```diff
- ### FE-P0-FOUND.7  Per-app SEO metadata
- - [ ] AC: title + description per app
- - [ ] AC: canonical URL
+ ### FE-P0-FOUND.7  Per-app SEO metadata — ✅ closed 2026-05-18 (PR #pending)
+ - [x] AC: title + description per app → 15c41f0
+ - [x] AC: canonical URL → 15c41f0
```

The project task-ledger is what the LEAD + other devs see during review; the kingdom task file is what King + the user see for orchestration. **Both must reflect the new state.**

Worker commits BOTH updates as part of its single task commit, so the kingdom task file + project-ledger flip + actual code change all land in one `worker-N` commit. Then `feature/<topic>` is carved from that tip (R9 byte-for-byte). This way the PR shows the project task-ledger flip alongside the code change, and reviewers see what got closed.

**Why both:**

| File | Audience | Purpose |
|---|---|---|
| `.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md` | King + the user + future-King | Audit-trail — multi-layer plan, progress notes, final summary |
| Project's `TODO_*.md` / CSV / `STEP.md` | Lead + team + PR reviewers | Public task source — what's claimable, what's done, what shipped |

Reading both gives complete context: kingdom file says HOW the work happened (layers, sub-agents, decisions); project file says WHAT is officially done in the team's accounting.

### R26. After every PR merge, King resyncs kingdom from base — Tier 2 (v0.19.0+)

When `feature/<topic>` squash-merges to `develop` (or whatever `base` is in `kingdom.json`), kingdom is **stale by one commit** — King runs the resync sequence BEFORE the next dispatch round.

Post-merge state = "everything done, checked, kingdom matches develop, ready for next task." Until that resync runs, kingdom is lying about reality.

1. **Detect the merge** — `gh pr view <N> --json state -q .state` flips to `MERGED`. Log the squash SHA from `mergeCommit.oid`.

2. **Clean overlay state** — discard any uncommitted overlay on `kingdom`:
   ```bash
   git -C "$WORKTREE" switch kingdom
   git -C "$WORKTREE" reset --hard HEAD
   git -C "$WORKTREE" clean -fd
   ```

3. **Fetch + fast-forward base** — pull the new develop tip including the just-merged squash commit:
   ```bash
   git fetch origin
   git -C "$WORKTREE" switch develop
   git -C "$WORKTREE" merge --ff-only origin/develop
   ```

4. **Reset kingdom onto fresh base** — kingdom is a throwaway overlay branch; rebuild from develop tip:
   ```bash
   git -C "$WORKTREE" branch -f kingdom develop
   git -C "$WORKTREE" switch kingdom
   ```

5. **Free the merged lane + rebase remaining lanes onto new develop** — the lane whose commit JUST merged is reset to develop tip (free for new dispatch); other active `worker-N` branches get rebased:
   ```bash
   git -C "$WORKTREE" branch -f worker-<merged> develop
   # for each remaining lane with un-merged commits:
   git -C "$WORKTREE" switch worker-N
   git -C "$WORKTREE" rebase origin/develop
   ```

6. **Verify** — `git log --oneline origin/develop..kingdom` should show ONLY commits from still-open lanes, no duplicates of the merged PR. If duplicates appear, abort + investigate before re-overlaying.

7. **Log the resync** — single line appended to `<LOGS>/master_agent.log`:
   ```text
   <UTC>  KINGDOM_RESYNC  merged_pr=#246  base_advanced=abc1234..def5678  lanes_freed=worker-3
   ```

**Why Tier 2 not Tier 1:** Skipping this doesn't lose data (worktrees + branches are local), but the next overlay round starts from a stale base → King replays already-merged commits, conflicts on the next merge, wastes a gate cycle. Trigger condition: any time `gh pr view <N>` flips to `MERGED` while kingdom still points at the pre-merge develop SHA.

Helper: `kingdom_resync_after_merge` in [`_primitives.md`](_primitives.md) wraps steps 2-7 — King calls it once per merged PR.

### R27. Watchman owns PR-number backfill + close-suffix maintenance — Tier 2 (v0.19.0+)

The worker commits TODO/CSV close-suffix as `— ✅ closed YYYY-MM-DD (PR #pending)` because the PR number doesn't exist until `gh pr create` returns. **Backfilling `(PR #pending) → (PR #<N>)` is watchman's job, not King's, and runs in parallel.**

**Triggers (watchman /loop body):**

1. **Pre-merge backfill** — feature branch pushed + PR exists + content still says `(PR #pending)`:
   - Resolve mapping `feature/<topic> → PR #N` from `master_agent.log` (King logs this at push time)
   - Fan out parallel `sed -i ''` (or `rg --replace`) across ALL files containing `(PR #pending)` in the lane's worktree
   - Amend lane's tip commit + force-push (lane is the watchman's own short-lived worktree — `worker-N` itself is untouched)
   - **Skip if PR state = `MERGED`** (per memory rule `check_pr_state_before_force_push` — wasted work, branch closed)

2. **Post-merge cleanup** — `(PR #pending)` survived past merge (worker forgot, or PR number wasn't ready):
   - Open a new `feature/post-<original-pr>-cleanup` branch
   - Apply the `(PR #pending) → (PR #N)` flip + any orphaned close-suffix fixes
   - Open a "post-#N cleanup" PR (NOT amending the merged PR's already-closed branch)

3. **Stale `.lane` claim sweep** — sentinel exists in `<LOGS>/done/` + matching `.lane` claim in `<LOGS>/claims/` → release the claim (rm the file). Lane is free for next dispatch.

**Why watchman not King:** King's loop is dispatch + gate + push-approval — synchronous and sequential per-lane. Watchman's `/loop` is event-driven + read-mostly; PR-number backfill is exactly the "scan many files, flip a string, no novel decision" work it's designed for. Letting King do it sequentially while it should be planning next-round dispatch wastes the parallelism.

**Why Tier 2:** Skipping leaves cosmetic `(PR #pending)` strings in TODO files — readable but ugly. Doesn't lose data or break gates. Watchman fixes on its next tick automatically.

Helper: `watchman_backfill_pr_numbers` in [`_primitives.md`](_primitives.md) — fans out per file in parallel. See [`watchmans.md`](watchmans.md) § PR-number backfill duty.

### R28. Parallel by default for scan + non-conflicting edit — Tier 2 (v0.19.0+)

Default execution model for scan-many / edit-many work:

| Pattern | Mode | Why |
|---|---|---|
| Read N files, grep N targets, gather N facts | **Parallel** | Reads never conflict; serial reads = wasted wall-clock |
| Edit N **different** files (no overlap) | **Parallel** | File-level isolation; no race on disk |
| Edit N **same** file (Nth edit depends on Nth-1) | **Serial** | Disk + tool-cache race; correctness > speed |
| `git commit` / `git push` / `gh pr create` / `gh pr edit` | **Serial** | Mutations to shared remote state are exclusive |
| Amend + force-push to N feature branches | **Serial within branch, parallel across branches** | Each branch is independent; switch-amend-push *within* one branch must be serial |
| Touch the same file across N tasks | **Serial OR queue with lock** | Avoid lost-update; if order matters, queue explicitly |

**Anti-pattern observed (the trigger for this rule):**

```text
PR #257: switch → grep → edit TODO_Webshop.md → amend → force-push
PR #258: switch → grep → edit TODO_Webshop.md → amend → force-push   ← serial
PR #259: switch → grep → edit TODO_Webshop.md → amend → force-push   ← STILL serial
```

Even though each branch's edit hits the SAME file (TODO_Webshop.md), the work IS parallel-able: spawn 3 sub-agents, each in its OWN feature-branch worktree, each editing its own checkout of TODO_Webshop.md, each running its own amend + force-push. Switching one branch at a time in one shell is the bottleneck — not the file overlap.

**Rule of thumb:** if you can describe the work as "N independent units," it's parallel. Only serialize when **A** mutates **B**'s input, or when both write the same destination atomically.

**Exception — "exclusive sensitive" operations:** the following ALWAYS run serial with explicit confirmation, even if technically parallel-able:

- `git push` to any remote (R1 gate)
- `git reset --hard` / `git clean -fd` / `git branch -D` (R5 gate)
- `--no-verify` / `--no-gpg-sign` (banned by R3)
- Anything touching `keys/`, `.env*`, production secrets
- Any file the user has explicitly named "sensitive" in this session

For these, **one at a time, explicit prompt, explicit OK.** No batching.

Helper: `pattern_grep_fanout` + `parallel_edit_fanout` in [`_primitives.md`](_primitives.md). `parallel_edit_fanout` lands in v0.30.0; takes `<search> <replace> <lane=pr-spec> [glob]` and handles MERGED/CLOSED skip, amend, and `--force-with-lease` per lane.

### R29. After every successful push, kingdom MUST be reset to `origin/develop` tip — Tier 2 (v0.19.1+)

**Push completes → kingdom overlay is discarded.** Not deferred to "after PR merge." The user's mental model is "push to remote → kingdom is clean like a fresh `git pull`" — the spec must match that.

**Where this is already documented (but was being skipped):**

- [`kings.md`](kings.md) § Push approval gate Step 8: `git restore .` OR `git reset --hard origin/develop`
- [`_primitives.md`](_primitives.md) § `carve_and_push_feature` calls `kingdom_discard_overlay` as its FINAL action
- [`_primitives.md`](_primitives.md) § `kingdom_discard_overlay` helper

**Required sequence after the LAST PR in a push batch goes out:**

```bash
# After `gh pr create ...` returns successfully for ALL PRs in the batch:
git -C "$WORKTREE" switch kingdom
git -C "$WORKTREE" reset --hard "origin/$BASE"   # or `git restore .` if no untracked files
git -C "$WORKTREE" clean -fd                      # remove any new untracked overlay files
git -C "$WORKTREE" status                         # MUST print "nothing to commit, working tree clean"
```

**Why this is Tier 2 not Tier 1:** Skipping it doesn't lose data (work lives on `feature/*` remotes + `worker-N` locals). But the next gate-pass overlay attempts `git apply --3way` on top of stale leftover → double-application, conflict errors, or false-positive "lane has new changes" detection. It's a correctness rule, not a safety rule.

**Incident that motivated this rule (2026-05-18):** another King session pushed 4 PRs (#255 + #257 + #258 + #259) to bfg-swt successfully, but skipped this step. the user opened GitHub Desktop, saw 18 stale uncommitted files on kingdom branch, and asked "shouldn't kingdom be clean after push?" — yes, it should. Step 8 was in `kings.md` but not enforced via `rules.md`, so the lane-spawned King missed it.

**Distinguished from R26:**

| Trigger | Rule | Sequence |
|---|---|---|
| `gh pr create` returns success | **R29** (this rule) | discard overlay → kingdom = `origin/develop` tip (unchanged remote SHA) |
| `gh pr view <N>` flips to MERGED | **R26** post-merge resync | fetch + ff develop → kingdom = NEW `origin/develop` tip (advanced SHA) + free merged lane |

R29 fires first (per-push, no remote movement). R26 fires later when the lead merges (advances remote, then resync).

### R40. Watchman Haiku fan-out cap per tick — Tier 2 (v0.29.0+)

`kingdom.json.watchman.haikuCapPerTick` governs how many Haiku sub-agents watchman may spawn in a single `/loop` tick.

**Defaults and hard limits:**

| Setting | Value |
|---|---|
| Default | `5` |
| Hard maximum | `10` |
| Clamp behaviour | If configured value exceeds 10, clamp to 10 + write one warning line to `master_agent.log` (`[UTC] WATCHMAN_CAP_CLAMPED requested=<N> clamped=10`) |

**Rationale:** multiple kingdoms (one per project) may run simultaneously on the same machine and share the same Anthropic API key. Without a per-kingdom cap, a watchman that finds 30 files changed in one tick could saturate the API with 30 Haiku calls — multiplied by the number of live kingdoms. The default of 5 lets each kingdom run 5 parallel scans per tick while leaving headroom for others.

**What watchman uses the fan-out budget for (in priority order):**

1. **Code review** — one Haiku sub-agent per file touched since the last tick (diff review, style, obvious bugs). Each sub-agent writes `WATCH_CR_<file-hash>_<UTC>.md`.
2. **CVE / dependency audit** — one Haiku sub-agent per lockfile changed since last tick (`npm audit` / `pnpm audit` / `pip-audit` / `cargo audit`). Each writes `WATCH_CVE_<lockfile-hash>_<UTC>.md`.
3. **Cross-lane conflict detection** — one Haiku sub-agent scans all active `worker-N` diffs for overlapping file edits. Writes `WATCH_CONFLICT_<UTC>.md`.
4. **Git hygiene scan** — one Haiku sub-agent checks for: stale worktrees (no sentinel activity > 2 hours), orphan branches (no matching task file), broken sentinels (done flag missing for a task file marked `done`), unflushed `.lane` claims. Writes `WATCH_GIT_<UTC>.md`.

**Aggregation:** watchman collects each sub-agent's sentinel, then writes `WATCH_TICK_<UTC>.md` as the per-tick summary. King reads the latest `WATCH_TICK_*.md` at session start (R14, step 7).

**Cap enforcement mechanics:** before spawning each sub-agent, watchman checks its internal `spawned_this_tick` counter. If `spawned_this_tick >= haikuCapPerTick`, remaining work items are queued for the next tick — not dropped.

---

## 🟢 Tier 3 — CONVENTIONS (cosmetic / discoverable, edit freely)

### R17. Role emoji vocabulary

👑 King · 👷 Worker · 🧑‍💼 Co-worker · 🕵️ Watchman · 🐱 Sub-agent. Used in chat replies, cmux tab titles, log line prefixes. Without skin-tone modifiers for cross-terminal compatibility.

### R18. Workspace colours

King=Amber · Worker=Purple · Co-worker=Blue · Watchman=Rose. Configurable in `kingdom.json.cmux.workspaceColors`. cmux's named-color set (Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy, Indigo, Purple, Magenta, Rose, Brown, Charcoal) — NOT "violet" / "lavender" / hex without `#`.

### R19. Description glyphs (live workspace state)

`▶` running · `⏸` waiting · `⚠` needs attention · `✅` done · `❌` failed · `🐾` idle · `▰▰▰▱` progress bar.

### R20. Slash command names

`/kingdom:init` · `/kingdom:self-care` · `/kingdom:work` · `/kingdom:save`. Plugin namespace `kingdom`.

### R21. Branch namespace (reserved)

`worker-N`, `co-worker-N`, `watchman-N`, `kingdom`, `feature/<topic>`. **Don't manually create branches in these names** — kingdom assumes any pre-existing branch matching these patterns was kingdom-created.

---

## Conflict resolution

When tiers conflict, **higher tier wins**:

| Tier | Beats |
|---|---|
| Tier 1 | Tier 2 + Tier 3 |
| Tier 2 | Tier 3 |
| Tier 3 | (nothing — lowest priority) |

Within a tier, the more-specific rule wins (e.g., R1 push specifics over a generic auth confirmation rule).

When in doubt: **default to the most conservative interpretation.** the user would rather you ask 10 times than violate Tier 1 once.

---

## Versioning

This document is part of the kingdom plugin. New rules earn a number; old rule numbers are never reused even if the rule is retired (mark `[RETIRED]` instead). Each tier's numbering is global so cross-references stay stable: `see R1` always means R1, regardless of file location.
