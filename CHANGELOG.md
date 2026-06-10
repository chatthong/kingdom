# Changelog

All notable changes to `kingdom` (formerly `claude-kingdom`) are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

---

## [0.44.1] — 2026-06-10

Closes the audit findings that fell between v0.44.0's agent ownership boundaries (nobody owned `kingdom.json.template`; two helpers weren't in the fix tracker). With this, every functional finding from the 2026-06-10 audit is fixed; the only remaining backlog is cosmetic (work.md step-number gap, `audit-summary` orphan card, faq `git.mergeStyle` mention, and pre-existing latent notes like the `_bounded_wait` rc nuance and pool TOCTOU — tracked in `docs/audits/2026-06-10-stability-audit.md`).

### Fixed

- **`pattern_grep_fanout` matched ZERO files on macOS** — BSD grep doesn't expand braces in `--include='*.{ts,tsx,…}'`; now one `--include` per extension (live-tested: finds files it previously missed). The `ls scripts/*$term*` line became `find` (BSD ls opens a literal unmatched glob as a filename).
- **`kingdom.json.template` schema splits**: `subAgentPool.models` (array, never read) → `model` (string, what `spawn_pool_slot` actually reads); added the missing `welcome` block (`userName`, `weather`) that `fetch_weather_line` + the welcome card document.
- **`init_subagent_pool`**: with `$KJSON` unset, `seq 1 ""` counted DOWN (`1 0`) and spawned two phantom slots — now fails closed + numeric-validates pool size.
- **`cmux_read_screen`** standalone wrapper routed surface refs through `--workspace` (silently empty) — now branches `--surface`/`--workspace` like `cmux_send`'s inline check.
- **Fail-closed git helpers**: `carve_and_push_feature` no longer pushes whatever HEAD is after a failed `checkout -b` (and reports push failures); `attach_or_create_worktree` surfaces worktree-add errors instead of `2>/dev/null`-swallowing them; `kingdom_review_surface` defaults `$BASE` to develop instead of diffing `origin/`.
- **Doc-rot sweep**: 11 stale `_primitives.md` § links in 5 rule files + 3 cards + skill-routing.md repointed at the real `functions/` files; R14's wrong `rules.md (this file)` self-reference → `rules/index.md` (R01–R55); last `violet` color usages in `reference/cmux.md`, `docs/cmux-integration.md`, `cards/spawn-complete.md` → `Purple`.

---

## [0.44.0] — 2026-06-10

The big stability + communication release. A 5-agent Sonnet audit of the whole kit (~70 findings, saved to `docs/audits/2026-06-10-stability-audit.md`) followed by a 5-agent Opus fix army with strict per-directory file ownership, then a main-session verification pass against the **real cmux CLI contract** (`docs/cli-contract.md` from manaflow-ai/cmux, fetched 2026-06-10). All 9 critical audit findings fixed, plus 15 real-world consumer items from a week of fleet driving.

### Fixed — the 9 criticals

- **Story pods never dispatched** — `work.md` looped over `$POD_ASSIGNMENTS`, which no code ever built. The R50 partition step is now implemented (group claimable tasks by `integration.unit`, emit `<story-id>=<workers>` lines into a pod file consumed by a zsh-safe `while read` loop).
- **Solo path created a branch literally named `feature/`** — `$TOPIC` was only set on the story path. Now set + exported from `$SUBTASK_ID` per task; Step 6 aborts if empty.
- **Skill routing was dead** — `pick_skills_for_task` read `…/.setting/skill-routing.md`, a path that hasn't existed since v0.35 (`reference/skill-routing.md`). awk-on-missing-file exits 0, so every dispatch silently got zero skills. Path fixed + fail-closed guard.
- **Overlay could silently apply nothing** — `kingdom_overlay_lane` piped `git diff | git apply`; a failed diff fed apply empty input and "succeeded", so Tier-2 gates ran against an empty kingdom branch. Now capture-then-apply with loud failure on diff error or empty patch.
- **`run_tier2_on_story` false-passed on missing `kingdom.json`** — gained the same fail-closed guard its tier-1/tier-2 siblings got in v0.42.0, plus a zero-gates-found guard (gates can never pass vacuously).
- **`generate_pr_body_from_task_file` hung the session** — `awk` on an empty `$task_file` read stdin inside a heredoc and blocked forever. Guarded before the heredoc.
- **Watchman reviewed nothing, every tick** — `watchman.md` used `$WORKTREES` in 4 duty sites without ever defining it (`git -C /worker-1` against filesystem root, errors swallowed). Defined in the tick preamble; unquoted use fixed.
- **tmux fallback was deeply broken** — `cmux_new_split` direction words ran as shell commands (now mapped right/left→`-h`, up/down→`-v`); the entire sub-agent pool grepped `surface:[0-9]+` which never matches tmux `%N` pane ids (pool no-op'd under tmux; real tmux `spawn_subagent_tab` implemented, pool pre-warming disabled); `cmux_list_panes`/`cmux_list_pane_surfaces` returned non-JSON / ignored `--workspace` (now jq-shaped); `cmux_attention_override` dropped the King notification entirely (blocked lanes went unnoticed on tmux — now routes glyph + description + `tmux_notify`).
- **`render_card` resolved cards via `$WS`, which nothing sets** — now falls back to `$_KFN_DIR/..`; the parsed-then-ignored variant suffix (`welcome/morning`) actually selects the matching template section; `save`/`init`/`update`/`self-care` now `source _load.sh && load_feature core` before rendering.

### Fixed — cmux contract compliance (the docs re-read)

- **`cmux_send` Enter failed ~50% of sends** (the worst real-world pain): the Enter keypress depended on the sibling `cmux_send_key` wrapper, which is silently function-not-found when unloaded. `cmux_send` is now self-sufficient (`cmux send-key` inline), verifies submission via read-screen, and the paste-collapse re-check finally uses `--surface` for surface refs (the K3 fix never applied to them).
- **Browser wrappers used flags that don't exist in the current contract**: `new-split --type browser` (no such flag — now `cmux browser open-split [url] --workspace <ws>`, one documented call that opens AND navigates), `click --ref` → `--selector`, `fill --ref/--value` → `--selector/--text`, `screenshot --path` → `--out`. `browser_verify` now waits on `browser wait --load-state complete` instead of a fixed `sleep 2`, and the `eval "location.href=…"` injection vector is gone.
- **`cmux_first_surface` empty right after spawn** — internal bounded retry (6 × ~1s) + a loud stderr diagnostic on final failure; `spawn_master_workspace` retries discovery too. Wrapper self-sufficiency sweep: every cmux/browser wrapper that called a sibling wrapper now has a `command -v` guard + inline raw fallback.

### Added — two-way inbox (R55) + King-only memory (R54)

- **`inbox_send` / `inbox_list` / `inbox_read` / `inbox_reply` / `inbox_pending_count`** (5 new core helpers, round-trip tested under zsh): file-based messages at `.kingdom/<project>/inbox/<recipient>/` (`<UTC>__<from>__<type>.md`, typed front matter, `.archive/` on consume) + best-effort `cmux_notify` nudge. Lanes ask questions / raise flags WITHOUT stalling (state `❓ waiting on King`, keep working on continuable parts); the King drains `inbox_list king` every poll tick (answer via `inbox_reply` + nudge, escalate user-decisions, consume). `tmux_notify`'s durable fallback now writes inbox-spec messages (replacing bare `king-inbox/` files; legacy dir still swept for back-compat). New rule R55 (Tier 2); "Talking to the King" sections in all four lane roles; "Inbox triage" in king.md.
- **R54 (Tier 2): memory writes are King-only** — lanes send `type: memory-request` via the inbox; the King validates against R34 and writes or declines.

### Added — `/kingdom:self-learn` (12th command) + dispatch/work UX

- **`/kingdom:self-learn`**: any role grounds itself in the project docs in 3 layers (all README/index/CLAUDE.md → essentials read-list → deep docs pass; parallel fan-out per R51/R53 with caps 30/25/15) and renders 1-3 new `self-learn-summary` cards (Big picture / Map / Deep notes). The King may inject it as a lane's SECOND message after `/kingdom:self-<role>`.
- **`/kingdom:work` no longer auto-seeks jobs**: after audit + resume scan it asks `(s) seek-and-propose / (a) you assign / (r) resume-only` (fail-safe default resume-only). Dispatch fires only after an explicit choice.
- **Dispatch briefs carry a required `📚 Read first` section** (`${READ_FIRST_LIST}`, 3-7 files: project CLAUDE.md + domain docs + key source) so lanes get the big picture before implementing, plus one-liners for R53 Workflow fan-out and the inbox protocol. All lane roles got an early imperative "fan out via the Workflow tool for 3+-file tasks" step (R53 was previously King-only in practice) and a "Replying with cards" convention (new `lane-question` card).
- **Docs-sync on close**: the worker/senior closer now updates affected README/docs in the same task commit (or records `docs: n/a`).

### Added — watchman overhaul + stale-lane repair

- **`kingdom_repair_stale_lanes`** (new helper): detects workspace↔worktree disconnects (workspace alive, worktree/branch deleted underneath — the classic post-rebase mess) and the reverse; `--repair` closes the stale workspace, recreates the worktree from `origin/$BASE`, respawns, and re-grounds via `/kingdom:self-<role>` (R52). Wired into `work.md` Step 0.5 (report → user confirms repair).
- **Watchman three new duties** (zero extra Haiku, R40-safe): inbox-triage assist (nudges the King when questions wait > 2 ticks), stale-lane detection each tick (flags via inbox), and a once-per-day `watchman-digest` card to the user (lanes' health, PRs, pending questions, drift flags).

### Fixed — longevity + correctness (highs)

- Cross-block variable hygiene in `work.md`: `KJSON` assigned where shape reads happen; `PROJ KING_WS REFS_FILE KJSON BASE LOGS PROJECT SUBTASK_ID TOPIC` + pr/pod counters exported, with re-derivation guards at block tops (each bash block may be a fresh invocation).
- Sentinel globs missed the model prefix (`*__worker-1__id.flag` never matches `…__opus-worker-1__id.flag`) in resume scan / archive / save — completed tasks re-listed as in-flight every session. Fixed in all three.
- Done-flags now pruned post-push in `work.md` Step 6 (the v0.42.0 longevity fix existed in king.md but was never wired into the command), so the 10s poll scan stays O(active).
- `kingdom_resync_after_merge`: guards `$WORKTREE` before its destructive git ops (empty var = `reset --hard` on cwd); rebase loop now covers `co-worker-*` + `watchman-*` too.
- `random_task_done_line` infinite-looped on a 1-line pool; `spawn_loop`/`spawn_subagent_tab` JSON payloads now built with `jq -n --arg` (briefs with quotes/backslashes silently failed); `spawn_subagent_tab` captures its own tab's surface instead of the racy `tail -1`.
- zsh `nomatch` guards in `self-care.md` / `init.md` / `work.md` Step 0.0 (blocks that run before `_load.sh`); `self-care` doctor-report variables actually assigned; `init` `N_ROLE_DOCS` counts the modular tree; `update` runs `diff -rq` once instead of 4×; king.md kingdom-branch creation uses `reset --hard` instead of a merge commit (R4); R27's nonexistent `watchman_backfill_pr_numbers` reference corrected; king.md Step −1 now includes all R14-mandated reads; `violet` → `Purple` fallback in work.md.

Counts: functions 105 (57 core + 23 cmux + 8 browser + 17 tmux) · commands 12 (7 core + 5 role-bootstrap) · rules 55 (Tier 1 = 10 / Tier 2 = 40 / Tier 3 = 5) · cards 29.

---

## [0.43.5] — 2026-06-02

zsh audit extended to the inline bash in `commands/` + `roles/`: two more divergences fixed (word-split + read-only `status`).

### Fixed

- **`for X in $scalar` iterated once under zsh (no word-split) in 10 inline-bash loops.** zsh does not word-split an unquoted scalar in a `for` list (bash/sh do), so `for lane in $LANES_EXPECTED`, `for KJSON in $SCOPE_PROJECTS`, `for ws in $LANE_WSes`, `for rel in $STALE_FILES`, `for unit in $spec` each ran **once over the entire blob** instead of once per item — breaking lane spawn/dispatch (work.md ×4), multi-project migration (update.md ×3), teardown (save.md), stale-file import (self-care.md), and the watchman PR-backfill illustration (watchman.md). Fixed by adding `[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null` at the top of each affected fenced block — the codebase's existing idiom (archive.md's `$ARGUMENTS` loop already used it). `emulate -L sh` turns on `sh_word_split` (and `no_nomatch`) locally and **auto-reverts on block exit**, so it aligns zsh with the sh/bash semantics the bash was written for without a global option change. Verified under zsh 5.9 that the guard preserves the non-POSIX constructs inside those blocks (`[[ … == pat* ]]`, `comm <(…) <(…)` process substitution) and that the `_bounded_wait $PIDS` word-split calls in the same blocks now split correctly too. Chosen over a session-wide `setopt sh_word_split` (in `_load.sh`, as was done for `no_nomatch`) because word-split affects *every* unquoted scalar expansion — too broad a blast radius for the loaded helper functions — whereas per-block `emulate -L sh` is local and proven.
- **Bare `status=` in inline bash hit the zsh read-only special (work.md, archive.md).** Same root cause as v0.43.2: `status` is a read-only parameter in zsh (alias for `$?`), so `status=$(grep …)` in the resume-scan (work.md) and the archive close-detection (archive.md) threw `read-only variable: status` and the assignment failed — the status was never captured. `emulate -L sh` does **not** make it writable (verified), so these were renamed to `task_status` / `term_status`. A full sweep of every fenced bash block in `commands/` + `roles/` for the other zsh divergences (reserved-name shadowing, `${!…}`, `${var//%…}`, case-conversion, `BASH_REMATCH`, `read -a`, `echo -e`, array indexing) returned no further issues. Every edited block passes `zsh -n`.

---

## [0.43.4] — 2026-06-02

Completes the v0.43.3 `nomatch` fix: the inline bash in the role/command docs is now covered too, session-wide.

### Fixed

- **`nomatch` glob-abort also bit the inline bash in `roles/`/`commands/`.** v0.43.3 guarded the eight glob-using helper *functions*, but the King and lanes also run ad-hoc globs straight from the role/command docs — `for FLAG in "$LOGS"/done/*.flag`, `ls "$LOGS"/raw/fix-task-*.md 2>/dev/null`, `ls "$LOGS/done/"*.flag 2>/dev/null` (king.md, work.md, save.md, worker.md, watchman.md). Those can't all be pre-guarded (the LLM writes new globs ad hoc), so `functions/_load.sh` — the one file every role and command sources at session start — now sets `setopt no_nomatch` once (zsh only, no-op under bash). An unmatched glob then passes through literally instead of aborting, which is **bash's default semantics**, so the existing `[ -f "$FLAG" ] || continue` guards in the for-loops handle the literal-passthrough exactly as intended. `no_nomatch` (literal passthrough) is the right choice over `null_glob` (empty expansion), which would diverge from bash and make a bare `ls *` list the cwd. The per-function `local_options no_nomatch` guards from v0.43.3 stay as belt-and-suspenders for standalone sourcing. Verified under zsh 5.9: the king.md/work.md/save.md inline patterns run clean over empty dirs with zero "no matches found" spew.

---

## [0.43.3] — 2026-06-02

Third zsh-correctness pass: the `nomatch` glob-abort trap, found by a full shell-syntax audit of `functions/`.

### Fixed

- **Unmatched globs aborted with visible "no matches found" spew under zsh.** zsh's default `nomatch` option makes an unmatched glob (e.g. `ls -1t "$dir"/*"__${lane}__"*.md 2>/dev/null`) a **shell-level error** — it prints `zsh: no matches found: …` to the terminal and skips the command, and crucially `2>/dev/null` does **not** suppress it (the error fires during expansion, before the redirect applies). Latent because it only triggers on the empty-match path: a fresh workspace, a lane with no in-flight task file, a `logs/done/` with no flags yet — exactly the early-session state. Eight helpers were affected (12 glob sites): `pattern_grep_fanout`, `pick_skills_for_task`, `extract_pr_title_from_task_file`, `generate_pr_body_from_task_file`, `latest_test_report`, `poll_for_sentinels`, `compute_task_duration`, `save_session_state`. Each now opens with `[ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch` — under zsh an unmatched glob passes through literally (so `ls` fails quietly and `2>/dev/null` works), `local_options` auto-reverts the setting on return (zero global side-effect), and the guard is a no-op under bash. Verified under zsh 5.9: empty-match calls now return clean fallbacks (`[]`/`unknown`/title-fallback) with no spew. A full audit of `functions/` for the remaining zsh-vs-bash divergences — bash-only builtins (`mapfile`/`readarray`/`shopt`/`declare -A`/`local -n`), `${!…}` indirection, `${var//%…}` anchor-metachar substitution, `${var^^}`/`${var,,}` case conversion, `BASH_REMATCH`, `read -a`, `echo -e`, and other glob forms (`for…in *`, `[ … * ]`, array assigns) — returned zero further issues.

---

## [0.43.2] — 2026-06-02

Follow-on to the v0.43.1 zsh sweep: a second reserved-name shadowing, found by auditing the whole tied/special-parameter family.

### Fixed

- **`local status` aborted `/kingdom:save` under zsh.** zsh's `status` is a **read-only** special parameter (alias for `$?`), so `save_session_state`'s `local task_id status layer blockers_json` threw `read-only variable: status` and aborted the in-flight-task block — state snapshots errored for any lane with an active task file. Renamed the local to `task_status` (declaration, assignment, and the `jq --arg st` reference). Verified under zsh 5.9. A full sweep of `functions/` for shadowing of every zsh reserved/tied parameter — the path-arrays (`path`/`cdpath`/`fpath`/`manpath`/`mailpath`/`module_path`/`psvar`) and the specials (`argv`/`status`/`options`/`commands`/`functions`/`aliases`/`parameters`/`dirstack`/`pipestatus`/`signals`/`reply`/`match`/…), across `local`/`typeset`/`declare`, bare assignments, `for`-loop vars, and `read` targets — now returns zero hits.

---

## [0.43.1] — 2026-06-02

Critical zsh fix: the lane-spawn path no longer clobbers `$PATH`. Caught in a live consumer `/kingdom:work` run.

### Fixed

- **`$path` ⟷ `$PATH` tie broke command resolution under zsh (lane spawn dead).** zsh ties the lowercase `path` array to `PATH`, so any `local path=…` silently overwrites the command search path for the duration of that function. Four helpers declared a local named `path`, and since the Claude Code Bash tool runs **zsh** on macOS, this fired on every real run: `spawn_master_workspace` set `local path="$2"` (the project dir) and then died on `basename`/`date`/`head` with "command not found"; `_load.sh`'s `load()` set `local … path=<file>.sh` mid-loop, so the next subfolder lookup's `find … | head` lost `PATH` — the original "command not found: head" during load. `cmux`/`jq` survived only because zsh had already hashed their absolute locations. Renamed the locals off the reserved name (`srcfile` in the loader, `proj`/`wt` in the spawn + worktree helpers); `attach_or_create_worktree` and the tmux-fallback `spawn_master_workspace` had the same trap and were fixed too. Verified under zsh 5.9: the old pattern reproduces "command not found: basename"; the fixed loader does a mixed flat+subfolder `load` with `rc=0` and every wrapper defined, and `basename`/`date`/`head` resolve through the spawn. No other `path`/`fpath`/`cdpath`/`manpath` local-shadowing sites remain.

---

## [0.43.0] — 2026-06-02

Sub-agent fan-out gets a visible, trackable execution surface: the Claude Code **Workflow tool** and its live `/workflows` view.

### Added

- **R53 (Tier 2) — sub-agent fan-out runs through the Workflow tool when available.** When a role fans heavy work out to parallel sub-agents (R51), the preferred mechanism is now the Claude Code **Workflow tool** — *if the session exposes it*. A Workflow run renders the live `/workflows` progress tree (phases, per-agent token/tool/time, optional judge/verify stages), so **each kingdom task's sub-agent army is visible and trackable**, one Workflow run per task. Richer than headless `Agent()` and aligned with R36/R38's visibility intent.
- **All five roles wired to R53.** King, Senior, Worker, Co-worker, and Watchman each prefer the Workflow tool for their heavy fan-out (the King's *sanctioned in-session visible* fan-out; the watchman still bounded by its R40 hard Haiku cap). Built by a 5-agent Opus army (one per role) + a consistency judge.
- **`reference/workflow-fanout.md`** — the canonical pattern: the self-detect-then-fall-back decision, a script skeleton (Discover → Execute → Verify), per-role shapes, and the fallback idiom. Role docs point here rather than restating it.

### Changed

- **Graceful fallback is first-class (the kit stays shape-only).** Where the Workflow tool isn't in the session's toolset, roles fall back to the existing bounded mechanism unchanged: lane roles use `Agent()` (R42) or visible cmux tabs; the King uses tabs / lane-dispatch (R37/R38), never bare `Agent()` in its own session. No hard dependency on the harness feature.
- **Boundaries preserved.** Lanes stay persistent cmux/tmux workspaces (R36) — Workflow governs only the *ephemeral within-task army*, never lane spawning. The task file (R23) and the closer (R22) are unchanged; the sentinel flag is still the load-bearing signal. R42 bounds, the R51 soft target, and the watchman's R40 hard cap all carry over.
- Rules now **53** (Tier 1 = 10, Tier 2 = 38, Tier 3 = 5). `plugin.json` description refreshed (11 commands, 53 rules, R53 fan-out note).

---

## [0.42.0] — 2026-06-02

Opus-army audit pass targeting a **1-month King session** (was degrading at ~7 days). Fixes three classes of bug + adds the retention/optimization machinery a month-long run needs.

### Fixed (critical correctness — found by the Opus bug-hunt)

- **`_bounded_wait` was a no-op under zsh** (the shell Claude Code's Bash tool uses) — zsh doesn't word-split a plain `$PIDS`, so the loop ran ONCE over the joined string and `wait`ed for nothing. **R42's hang-protection never actually worked under zsh.** Same root cause silently broke `parallel_edit_fanout` (PR-backfill processed 0 lanes), `cross_story_scan` (dropped the last story, compared empty refs), and `random_task_done_line` (`mapfile` is bash-only). Fix: `emulate -L sh` (function-local sh word-splitting + 0-indexed arrays) on the affected helpers; `mapfile` replaced with a portable read loop. **Verified live under zsh**: `_bounded_wait` now waits and kills survivors on timeout (rc=124).
- **Gates could PASS on zero checks** — `run_tier1_gate`/`run_tier2_gate` fell back to `${project}` (a non-exported local) instead of `${PROJECT}`; an empty name → `.kingdom//kingdom.json` → jq read nothing → loop never ran → false pass. Fixed to `${PROJECT}` + **fail-closed** if the config file is missing. (Same `${project}`→`${PROJECT}` fix in compute_task_duration / extract_pr_title / poll_for_sentinels.)
- **tmux FALLBACK silently failed** — the activator overrode only 11 of ~17 `cmux_*` the roles call; `cmux_tab_action` (R38 sub-agent tabs + closer self-close), `cmux_tree` (R31 lane-readiness gate), `cmux_workspace_action`, `cmux_rpc`, `cmux_list_pane*` fell through to a missing `cmux`. Added `tmux_tab_action` / `tmux_tree` / `tmux_workspace_action` wrappers + routed/no-op'd all of them; fixed `cmux_new_split`'s arg-order mismatch. **Verified: 20/20 `cmux_*` now route under tmux.**
- **`kingdom_reset`** used bare `git` (cwd-dependent) + unguarded `$BASE` — now takes a project root, uses `git -C`, defaults BASE to develop (the v0.37.0 `git -C` discipline that this one had missed).
- **PR-backfill wrote the wrong PR numbers (or none)** — found in the post-build recheck. The watchman built its feat→PR map as a bash associative array (`declare -A PR_MAP`), which throws `bad substitution` under zsh and stores keys with literal brackets → every lookup read empty → backfill silently no-op'd. Worse, the helper call passed a single `(PR #${pr})` (the post-loop value = the **last** lane's number), so when it *did* run it stamped one lane's PR onto all of them. Fixed: portable newline `"feat pr"` pairs + `awk` lookup (no assoc array), a `%PR%` token in `parallel_edit_fanout` that substitutes **each lane's own** number via `sed` (the `${x//%PR%/n}` form is a silent no-op under zsh — `%` is zsh's end-anchor metachar), and dynamic lane enumeration via `git for-each-ref` (a hardcoded `worker-1..co-worker-1` list skipped `worker-5`/`story/*`). **Verified under zsh** (awk lookup last-write-wins; per-lane `%PR%` substitution distinct).
- **Done-flag deletion emptied the review surface** — recheck flagged that deleting `done/*.flag` at gate-time (the v0.42.0 hot-path prune) broke the multi-lane overlay rebuild, which derives *which lanes to re-overlay* from those flags: a session resume (or a `git reset --hard` before push) would rebuild an **empty** kingdom overlay, losing the exact dirty files the user was about to review (R15/R29). Fixed: the flag now survives review and is pruned **after push** (Step 8) instead — still bounded (only gated-unpushed flags linger, one review cycle wide), the gate never re-runs (the un-gated detector keys on the `KING_*` report, not the flag). Same loop's lane extraction also fixed to strip the model prefix (`sonnet-worker-2` → `worker-2`) so `kingdom_overlay_lane` targets a branch that exists.
- **`cadence.deepQuietStreak` was undefined** — watchman.md reads it (`// 3` default) but it was missing from `kingdom.json.template` and `configuration.md`; added to both so the deep-quiet tier is configurable, not just a hidden default.

### Added (longevity — to survive 1 month)

- **`/kingdom:archive`** (new, 11th command) — moves aged/closed task files + logs to `tasks/archive/<YYYY-Qn>/` + `logs/archive/`, sweeps old `WATCH_*`, rotates `master_agent.log`; `--older-than=Nd` + `--dry-run`; never touches in-flight/state/config/memory. Safe from `/kingdom:save` or a weekly watchman duty.
- **Watchman retention + change-gating** — a `WATCH_*` retention sweep at each tick (`watchman.retentionDays`, default 7) bounds the ~20k-files/month flat dir; Duties 2/4/6/7/8 are now **change-gated** (CVE only on lockfile change or 6h timer; seq/config/test only when a lane advanced; git-hygiene only on branch/worktree/sentinel change) — the ledger already deduped *notifications*, this stops the redundant *computation* (~tens of thousands of Haiku/month saved); a **deep-quiet cadence tier** (`cadence.deepQuietMin`, 30 min); PR-backfill reads `tail -n 500` of the log, not the whole file.
- **Hot-path pruning** — the King prunes each `done/*.flag` after the lane is **pushed** (was never deleted → full-scanned every 10s + every resume → quadratic; deleting at gate-time instead would empty the overlay-rebuild set, so post-push is the safe point), consumes-and-deletes `king-inbox/` items, and `kingdom_resync_after_merge` deletes the merged `feature/*` branch (local+remote) so out-of-band merges don't leak. R33 resume scan capped at `head -40`.
- **Doc-orientation caching** — `haiku_read_docs_orientation` writes stable-name artifacts (overwrite, not ~thousands of timestamped scratch files/month) + a content-hash cache that skips the ~50-file Haiku fan-out when docs are unchanged (re-grounding stops being expensive).

### Changed

- Command surface is now **11**. `configuration.md` synced (8 watchman duties, retention/cadence knobs incl. `cadence.deepQuietStreak`); `kingdom.json.template` gains `watchman.retentionDays` + `watchman.cadence` (`churnMin`/`quietMin`/`deepQuietMin`/`deepQuietStreak`). Functions: 100 (52 core + 23 cmux + 8 browser + 17 tmux).

---

## [0.41.0] — 2026-06-02

### Added

- **tmux FALLBACK backend (`functions/tmux/` (one wrapper per file)).** When cmux.app is unavailable (Linux, or macOS without cmux — e.g. Ghostty), the kingdom now runs on plain tmux: one session whose **windows are the lanes**, with the status-bar window list serving as the cmux colored-workspace sidebar (per-role `@rolecolor`; live `@state` glyph set WITHOUT renaming, so a lane's target handle stays stable through state changes). `load_feature tmux` + `export KINGDOM_BACKEND=tmux` redefines the `cmux_*`/`spawn_*` names to route to tmux, so every existing role/command call site works in FALLBACK with zero changes. Wrappers mirror the cmux ops: send (`send-keys -l` + Enter), set-state, notify (display-message + ⚠ glyph + a durable `king-inbox/` fallback file — an alert is never only a transient flash), read-screen / capture-pane, list / close-workspace, new-split, identify, and spawn (new-window + boot `claude`). New `tmux` feature in `manifest.json` (14 one-function-per-file wrappers, parity with `cmux/`); `TMUX-Guide.md` rewritten with the full cmux→tmux mapping. Verified live on tmux 3.6 under Ghostty — spawn → dispatch → set-state → notify → capture → teardown all pass via the real `load_feature` path.
- **Backend auto-detection + per-process robustness.** `core` now deps BOTH `cmux` + `tmux` (wherever cmux loads, tmux loads too). `kingdom_detect_backend` returns `cmux` (needs `$CMUX_CLAUDE_PID` AND the `cmux` binary — a stray env var won't mis-route) / `tmux` / `standalone`; `kingdom_backend_init` exports `KINGDOM_BACKEND`, activates the backend, prints which, and runs at `commands/work.md` Step 0.4. Detection is **per-process**, so it's robust to mixed setups — cmux.app + Ghostty both open with a King in each, or two Kings in one app: each detects its own host independently (env is inherited from the launching app, never globally scanned). tmux sessions are **project-scoped** (`kingdom-<project>`) so two tmux kingdoms never collide; the isolation boundary is the project (one King per project per workspace). Full matrix: `index.md` § Multi-session.

---

## [0.40.0] — 2026-06-02

Structural cleanup for clarity + flexibility (consumer-directed), plus a smarter watchman.

### Added

- **Watchman: 3 new surveillance duties + a findings ledger (smarter, less noisy).** Grounded in what the real consumer watchman caught and missed: **Duty 6 — sequence-collision scan** (parallel numbered-file collisions with no git conflict — two lanes forking the same migration parent, ADRs, changelog; the single highest-value catch from the 2026-05-20 run); **Duty 7 — config/secret parity** (a new env/config key with no home in configmaps/templates — the `KEYCLOAK_ISSUER` miss — plus a committed-secret regex scan); **Duty 8 — missing-tests heuristic** (new source files with no matching tests). Plus a cross-tick **findings ledger** in `watchman_state.json`: dedup (no more re-flagging the same issue every 5 min), persistence-escalation (info→warn→urgent if unactioned), auto-resolve (logs when an issue disappears), a **notify-fallback to `king-inbox/`** (so alerts survive a dead `cmux_notify` — the empty-`workspace-refs.env` failure), a **suggested-action** line on every finding, a **develop-health trend** (sustained-RED vs one-off, flaky detection), and a per-tick **"King's next action"** line that turns monitoring into one decision. New `kingdom.json.watchman.duties` toggles (`seqCollision`/`configParity`/`missingTests`, default on); all eight duties share the R40 Haiku cap.

### Changed

- **One file per role.** `roles/` collapsed from 12 files to exactly **5** — the `king-auto-gate` / `king-dispatch` / `king-overlay-review` / `king-watchman-integration` sub-docs merged into a single `king.md` (all content preserved), and `watchman-duties` / `watchman-docs-audit` / `watchman-pr-backfill` merged into a single `watchman.md`. Each role is now one complete "what + how" doc. The `/kingdom:self-<role>` bootstrap commands and `reference/role-bootstrap.md` point at the single role file (no sub-doc lists).
- **Action-named functions; flattened features.** Role-prefixed helpers renamed to action names so **any role can load any function**: `senior_review_tick`→`review_tick`, `senior_merge_worker_into_story`→`merge_into_story`, `watchman_cross_story_scan`→`cross_story_scan`, `guard_senior_dispatch_scope`→`guard_dispatch_scope`, `guard_worker_commit_branch`→`guard_commit_branch`, `guard_no_king_session_worktree_cd`→`guard_no_worktree_cd`; `spawn_senior_loop` + `spawn_watchman_loop` → one generic `spawn_loop`; `spawn_senior_workspace` dropped (use `spawn_master_workspace`). `manifest.json` no longer gates by role — the former `senior`/`watchman` features are gone; every helper lives in `core` (always loaded, deps `cmux`); only `browser` stays on-demand. (`kingdom_*` overlay helpers keep their prefix — it names the overlay action, not a role.)
- **`kingdom.json.template` is a lean per-project save-slot.** Removed behavior-encoding (`subAgents.modelByWorkType` — that's a fixed R51 default, not per-project config); kept the genuine per-project knobs (shape, git, gate.*, per-lane model, integration/watchman/cmux toggles, `subAgents.parallelTarget`).
- **All roles render cards.** Reinforced that every role uses `.kingdom/.setting/cards/` for user-facing output (no raw text where a card exists).

### Fixed (from the v0.39.0 recheck)

- R52's broken link to R34; stale `R01…R51` ranges (now R52); the directory-layout `plugin.json` version comment. Plus the R20 command registry, R32/R39 spawn-time `/kingdom:self-<role>` carve-outs, and the `self-watchman` card normalization are addressed in this release's consistency pass.

---

## [0.39.0] — 2026-06-02

### Added

- **Role-bootstrap commands — `/kingdom:self-<role>` (5 new commands).** `self-king`, `self-worker`, `self-co-worker`, `self-watchman`, `self-senior`. Each re-reads the canonical kingdom rules (`rules/index.md` + the 10 Tier-1 in full) and that role's spec (`roles/<role>.md` + sub-docs) straight from `.kingdom/.setting/`, then prints a `role-grounded` card (identity · model · allowed/banned verbs · gate tier · closer · the one "never"). The point: role knowledge becomes **pull-from-disk, not push-from-prompt** — a lane re-reads the versioned source instead of inheriting whatever the King restated from its (possibly drifted) context. Read-only: they read docs and print a card, never edit/dispatch/commit/push.
- **R52 (Tier 2) — role-grounding is pull-from-disk.** Codifies the above: the King injects `/kingdom:self-<role>` as each freshly-spawned lane's **first** message (before any task brief), so the lane grounds itself; the brief then carries only the task. Any role — including the King via `/kingdom:self-king` — re-runs its bootstrap any time it has drifted (after a long multi-day session, a `/compact`, or before a high-stakes action). Runtime complement to R14 (session-start read) and R34 (rules override memory). Wired into `commands/work.md` Step 0.4 (spawn injection) and `king-dispatch.md`.
- New `reference/role-bootstrap.md` (shared procedure + per-role read map + summary table) and `cards/role-grounded.md`.

### Changed

- Command surface is now **10** (5 core: work/init/self-care/save/update; 5 role-bootstrap: self-king/worker/co-worker/watchman/senior). Rules: 52 (Tier 2 = 37).

---

## [0.38.1] — 2026-06-02

### Added

- **`/kingdom:self-care` Check 13 — kingdom-mechanics drift in project memory (read-only).** Memory at any scope can drift from the versioned plugin and silently override the rules (R34) — the exact failure that cost a full session (a memory said "spawn helpers are broken, hand-roll cmux_send" long after the bug was fixed). Check 13 scans the workspace's project-memory dir and FLAGS — never edits — files that (a) snapshot kingdom *implementation* (matches function/command-level tokens: `cmux_send`, `cmux_rpc`, `workspace.list`, `spawn_*`, `_load.sh`, `git apply --3way`, … — NOT generic words like "overlay"/"dispatch" that appear in legitimate governance notes), (b) name a kingdom version older than installed, or (c) are duplicate stores created by path-casing (`Bonfire` vs `bonfire`). The plugin never writes to user memory (per the consumer-side no-blind-memory-writes rule); Check 13 lists, you decide. `/kingdom:update` now points to it as a post-migration heads-up. Tested against a real workspace: flags the one true mechanics snapshot with zero false positives.

---

## [0.38.0] — 2026-06-01

### Added

- **New command `/kingdom:update`** — migrate an existing workspace to the freshly-updated plugin **without losing session state or memory**. Previously the only way to refresh the kit was `/kingdom:init`, which conflates "scaffold a new workspace" with "re-sync an existing one" and (pre-v0.37.0) could clobber a hand-tuned `kingdom.json`. `/kingdom:update` treats the workspace as three categories: **shape** (`.kingdom/.setting/` — clean-replaced from the plugin, backup → fresh, stale files removed, local patches preserved in the `.bak`), **config** (each `<project>/kingdom.json` — additively merged so new schema keys are added while every existing value wins), and **runtime** (`tasks/`, `logs/`, `state.json`, `king-inbox`, `watchman_state.json` — never touched). Memory (`~/.claude/projects/<…>/memory/`) lives outside the workspace and is structurally never touched. The command previews the full delta (shape files changed/added/removed, per-project keys to add, preserved runtime) and requires an explicit `update` confirmation before any write; every write is backed up first. New `cards/update-report.md`.
- **Kit version stamp `.kingdom/.setting/.kingdom-version`.** Both `/kingdom:init` and `/kingdom:update` now write the installed plugin version into the kit, so drift between a workspace and the installed plugin is detectable.
- **`/kingdom:self-care` Check 12 — version drift.** Compares the kit's stamp against the installed plugin and recommends `/kingdom:update` when behind (or when the stamp is absent on a pre-0.38.0 kit). Informational; never auto-migrates.

### Changed

- The command surface is now **5 commands** (`work`, `save`, `init`, `self-care`, `update`). The 4-command surface (v0.29.0) deliberately folded updates into `init`; real consumer use (a workspace with 57 task files + 104 logs + tuned config) showed migration is a distinct enough concern — and risky enough to get wrong — to warrant its own verb with its own preview-and-preserve safety model.

---

## [0.37.0] — 2026-06-01

Consumer bug-report pass: a full day driving a 9-lane fleet on a consumer project (cmux.app + macOS/zsh) surfaced a cluster of silent-stall bugs (K1–K13) plus a hard lesson about the `kingdom` overlay being wiped before the human could review. This release fixes the verified-in-source bugs, hardens the overlay-review contract, and adds R51 (parallel sub-agents as a default for every lane + the King).

### Fixed

- **K1 — `_load.sh` was not zsh-safe (silent total failure).** Claude Code's Bash tool runs **zsh** on macOS, where `${BASH_SOURCE[0]}` is empty → `_KFN_DIR` resolved to cwd → every `load <fn>` failed with "command not found", and the subfolder fallback used a shell glob that **aborts** the function under zsh's `NOMATCH`. Rewrote self-location to detect zsh (`eval`-hidden `${${(%):-%x}:A:h}`, opaque to bash's parser) and replaced both globs with `find`. Verified `bash -n` + `zsh -n` clean.
- **K2 / K6 — spawn helpers assumed a flat `workspace.list` array (lanes came up at a dead bash prompt).** This cmux returns `{window_ref, workspaces:[…]}`, but `spawn_master_workspace`, `spawn_watchman_loop`, and `spawn_senior_loop` all did `jq '.[] | select(.ref…)'` → `surface=null` → the post-spawn `claude\n` and `/loop` sends were silently skipped. New shared helper `cmux_first_surface` (`functions/cmux/`) handles both schemas (`(.workspaces // .)`); all three rewired to it. `spawn_master_workspace` now also **verifies** Claude actually booted via `cmux_read_screen` (loud warning instead of a fixed-sleep assumption).
- **K3 — `cmux_send` long pastes didn't submit into an idle REPL.** A single Enter after a big paste leaves the composer paste-collapsed → the brief sits unsubmitted → the lane stalls. `cmux_send` now verifies and re-sends Enter if the collapsed-paste hint is still on screen.
- **K10 — Watchman polluted the project git tree.** `WATCH_*.md` monitoring artifacts were written to `<project>/docs/test-reports/` (they ride PRs). Relocated **all** `WATCH_*` writes (heartbeats, reviews, CVE/conflict/git/tick) to `.kingdom/<project>/logs/watch/` across `watchman.md` + `watchman-duties.md`; only PR-evidence `SMOKE_*`/`SENIOR_*`/`KING_*` reports stay in the project tree.
- **`kingdom_discard_overlay` was cwd-dependent** (bare `git checkout`). Now takes a project root and uses `git -C`, and `clean -fd`s the untracked overlay files the old version left behind.

### Changed

- **K8 — `/kingdom:init` no longer blind-overwrites a hand-tuned `kingdom.json`.** Existing config now offers `merge` (default — template adds only NEW schema keys, your values win via `jq '.[0] * .[1]'`), `overwrite` (with a timestamped `.bak`), or `keep`. No more lost all-`opus` lane config.
- **K9 — `/kingdom:init` `.setting` migration is now a clean-replace, not an overlay.** It renames the existing tree to `.setting.bak-<ts>` then installs fresh, so a stale flat layout (`kings.md`, `workers.md`, `cmux.md`, …) can't linger beside the new `roles/`+`reference/` dirs as dead traps.
- **K12 — dispatch briefs now say issue closure is FLAG-ONLY.** Briefs instruct lanes to never run `gh issue close`; use `Closes #N` in the PR body or flag king-inbox. Closure = lead sign-off.
- **K13 — `integration.unit` default is now `"pod"`** (one branch per Senior pod → one PR) with both `pod` and `story` semantics documented in the template.
- **R15 / R29 hardened — the overlay is sacred until push.** R15 now requires overlaying the **full** gated set so the user sees every in-flight change (all N PRs) as dirty files in one review surface. R29 now explicitly **BANS** `git reset --hard` / `git restore .` / `git clean -fd` on the overlay while gated work awaits review or push, and adds a classify-don't-wipe rule for pre-existing dirty kingdom (in-flight surface → keep; authored-on-kingdom → R4 violation, recover to a worktree). Motivated by the 2026-05-26 incident where the overlay was repeatedly wiped before the human could review 3 push-eligible PRs.

### Added

- **R51 (Tier 2) — every lane master + King fans heavy work out to parallel sub-agents.** Multi-file reads, greps, doc-orientation, review fan-outs should run as parallel sub-agents (soft target `kingdom.json.subAgents.parallelTarget`, default 10 — a strong default, not a hard gate), with model by work type (sonnet=standard, haiku=bulk, opus=sensitive). King fans out via `cmux_send`/visible tabs only (R38); still bounded by `_bounded_wait` (R42); the watchman keeps its own hard cap (R40). New `subAgents` block in the `kingdom.json` template.

### Notes

- **K5 (the `PreToolUse … hookSpecificOutput missing hookEventName` error) is NOT a plugin file** — it lives in a hook in `~/.claude`/workspace `settings.json`. `/kingdom:init` does not install it; locate and repair that hook separately. K4 (loop stalls on a failed wakeup) is downstream of K5.
- **K11 (`sync_roadmap.py` native-Milestone support)** is a consumer-project script, not a kingdom plugin file — out of scope for the plugin repo.

---

## [0.36.2] — 2026-05-25

### Added

- **`/kingdom:self-care` Check 11 now verifies the backend is fully scaffolded.** It syntax-checks function files in backend subfolders (`functions/cmux/`), not just flat files, and asserts every function named in `manifest.json` resolves to a `.sh` (flat or subfolder). This catches a partial scaffold — e.g. the v0.36.0 init bug where `functions/cmux/` (30 wrappers) wasn't copied — before it breaks `load_feature` at runtime. Implemented with `find` + a name-set membership test, so an absent subfolder can't trip glob-nomatch.

---

## [0.36.1] — 2026-05-25

### Fixed

- **`/kingdom:init` now scaffolds the `functions/cmux/` backend.** v0.36.0's copy step used `cp "$SRC/functions/"* "$DST/functions/"` (no `-R`), which skips directories — so a freshly scaffolded workspace got the flat helpers but **none of the 30 `cmux_*`/`browser_*` wrappers**, breaking `load_feature cmux`/`core` (every cmux call dead). Changed to `cp -R "$SRC/functions/."`, verified by simulating the full copy (178/178 files, cmux/ included). Future backend subfolders (e.g. `tmux/`) now come along automatically.

---

## [0.36.0] — 2026-05-25

**cmux through wrappers — one micro-function per subcommand.** The kit no longer types raw `cmux …` anywhere in its prompts. Every cmux subcommand now has a one-line wrapper in `functions/cmux/`, and every role / command / rule / card calls the wrapper. This makes calls accurate and uniform, gives one place to fix when cmux's CLI shifts, and sets up a clean `functions/tmux/` for the fallback backend later. Built by dogfooding: 5 parallel cmux worker lanes did the rewire, then a cross-lane consistency pass (each lane fanning the diff-reads out to parallel Sonnet sub-agents).

### Added

- **`functions/cmux/` backend folder** — 22 `cmux_*` wrappers (one per subcommand: `cmux_send`, `cmux_send_key`, `cmux_notify`, `cmux_new_workspace`, `cmux_new_window`, `cmux_new_split`, `cmux_workspace_action`, `cmux_tab_action`, `cmux_close_workspace`/`_surface`/`_window`, `cmux_tree`, `cmux_list_workspaces`/`_panes`/`_pane_surfaces`, `cmux_identify`, `cmux_capture_pane`, `cmux_read_screen`, `cmux_rpc`, plus the existing `cmux_set_state`/`cmux_attention_override`/`cmux_attention_clear`) **plus the 8 `browser_*` wrappers** (`browser_open`/`snapshot`/`click`/`fill`/`eval`/`screenshot`/`close`/`verify`) for cmux.app's built-in browser — UI verification any role can call via `load_feature browser`.
- **`cmux` feature** (always-on) + **`browser` feature** (on-demand, deps cmux) in `manifest.json`; `core` now deps `cmux`.
- **Subfolder-aware loader** — `_load.sh` resolves a bare function name whether it sits flat or in a backend subfolder (`cmux/`, future `tmux/`), so the manifest and callers never carry paths.

### Changed

- **Every raw `cmux …` invocation across `roles/`, `commands/`, `rules/`, `cards/`, and `index.md` rewired to the wrappers.** `reference/cmux.md` is now the wrapper catalog (raw commands shown only as "what each wrapper runs").
- **`cmux_send` submits via `cmux send-key`, not `cmux send … Enter`** — the latter types the literal word "Enter" (a "brief lands in a dead shell" silent failure). The wrapper now does text + a real keypress; `reference/cmux.md` § Send documents the trap.
- **`cmux_capture_pane` gained an optional surface arg** for per-pane precision (watchman orphan-tab sweep) while defaulting to workspace-level.

### Fixed

- **`cmux_set_state` 2-arg call sites** (`cmux_set_state "▶" "text"`) corrected to the 3-arg signature `(ws, emoji, text)` across `king.md`, `worker.md`, `senior.md`, `work.md` — the 2-arg form silently passed the emoji as the workspace ref, so the status line never updated (undermined R36). Surfaced by the cross-lane consistency pass.
- Unquoted refs in a few `cmux_notify` / `--workspace $VAR` sites quoted.

---

## [0.35.0] — 2026-05-24

**Modular architecture — the big upgrade.** Completes the reorg begun in v0.34.0: every part of the kit is now a small, single-purpose file in a clearly-named folder, features are declared bundles that plug in/out, the two oversized role docs are slimmed, and a structure-lint keeps it honest. Behavior is unchanged; this is organization. Built largely in parallel (4 workers + a serial rewire stage).

### Added

- **Composability — `manifest.json` + `load_feature` (phase 3).** Each feature (`core`/`senior`/`watchman`) is a manifest entry listing its `rules`, `functions`, `deps`, and the `kingdom.json` config flag that activates it (core=33 funcs, senior=7, watchman=2). `functions/_load.sh` gains `load_feature <name>`, which sources a feature + its deps in one call (`load_feature senior` → 7 senior helpers + `core`). Turning a feature off = don't `load_feature` it; zero edits to core.
- **`roles/` and `reference/` folders (phase 2).** Role docs moved + renamed to `roles/king.md`, `roles/worker.md`, `roles/co-worker.md`, `roles/watchman.md`, `roles/senior.md`; cross-cutting guides to `reference/cmux.md`, `reference/git.md`, `reference/skill-routing.md`. Every cross-reference across ~40 files rewired to correct relative paths (verified: 0 broken links repo-wide).
- **Structure-lint in `/kingdom:self-care` (Check 11, phase 5).** Verifies every `functions/*.sh` parses, every rule is registered in `rules/index.md`, and every internal `.md` link resolves. Keeps the small-file structure from rotting as it grows.

### Changed

- **Slimmed the oversized role docs (phase 4).** `roles/king.md` 1,328 → ~870 (extracted dispatch / gate / overlay / watchman-contract into `roles/king-*.md`); `roles/watchman.md` 1,037 → ~600 (duties extracted to `roles/watchman-*.md`); `commands/work.md` moved its non-executable prose/reference tables out to `docs/work-cycle.md`, keeping the bash steps.
- **De-duplicated shared mechanics.** The 4-step closer + forbidden-ops list (canonical in `roles/worker.md`) and the P1/P2/P3 model chain (canonical in `index.md`) are now stated once; `roles/co-worker.md` links to them instead of restating.

### Notes

- `rules.md` and `_primitives.md` remain thin pointers (deep `R##` anchor links into the old monoliths are the one cosmetic follow-up left).

## [0.34.0] — 2026-05-24

Modular reorganization (phase 1): the two monoliths become many small files, so each file stays short and a run loads only what it calls.

### Changed

- **`rules.md` → `rules/` (one rule per file).** All 50 rules are now individual files `rules/R01-…md` … `rules/R50-…md`, with `rules/index.md` as the registry (Tier-1 legend + a table linking every `R##` to its file). Tier-1 stays exactly 10. `rules.md` is now a thin pointer to `rules/index.md`.
- **`_primitives.md` → `functions/` (one function per file).** All 42 bash helpers are now individual `functions/<name>.sh` files (each `bash -n`-clean), with `functions/index.md` as the registry and `functions/_load.sh` the loader: `source _load.sh; load render_card spawn_master_workspace …` pulls only the helpers a run calls. `_primitives.md` is now a thin pointer to `functions/index.md`.
- **`/kingdom:init`** now copies the `rules/` and `functions/` directories into a scaffolded workspace; `index.md` file-map updated to point at the new folders.

### Notes

- Behavior is unchanged — this is packaging only. Old `[rules.md]` / `[_primitives.md]` references still resolve (the files are pointers).
- Phase 2 (deferred): move role docs into `roles/` + reference docs into `reference/`, and rewire deep `R##` anchor cross-references to the new per-file paths.

## [0.33.0] — 2026-05-24

Command-surface cleanup for consistency and simplicity. **Breaking** for the `/kingdom:work` and `/kingdom:init` argument surfaces.

### Changed (BREAKING)

- **`/kingdom:init` takes no flags.** It only scaffolds (workspace `.setting/` + project `kingdom.json` from template defaults + `tasks/` + `logs/`); it no longer reads the task-ledger, decides work, or spawns anything. The old `workers=` / `co-workers=` / `watchman=` / `base=` init flags are removed: shape is chosen per-session at `/kingdom:work` or by editing `kingdom.json` (`git.base` lives in the file, default `develop`).
- **`cap=N` renamed to `pr-limit=N`** (hard ceiling on PRs opened) and a new **`pod-limit=N`** added (hard ceiling on pods = units of work: story / task / milestone / issue). They are independent; dispatch stops when either is hit. A 3-worker story pod that ships one PR counts as 1 toward each, never 3.
- **`target=N-M/<period>` removed.** The soft-budget auto-split (Step 0.1 `parse_target`) is gone in favour of the two plain ceilings above.
- **Role flags shown as singular** (`worker=` `co-worker=` `watchman=` `senior=`) to match lane identities; the parser still accepts the plural forms (`workers=`, `seniors=`, `watchmen=`, `co-workers=`, `lanes=`). `seniors=` (introduced in v0.32.0) is now canonically `senior=`.
- Card `cap-reached` renamed to **`limit-reached`** (covers both `pr-limit` and `pod-limit`).

### Added

- **`lane=N` total-lane budget** (from v0.32.0, now first-class): the King auto-composes worker/co-worker/watchman/senior to fill N, honoring any per-role pin. `lane=8 watchman=1` pins 1 watchman and fills 7; `lane=12 senior=2` makes 2 story pods plus workers.
- **Pods persist `logs/` + `tasks/` like every lane.** `senior.md` now documents the full artifact set a pod writes: the Senior's story task file in `tasks/`, each worker's sub-task file in `tasks/`, and the Senior's 4-step closer (raw → curated → `master_agent.log` → sentinel) in `logs/`, plus the `SENIOR_*` review report. Nothing about a pod skips the audit trail.

### Migration

`cap=N` → `pr-limit=N`. `target=…` → drop it (use `pr-limit` / `pod-limit`). `/kingdom:init my-app workers=5 …` → `/kingdom:init my-app` then `/kingdom:work my-app worker=5 …` (or edit `kingdom.json.shape`). Existing `kingdom.json` files keep working; the shape is read from them as before.

## [0.32.0] — 2026-05-24

Story pods. A new **Senior** role (🎓 Opus) plus a **story integration branch** let multiple workers attack one unit of work (story / milestone / issue, configurable) in parallel, get it reviewed as a whole, and ship it as a single PR. Designed for both quality and speed via clean specialization: the King owns cross-story coordination, each Senior owns one story end to end, and review never happens twice on the same code.

### Added

- **`Senior-N` role (`.kingdom/.setting/roles/senior.md`).** Opus per-story sub-orchestrator and sole within-story reviewer. It owns a worker pod, merges their branches into a local `story/<id>` branch, runs an autonomous review loop (route fixes back to the owning worker, re-review, capped at `integration.reviewLoopCap`), then marks the story push-eligible and hands it to the King. Never pushes, never writes feature code. New cmux color (Teal) and emoji (🎓).
- **Story integration branch (R46).** A local branch (default `story/<id>`, configurable via `kingdom.json.integration`) with real merge commits, living in the Senior's worktree, branched off `develop`. Only the final `story/<id> -> develop` PR reaches origin. The solo `worker -> feature/<topic>` path remains for one-worker tasks.
- **Three-tier gate (R47).** worker Tier-1 (lane typecheck) -> story-branch Tier-2 (tests/smoke/lint, run by the Senior) -> Senior review loop -> human push (R1 unchanged).
- **`kingdom.json.integration` + `shape.seniors` + `seniors[]`.** New config: `enabled`, `unit` (story|milestone|issue), `branchPattern`, `gateOnStory`, `reviewLoopCap`; plus the senior workspace color and the `watchman.duties.crossStoryScan` toggle.
- **`/kingdom:work` arg additions.** `seniors=N` (per-role) and `lane=N` (total-lane budget the King auto-composes, honoring per-role pins; e.g. `lane=8 watchman=1`). Clarified the counting unit for `cap=` / `target=`: they count things that become a PR (a solo task OR a whole story pod = 1), not sub-tasks and not milestones.
- **8 helpers in `_primitives.md`:** `create_story_branch`, `spawn_senior_workspace`, `spawn_senior_loop`, `guard_senior_dispatch_scope`, `senior_merge_worker_into_story`, `run_tier2_on_story`, `senior_review_tick`, `watchman_cross_story_scan`.
- **Watchman Duty 5 — cross-story drift scan (R50).** Per-tick `git merge-tree` across in-flight `story/*` branches, feeding the King a drift signal. Watchman detects; King resolves at push; Senior owns within-story conflicts.
- **R46-R50** added; **R30 amended** for delegated dispatch (King + Seniors dispatch; Seniors in-pod + visible only, enforced by `guard_senior_dispatch_scope`). Tier-1 count stays 10. Design spec at `docs/superpowers/specs/2026-05-23-senior-story-pods-design.md`.

### Changed

- **`commands/work.md`:** Step 0.4 spawns Seniors; new Step 3.5 partitions stories, creates story branches, and assigns pods to Seniors; Step 4 skips senior lanes; Step 5 routes a Senior's push-eligible story sentinel through the cross-story check and the story-PR push.
- **`commands/init.md`:** copies `senior.md`; the scaffold template carries the new `integration` / `seniors` blocks.
- Role docs updated: `king.md` (delegation + cross-story), `worker.md` (pod membership), `watchman.md` (Duty 5), `git.md` (story branch tier), `index.md` (Senior registered across all role tables).

## [0.31.1] — 2026-05-22

Consumer-test fix release. A 2026-05-21 session running v0.31.0 surfaced two real bugs: (1) when the King spawned `worker-N` / `co-worker-N` / `watchman-N`, the cmux workspaces appeared but Claude REPL didn't start — `cmux new-workspace --command "claude"` turned out to be unreliable across cmux versions, so the King's subsequent `cmux send -- "<dispatch brief>"` landed in a bash prompt instead of a Claude session (the user had to manually ask King to run `claude` first); (2) when a worker closed a task, the King's poll loop was supposed to overlay the lane's diff onto the `kingdom` branch but didn't, because `commands/work.md:555` called `overlay_lane_onto_kingdom` — a function name that didn't exist anywhere (the v0.30.0 helper was named `kingdom_overlay_lane`, the call site was never updated). Bash's silent function-not-found behaviour meant the overlay step ran as a no-op for many releases without anyone noticing, and the subsequent Tier-2 gate fired against an empty kingdom branch.

Beyond the two fixes, this release also lands four planned consumer requests from the same session — a unified doc-orientation protocol (R45), watchman senior-dev cross-check duty, mandatory worker smoke-test reports, and a Sonnet default for the sub-agent pool. Pre-commit Haiku-army audit (10 parallel agents) caught 16 distinct issues before ship; 7 critical/high were fixed inline.

### Fixed

- **Worker spawn now reliably launches Claude REPL.** `spawn_master_workspace` in `_primitives.md` no longer relies on `cmux new-workspace --command "claude"` (unreliable). Replaced with explicit post-spawn `cmux rpc surface.send_text "claude\n"` + 1.5s boot sleep — the same pattern `spawn_watchman_loop` already proved works. `spawn_watchman_loop` simplified accordingly: it now only sends `/loop\n` (claude is already running by the time it's called).
- **King poll loop calls the right overlay helper.** `commands/work.md` Step 5a (sentinel-detection loop) was calling `overlay_lane_onto_kingdom "${LANE}"` — a function name that hadn't existed since v0.30.0. Replaced with `kingdom_overlay_lane "$PROJ" "${LANE}" "${BASE}"`. Discovered while fixing this: the loop's `BASE=$(basename "$FLAG" .flag)` was also **shadowing** the outer `$BASE` (git base branch, set at line 227) for the entire loop body. The shadow silently broke not just the overlay call but also the `N_MODIFIED=$(git diff --name-only "origin/${BASE}" | wc -l)` at line 566 (push-prompt card metadata). Inner var renamed to `FLAG_BASE` to stop the shadow.

### Added

- **R45 (Tier 2) — Haiku-army doc orientation for all roles.** Every role (King, worker-N, co-worker-N, watchman-N) MUST call `haiku_read_docs_orientation` when getting the big picture before work. The new helper in `_primitives.md` runs 2 phases: (1) Phase 1 — wayfinding fan-out: scans EVERY directory for `readme.md` / `index.md` / `todo*.md`, caps at 30 files, spawns up to 10 Haiku in parallel for 5-bullet digests; (2) Phase 2 — broader doc fan-out: full `*.md` landscape minus Phase 1, 20 newest by mtime, same parallel fan-out. Both phases bounded by `_bounded_wait` (R42). Consolidated digest at `<LOGS>/.<role>_<UTC>_doc_context.md`. King calls at session start; workers at task receipt before any code edit; watchman once at spawn (refresh trigger is design-forward — not yet implemented in watchman's loop); any role mid-task when "not sure." HAIKU_CAP=10 hard ceiling per call. R45 also locks model defaults: Haiku for doc-orientation fan-outs, Sonnet for lane sub-agents, Opus for sensitive design review.
- **Watchman Duty 1 expanded to senior-dev review with doc cross-check.** Previous Duty 1 was a per-lane code review (test coverage, security, style). v0.31.1 keeps those dimensions and adds a Doc cross-check section: per-tick read of root + `docs/` markdown, then each lane's Haiku reviews the diff with that doc context grounded. New severity grounds: contradicts a documented decision (urgent), drifts from documented pattern (warn), missing doc update (warn). King's overlay state on `kingdom` branch is now also reviewed each tick (third reviewee alongside workers and co-workers). Output files land at `<project>/docs/test-reports/WATCH_REVIEW_<UTC>__<lane>.md` (convention-compliant — fixes audit finding H3).
- **Worker smoke-test report MANDATORY before every task commit.** New pre-closer section in `worker.md` (sits before the existing R4/R9 task-commit guard). Format-discovery first per R8 spirit: `ls $REPORTS_DIR | head -10` then read one existing report to match conventions. Bootstraps with a minimum schema (TL;DR + commands run + files touched + caveats) but expected to mimic existing format from the 2nd report onward. File naming `LANE_<UTC>__<lane>__<sub-task-id>.md` preserves the segment-2-is-lane grep contract. Both `worker-N` and `co-worker-N` use this; King's `KING_*` and Watchman's `WATCH_*` prefixes are untouched.
- **Sub-agent pool defaults to Sonnet.** `kingdom.json.cmux.subAgentPool.model` reads to `"sonnet"` by default (was previously implicit Opus via no `--model` flag). Override to `"haiku"` for cheap-read pools or `"opus"` for sensitive design pools. Pool slots are mono-model at boot — `spawn_subagent_from_pool` still accepts a `$model` arg for tab-rename labeling but no longer changes the slot's actual model. Flag order: `claude --model <m> -p 'AWAITING_DISPATCH'` (audit caught the inverted `-p --model` order before ship — would have failed entirely on consumer install).
- **R43 + R44 + R45 cross-references added throughout role docs.** `worker.md` Layer 1 Discovery now lists R45 as step 0 (doc orientation before code grep). `king.md` mandatory-reads table cell for `/kingdom:work` first-message expanded to include the helper invocation.

### Changed

- **`_primitives.md` orientation helper dropped `eval` indirection.** Original draft used `eval "find ... $prune -prune -o ..."` to interpolate the prune-clause string. Pre-commit audit (Audit #4) flagged this as redundant + a quoting vulnerability if `$proj` contains special chars. Replaced with direct backslash-escaped `\(` `\)` parens in the find invocation — works in bash without eval.
- **`_primitives.md` orientation helper now handles filenames with spaces.** Phase 2 `comm -23` pipeline rewritten to use `IFS= read -r f` + per-line iteration instead of word-split-then-sort. The `stat -f %m` (BSD) vs `stat -c %Y` (Linux) fallback now uses explicit if-else with empty-output check rather than `||` short-circuit (handles minimal Alpine containers where both flavours behave oddly).
- **`watchman.md` Duty 1 doc-context pipeline mirrors the same fix.** Was `tr '\n' ' '` collapsing the file list to a space-separated string; now preserves newlines and the Haiku prompt is told to read line by line via the consolidated `$DOC_CONTEXT_FILE`. Prompt also clarifies "use your Read tool" explicitly (was ambiguous — auditor flagged Haiku could try cat).
- **`CLAUDE.md` stale rule count.** "Pointers for unfamiliar areas" was still listing 40 rules with Tier 1 = 18. Updated to 43 rules; Tier 1 = 10 (per v0.31.0 cap); Tier 2 = 28; Tier 3 = 5.
- **`king.md` R45 reference scope corrected.** First-message-after-/kingdom:work mandatory-reads cell originally said "root *.md + docs/*.md"; updated to describe the actual two-phase / 30+20-file / every-directory scope.

### Audit summary (pre-commit)

10 parallel Haiku audits ran on the v0.31.1 changeset before commit. Findings:

| Severity | Count | Fixed inline? |
|---|---|---|
| 🔴 CRITICAL | 2 | Both fixed (flag order; `$KJSON` undefined) |
| 🟠 HIGH | 3 | All fixed (filename spaces ×2 sites; eval drop; WATCH_REVIEW path) |
| 🟡 MEDIUM | 5 | 2 fixed (king.md scope; CLAUDE.md count). 3 deferred (soft-fail surface lookup; R45 watchman aspirational claim; tick aggregation across multi-lane WATCH_REVIEW) |
| 🟢 LOW | 5 | 1 fixed inline (Haiku prompt explicit Read-tool); 4 deferred to v0.32.0 |
| ✅ PASS | 1 audit | (work.md BASE shadow + overlay rename) |

Audit cost: ~10×30k Haiku tokens (sub-dollar). Caught issues that would have shipped broken to consumers.

### Open threads — promoted to v0.32.0

- **Soft-fail surface lookup** in `spawn_master_workspace` — currently warns + proceeds if `cmux rpc workspace.list` returns no surfaces yet; should add bounded retry loop (matching R42 pattern).
- **Watchman doesn't actually call `haiku_read_docs_orientation`** — R45 claims watchman refreshes every 10 ticks OR on mtime change, but neither trigger is implemented in `watchman.md`'s tick body yet. Either wire the call in or weaken R45's claim.
- **Tick-aggregation across multiple per-lane `WATCH_REVIEW_*.md` files** — Duty 1's senior-dev fan-out produces one review file per lane per tick; the existing tick-summary table has one row per duty. Needs max-merge logic for the duty's severity column.
- **Per-rule heading sweep for Tier 1 cap** — still pending from v0.31.0; the legend at `rules.md:27` is authoritative, but per-rule headings still carry `— Tier 1` suffixes for ~19 rules that should be `— Tier 2`.
- **`_primitives.md` split into `_primitives/` directory** — file has grown to ~1380 lines; proposed shape: ~15 per-area files (hard-gates / spawn / orientation / overlay / feature-carve / etc), with `_primitives.md` becoming a 50-line index. Discussed; deferred to v0.32.0 to keep v0.31.1 blast radius bounded.

---

## [0.31.0] — 2026-05-20

Released the same day as v0.30.0 after a real consumer-kingdom session (`/kingdom:work bfg-swt cap=5`, 2026-05-20 morning) shipped **zero PRs in four hours** despite all five lanes spawning successfully. The transcript exposed that the kingdom's Tier-1 rules (R4, R9, R30, R31, R36, R37, R38) were being violated in sequence by the same King session — committing on `feature/<topic>` instead of `worker-N` (R9), FF-merging onto `kingdom` (R4), `cd`-ing into worker worktrees from the King's own session (R30 + R37), skipping the lane-spawn step entirely (R36), and asking "pick execute mode m/a/m1/self?" after the user said `go`. **Diagnosis: prose rules aren't gates.** A King operating fast in chat will skim past 600 lines of `rules.md` and reach a `cd .worktrees/worker-1 && git commit -m ...` line that looks reasonable in isolation. v0.31.0 turns the load-bearing rules into actual call-site blocks.

### Added

- **`_primitives.md` § Hard gates — 5 new helpers** that BLOCK violations at call time instead of describing them in prose:
  - **`guard_worker_commit_branch`** — refuses to proceed if `git commit` is about to land on `kingdom` (R4 violation), on `feature/*` (R9 violation — those are carved at push time), or on a branch whose name doesn't match the worktree's lane (`worker-1` worktree must be on `worker-1` branch). Returns `1` with a specific error + fix recipe; calling script's `set -e` propagates the fail.
  - **`guard_lane_workspace_exists`** — before any dispatch, checks `.worktrees/<lane>/` exists AND `cmux list-workspaces` shows the lane's labelled workspace. R31 + R36 enforcement: dispatch fails loud if the user can't see the lane in the cmux sidebar.
  - **`guard_no_king_session_worktree_cd`** — when invoked with `KINGDOM_ROLE=king` (or by default), refuses to `cd` into any path matching `*/.worktrees/worker-*|co-worker-*|watchman-*`. R30 + R37 enforcement: King's session can `git -C <path> <cmd>` for trivial reads but never assumes the lane's working directory.
  - **`kingdom_overlay_lane`** — wraps the correct `git diff origin/$base..$lane | git apply --3way` overlay flow with R4 guards (kingdom branch checked out + HEAD == origin/$base). Replaces the ad-hoc inline overlay the 2026-05-20 session got wrong (which FF-merged onto kingdom, making it a commit branch).
  - **`spawn_watchman_loop`** — after `spawn_master_workspace` returns a watchman workspace ref, auto-launches `claude` + `/loop` via `cmux rpc surface.send_text`. R39 enforcement: watchman is autonomous by spec; spawning a watchman workspace without dispatching `/loop` is a setup bug, not a deferred decision. The 2026-05-20 session left watchman-1 idle at a shell prompt for 47 minutes before the user asked "watchman why do nothing".
- **R43 (Tier 2)** — Job-done closing actions are agent-owned. The 4-step closing checklist (flip AC checkboxes in the project ledger, append `— ✅ closed YYYY-MM-DD (PR #N)` to the heading, write Final summary, run 4-step closer) is wholly the lane's responsibility; King's dispatch brief MUST NOT annotate any of these as user-owned ("Ter's hand" / "(human flip)" / "Ledger update: manual"). Lane MUST reject any brief containing such fields. The 2026-05-19 worker-1 incident motivated the rule: brief said "TODO_Webshop.md AC flip held on kingdom branch — Ter's hand", worker-1 never flipped, drift leaked into kingdom as unstaged changes, and the next morning the King re-read the field and asked the user "decide how to ship the AC flip" — burning 15 minutes on a step that should have been silent.
- **R44 (Tier 2)** — After user `go`, King executes. No further "pick execute mode m/a/m1/self?" or "spawn workspace now or later?" prompts. The user's `go` collapses all remaining dispatch branch points into kingdom defaults (`dispatch.defaultExecuteMode` = `cmux-lane`, smallest-task-first lane order, reuse-then-spawn workspace policy). What `go` does NOT collapse: R1 push approval (still per-PR) and R5 destructive-op approval (still with target). Recovery when violated: factual-ack in chat, default + execute, log `RULE_VIOLATION R44`, do not block.
- **Tier 1 cap (v0.31.0+)** — `rules.md` now opens with a prominent legend declaring exactly 10 Tier-1 rules: R1, R2, R4, R5, R14, R22, R30, R31, R36, R42. The cap is intentional: Tier 1 should be "violation = kingdom worse than running solo." 29 prior rules carrying `— Tier 1` markers in their headings are demoted to Tier 2 by the legend (per-rule headings will be swept in a future release; the legend is authoritative until then).
- **`worker.md` task brief schema** — explicit "Forbidden brief fields" callout listing the user-ownership annotations that violate R43 + the lane's rejection template.
- **`cards/daily-status.md`** — splits the lane table in two: a Dispatch-lanes table (worker-N + watchman-N rows only) and a Paired-sessions table (co-worker rows only, manual-only per R32 + R43). The 2026-05-20 session repeatedly listed co-worker-1 in the same table as workers, treating it as a dispatch candidate even though R32 forbids this.

### Changed

- **`rules.md` R33** — pre-scan now MANDATORY: `git fetch origin --prune` + `gh pr list --state merged` + per-lane recovery-PR check BEFORE reading task files. R33 v0.30.0 read frozen task-file snapshots and built a resume queue from them; if `origin/develop` advanced overnight via a recovery PR (e.g. `recovery/pr-262-consent-banner` after PR #262 had a stacked-retarget incident), the resume queue offered to "resume" work that had already shipped 8 hours earlier. The 2026-05-20 morning incident: King drafted a "ship the dependency chain" plan for worker-1 + worker-3, asked for `go`. User asked "did you cross check task ledgers?" — that triggered `git fetch` and the truth came out: both PRs already merged. 0 jobs shipped that morning. New 0.a/0.b/0.c pre-scan steps prevent the failure.
- **`plugin.json` description** — updated to lead with the v0.31.0 gate-helpers theme, mentions the 5 helper names by name, and aligns command surface with the v0.29.0 4-command set (`/kingdom:work` / `/kingdom:save` / `/kingdom:init` / `/kingdom:self-care`; was still referencing `/kingdom:day` / `/kingdom:update` / `/kingdom:exit` from v0.20-0.28).
- **`README.md` tagline + version badge** — both bumped to v0.31.0; tagline highlights "Hard gates replace prose" framing.

### Architectural insight (the v0.31.0 design decision)

Prior versions (v0.28.0 introduced R36/R37/R38; v0.29.0 added R39/R40/R41; v0.30.0 added R42) treated `rules.md` as the authoritative behaviour spec. Every new failure mode added a new rule + a new anti-pattern callout + a new "why Tier 1" justification. The 2026-05-20 session — running v0.30.0 in real consumer use — proved this approach has a ceiling. A King operating in real-time chat will not re-read 700 lines of rules between every Bash call; it will pattern-match the surface shape of the task and run with what looks right. Rules that aren't enforced at the call site are rules that get skimmed.

v0.31.0 picks a different lane. The rules stay (documentation matters; reviewers still need to understand the *why*), but the load-bearing critical rules now have helper functions in `_primitives.md` that the role docs MUST call before any commit / dispatch / overlay / cd. The guards are bash, not prose: `return 1` is a real fail, `set -e` propagates it, and the script halts. If a future King writes `cd .worktrees/worker-1 && git commit`, the `cd` itself goes through `guard_no_king_session_worktree_cd` first and the script exits before the commit ever runs. The same insight motivated the Tier-1 cap: 10 truly iron-clad rules with bash gates beats 29 prose rules with no enforcement.

### Open threads carried into v0.31.x

- **R45 candidate** — pre-commit hook (not just helper) installed by `/kingdom:init` into each lane worktree's `.git/hooks/pre-commit` that calls `guard_worker_commit_branch` automatically. Would catch the failure mode even when a future role-doc forgets to call the guard. Deferred to v0.31.1 pending consumer test.
- **R34 hardening** — session-start "memory vs Tier-1 conflict scan" required output (today, R34 says rules win but the King session must self-detect conflicts; no automatic scan). Deferred — needs design work on the scan format.
- **Companion app discussion (open from v0.30.0)** — thin web dashboard vs cmux.app upstream PRs, still no decision.
- **Stale `cmux send` / `cmux notify` / `cmux tree` references in plugin docs** — 11+11+4 hits across role docs. Live cmux 0.64.6+ still accepts these but the RPC method form (`cmux rpc surface.send_text` / `notification.create_for_target`) is the documented path. Audit deferred to v0.32.0.

---

## [0.30.0] — 2026-05-20

Three open threads from v0.29.x cleanup + one new Tier-1 rule discovered via live cmux audit. The audit was triggered by user report of "stuck on real use for many versions"; root cause turned out to be bare `wait` in 5 load-bearing fan-outs, not cmux itself.

### Added

- **R42 (Tier 1) — Every parallel fan-out uses `_bounded_wait`, never bare `wait`.** Bare `wait` (no PID, no timeout) blocks until every backgrounded subshell exits; if any one hangs (`git worktree add` blocked on `.git/index.lock`, `gh pr view` on stale network, `cmux send` to not-yet-ready workspace), the parent script hangs forever and the Claude Code harness auto-pushes the bash call to background. User sees "Job's output is empty and files weren't written" — the actual hang vector observed across v0.27-v0.29.4. Spec: collect PIDs (`PIDS="$PIDS $!"`), pass to `_bounded_wait <budget> $PIDS`, function `kill -9`'s survivors and returns 124 on timeout.
- **`_bounded_wait` helper** in `_primitives.md`. Pure-bash, macOS-portable (no GNU `timeout` dependency — confirmed missing on default macOS in audit). Per-PID poll loop with global wall-clock budget; default budgets table (5s cosmetic, 15s teardown, 45s `parallel_edit_fanout`, 60s spawn) documented inline.
- **`parallel_edit_fanout` helper** in `_primitives.md` (sibling to `pattern_grep_fanout`). Takes `<search> <replace> <lane=pr-spec> [glob]`; fans out per-lane subshells, each running `rg-discover → sed → amend → push --force-with-lease`. Honours R27 (skips MERGED/CLOSED PRs), R28 (parallel across branches, serial within), R42 (bounded wait, 45s budget). Logs a `PARALLEL_EDIT_FANOUT` line to `master_agent.log`. Removes ~20 lines of inlined parallel `&`/`wait` skeleton from `watchman.md`.
- **Check 9 in `/kingdom:self-care` — workspace file sync.** Scans the plugin's `.kingdom/.setting/` against the workspace copy; missing files (a common after-effect of upgrading the plugin without re-running `/kingdom:init`) are listed for one-keystroke import. Reuses the existing `doctor-report/partial-pass` card variant — no new card needed.

### Changed

- **`king.md` § Push approval gate Step 7** now calls `kingdom_resync_after_merge "$PR" "$LANE"` instead of inlining the old `worktree remove + branch add -b` cleanup. Behavioural improvement: the helper does `branch -f $merged_lane $BASE`, **preserving** the worker's local worktree (R35) — the inlined pattern destroyed and recreated it. Feature-branch deletion remains inline (one-shot ref hygiene).
- **`watchman.md` § PR-number backfill duty** rewritten to call `parallel_edit_fanout`. Per-lane `&` fan-out with PID-collection + `_bounded_wait 45 $FANOUT_PIDS` instead of bare `wait`. Stdout drains to `WATCH_PR_BACKFILL.md`.
- **`commands/work.md` Step 0.4** — King workspace-rename fan-out (4 cmux calls) and all-lane spawn cycle now both collect PIDs + call `_bounded_wait` (5s and 60s budgets respectively). The 60s spawn budget covers ~5 lanes × (worktree add 2s + 4 cmux calls 0.2s) with 5× safety margin.
- **`commands/save.md` teardown** — `cmux close-workspace` fan-out now uses `_bounded_wait 15 $CLOSE_PIDS`.
- **`rules.md` R28 footer** — removed "(the latter to be added in v0.19.0)" parenthetical now that the helper body exists.
- **`doctor-report` card all-pass variant** — added "workspace .kingdom/.setting/ in sync" check line; notes block updated from "10 standard checks" → "9 standard checks" + Check 9 auto-patch behaviour documented.
- **`commands/self-care.md` intro** — "8 checks" → "9 checks"; `CHECK_RESULTS_LIST` now appends `${STALE_RESULT}`.
- **`CLAUDE.md`** — open-threads list crossed out #1/#2/#3 (closed); architectural decisions list extended with #26 (R42 bounded wait).

### Fixed (open threads from v0.29.x)

- Thread #1 ("self-care should detect workspace-stale files") — closed via Check 9.
- Thread #2 ("`parallel_edit_fanout` referenced by R28 but spec-only") — body landed.
- Thread #3 ("wire `kingdom_resync_after_merge` into `king.md` Step 7") — Step 7 now calls the helper.

### Audit findings (cmux command surface, 2026-05-20)

Live test of every cmux subcommand the kingdom invokes, on macOS 25.4.0 with cmux 0.64.6:

- **All 18 commands return in <0.65s.** None hang.
- Slowest: `events --limit 1 --no-heartbeat --no-ack` at 0.61s (this is a stream by design).
- `cmux send` requires non-empty text (rc=1 if empty).
- `cmux workspace-action set-color "" / set-description ""` rejects empty value (rc=1) — documentation: don't try to "clear" via empty string.
- `cmux tab-action` without `--tab` or `--surface` ref → "Tab not found" (rc=1) — closer pattern depends on `$CMUX_SURFACE_ID` being set.
- **GNU `timeout` is NOT on macOS.** `gtimeout` is also absent by default. Kingdom doesn't reference either (audited); `_bounded_wait` uses pure-bash poll loop.

The user-perceived "cmux hangs" across v0.27-v0.29.4 were all downstream subshells (git, gh, network) caught by bare `wait` — R42 closes that gap.

### Architectural decisions (CLAUDE.md)

Decision #26 added: **R42 bounded wait** — every parallel fan-out must collect PIDs and call `_bounded_wait` with an explicit budget. List grows from 25 to 26.

### No new commands. No card renames.

R26/R27/R28 contracts unchanged — this release lands the **implementation** of helpers those rules already named, plus one new rule (R42) discovered by the live cmux audit.

---

## [0.29.4] — 2026-05-20

R41 propagation across docs + role-doc step audit. Shipped via 7 parallel Sonnet agents. No spec changes (rules unchanged); fixed-in-place corrections found by auditing each role doc against current rules.

### Audit findings (per role doc)

**`king.md` — 8 findings, all fixed:**
- **R4 / v0.17.0 violation** — Tier-2 gate code block used `git merge --no-ff "worker-N"` on kingdom (pre-overlay pattern). Fixed: now uses `git reset --hard "origin/$BASE"` + `git diff "origin/$BASE..worker-N" | git apply --3way -` (overlay, no commit) + review via `git status --short`.
- **R4 violation** — "Refreshing the kingdom integration branch" section had live `git merge --no-edit "$LANE"` on kingdom. Marked RETIRED + added v0.17.0 deprecation note.
- **R38 violation** — Dispatch prompt template told workers to use `Agent(...)` by default. Fixed: prompt now says "Spawn sub-agents as visible tabs by default (R38)".
- **R38 / R31 ambiguity** — Sub-agent lifecycle "Spawn" row said "another `Agent()` call" — could be misread. Reworded to explicitly say "AGENT mode (no cmux/tmux): `Agent(subagent_type=general-purpose, ...)` per R31".
- **Dead ref** — `commands/start.md Phase 5` pointed at a file deleted in v0.29.0. Updated to `commands/work.md Step 0.4`.
- **R36 missing** — Daily kickoff routine had no workspace-rename + lane-spawn-first callout. Added one-line block.
- **R41 missing** — Step −1 context-load had no skill resolution mention. Added sentence pointing to work.md Step 0.3.5.
- **R33 missing** — Kickoff synthesis showed "Today's plan" without note on resume queue check. Added 3-line callout.

**`worker.md` — 3 findings, all fixed:**
- **R25 missing** — No reference to updating both kingdom task file AND project task-ledger. Added bullet to Lifecycle list.
- **R38 stale** in 3 places — Section header said "Default: model-tiered — cheap fan-outs headless"; `subAgentSpawnByModel` JSON had `haiku/sonnet: "background"`; fan-out example used inconsistent label. All flipped to v0.28.0 R38 defaults (all-tab, background opt-in only).
- **R41 missing** — Zero skill references. Added 2-line note to task sequencing step covering King's `${SUGGESTED_SKILLS}` block + lane's authority to invoke additional skills mid-task.

**`co-worker.md` — 3 findings, all fixed:**
- **R32 contrast missing** — File said co-workers are dormant but didn't explicitly contrast with workers (which are NOT dormant). Added clarification.
- **Rule cross-ref** — Task file template ref to worker.md didn't name R22/R23/R24/R25. Added.
- **R41 missing** — No mention of skill invocation in paired sessions. Added bullet.

**`watchman.md` — 2 findings, all fixed:**
- **Dead `commands/doctor.md` ref** — File was deleted in v0.29.0. Replaced with `commands/init.md` reference.
- **R41 missing for Haiku fan-out** — Watchman duties could optionally invoke `code-review:code-review` / `security-review` skills. Added paragraph between section intro and `haiku_cap_per_tick`.

### R41 propagation (4 parallel agents)

- **`CLAUDE.md` synced to v0.29.4** — version footer + 4 new version-history rows (v0.29.1 through v0.29.4) + architectural decision #25 (R41 auto-skill-discovery). Now 25 total architectural decisions.
- **`README.md`** — added "Skill-aware" bullet to "Why kingdom?" list (after "Zero new runtime"). One bullet, one em-dash, links to `skill-routing.md`.
- **`docs/work-cycle.md`** — new "Skill-aware execution (R41, v0.29.3+)" section explaining domain routing + process skills.
- **`docs/configuration.md`** — new "Skill routing" subsection in Configure-your-project, pointing at workspace copy of `skill-routing.md` as the customisation surface.
- **`docs/faq.md`** — new Q/A "How does the King pick which skills to invoke?" covering 3-step resolution + customisation.
- **`commands/work.md`** — new Step 0.3.5 (Skill check, R41 mandatory) listing King's 4 process skills + lane skill flow + auto-discovery fallback. Step 4 preamble now mentions R41 explicitly.

### Flagged for future cleanup (not touched this release)

- `king.md` "Refreshing the kingdom integration branch" section — entirely obsolete after v0.17.0 working-tree overlay; marked RETIRED but full removal deferred.
- `king.md` Two-tier gate prose still says "Runs on the kingdom branch" — accurate but unclear that tests run against the overlaid working tree. Low priority.
- `worker.md` sub-agent lifecycle mermaid diagram still labels nodes "SPAWN more Agent() calls" — accurate in standalone mode but ambiguous in kingdom mode. Cosmetic.

### Changed

- `plugin.json`, `marketplace.json`, README badge + tagline — version → `0.29.4`.

### No spec changes

No rules added, no commands renamed, no new cards. This release is pure consistency-and-propagation cleanup after the rule-heavy v0.29.0-v0.29.3 sequence.

---

## [0.29.3] — 2026-05-19

Skill-aware execution: King + lanes resolve a skill set BEFORE any work. New R41 makes this a Tier-1 obligation. Plus removed the ASCII wizard from README (rendered poorly in dark mode) + 15 new skill rows in routing table (prisma family + remaining superpowers family).

### Added

- **R41 (Tier 1) Auto-discover and use the right skill BEFORE any work.** At task receipt, actor resolves a skill set via 3-step priority: (1) fast path = `pick_skills_for_task` against routing table; (2) fallback = system-reminder skill list match by description; (3) no-skill is valid (skip rather than load a vaguely-related skill). Includes a 12-row domain→skill quick map (frontend, prisma, supabase, stripe, figma, plugin-dev, file formats, claude api, hugging face, security, code review, git workflow) and a 10-skill process map for King-side planning (brainstorming, writing-plans, TDD, systematic-debugging, verification-before-completion, dispatching-parallel-agents, subagent-driven-development, using-git-worktrees, finishing-a-development-branch, etc).
- **skill-routing.md mapping rows** — 15 new P1 entries:
  - **Prisma family (7):** `prisma-cli`, `prisma-client-api`, `prisma-database-setup`, `prisma-postgres`, `prisma-postgres-setup`, `prisma-upgrade-v7`, `prisma-driver-adapter-implementation`
  - **Remaining superpowers (8):** `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`, `writing-skills`
- **Auto-discovery fallback section** in `skill-routing.md` — documents the 4-step fallback when routing table returns 0 matches (list available skills → match by description → invoke best fit → skip if no confident match). Distinguishes King-side process skills (invoked directly) from lane-side domain skills (via dispatch-brief).

### Removed

- **ASCII wizard mascot** from README. Rendered poorly in dark mode terminals (sigil column looked like floating debris next to mascot). Removed entirely — README header is cleaner without it.

### Changed

- `plugin.json`, `marketplace.json`, README badge + tagline — version → `0.29.3`. Tagline updated to "4 commands, autonomous watchman, state-based save, skill-aware execution."

### Cumulative rules count

| Tier | Count | IDs |
|---|---|---|
| Tier 1 (IRON-CLAD) | 18 (was 17, +R41) | R1-R7, R22, R23, R30, R31, R33-R39, R41 |
| Tier 2 (STRONG DEFAULTS) | 17 | R8-R16, R24-R29, R32, R40 |
| Tier 3 (CONVENTIONS) | 5 | R17-R21 |
| **Total** | **40** | |

Wait — that's 18+17+5 = 40, but R41 brings the highest ID to 41 with R32 (Tier 2) between R31 and R33. Let me recount: R1-R7 (7) + R22 (1) + R23 (1) + R30 (1) + R31 (1) + R33 (1) + R34 (1) + R35 (1) + R36 (1) + R37 (1) + R38 (1) + R39 (1) + R41 (1) = 18 Tier 1. R8-R16 (9) + R24-R29 (6) + R32 (1) + R40 (1) = 17 Tier 2. R17-R21 (5) = 5 Tier 3. Total = **40 active rules**. ID range R1-R41 with no R20a/R30a sub-rules, just plain monotonic numbering. ✅

### Apply on consumer side

Re-run `/kingdom:init <project>` to sync the new `skill-routing.md` rows + updated `rules.md` (R41) into the workspace copy. Next `/kingdom:work` invocation will pick up the routing table changes automatically (matcher reads workspace copy each dispatch).

---

## [0.29.2] — 2026-05-19

README polish: ASCII wizard mascot under the header (wrapped in `[!WARNING]` for amber/orange tint in GitHub rendering — closest to the mascot's terracotta colour without resorting to SVG) + expanded `/kingdom:work` shape-override examples with situation guide.

### Added

- **ASCII wizard mascot** in `README.md` header (Option E, "wizard mid-cast" — mascot + staff + casting sigil + warding stars). Rendered inside a `> [!WARNING]` GitHub alert frame so it gets an amber/orange-tinted border that approximates the mascot's terracotta. GitHub markdown doesn't support arbitrary inline text colour, so `[!WARNING]` is the closest stock option.
- **Expanded `/kingdom:work` examples** in Quick start. Previous block had 3 examples (`cap` + 2 `target` variants). New block has 12 examples in 4 categories: default daily, caps + targets (pace control), shape overrides (per-session, not persisted), combined patterns.
- **Shape-by-situation guide** (new 6-row table in Quick start). Maps common scenarios to recommended shape + reason: solo prototype, standard day, UI/design session, heavy autonomous batch, quick focused session, sustainable weekly cadence.

### Changed

- `plugin.json`, `marketplace.json`, README badge + tagline — version → `0.29.2`.

---

## [0.29.1] — 2026-05-19

Audit + fix-up: stale references to v0.29.0-deleted commands across 22 files. Shipped via 5 parallel Haiku audits + 4 parallel Sonnet fixers + README polish pass.

### Audit findings (5 parallel Haiku scans)

- ❌ ~50 stale `/kingdom:day` / `/kingdom:start` / `/kingdom:update` / `/kingdom:exit` / `/kingdom:doctor` references across rules.md (8 lines), watchman.md (5 lines), cards/*.md (16 files affected), docs/branch-model.md, docs/cmux-integration.md (6 lines), docs/faq.md (Q/A headers — historical, kept), CLAUDE.md (rule counts wrong).
- ❌ CLAUDE.md rule count claim was stale: "37 enforceable rules" / "Tier 1 = 16, Tier 2 = 16, Tier 3 = 5". Actual: **40 rules** (Tier 1 = 18, Tier 2 = 17, Tier 3 = 5).
- ✅ R39/R40 consistent across rules.md + watchman.md + kingdom.json.template + _primitives.md (verified live).
- ✅ Cards index (cards/README.md) clean — 22 cards listed, 22 files present.

### Fixed (4 parallel Sonnet agents)

- **rules.md**: 8 replacements. R30 / R32 / R33 / R36 / R37 / R20 → updated to use `/kingdom:work` (audit phase folded), `/kingdom:save`, `/kingdom:self-care`. R20 command list now shows 4 commands (init / self-care / work / save) instead of 6.
- **watchman.md**: 5 replacements. `/kingdom:update` → `/kingdom:work audit phase`.
- **All 16 affected cards/*.md** files updated (fires-when + used-by + body refs + path links). Affected: end-of-day, scaffold-success, what-to-work-on, suggested-task, audit-summary, welcome, daily-status, doctor-report, dispatch-plan, cap-reached, resume-queue, spawn-complete, gate-fail, pr-merged, push-prompt, task-complete. Already clean: watchman-alert, watchman-tick, session-saved, dispatch-brief, conflict-detected, blocked-lane.
- **CLAUDE.md**: rule count claim fixed (40 total, Tier 1 = 18, Tier 2 = 17, Tier 3 = 5). One stray `/kingdom:day` on line 105 → `/kingdom:work`. Version-history table entries kept as historical references (they describe what each release shipped at the time).
- **docs/branch-model.md**: 1 replacement + fixed leftover `daily-ritual.md` link → `work-cycle.md` (file was renamed in v0.29.0).
- **docs/cmux-integration.md**: 5 replacements + 1 section heading rename ("What `/kingdom:start` does" → "What `/kingdom:work` does in PRIMARY mode (spawn phase)").
- **docs/faq.md**: 0 edits. Q/A headers naming old commands intentionally preserved as historical context; answer bodies already correctly point to new commands.

### README polish

- 210 lines (was 209). One-line v0.29.1 tagline added: `v0.29.1: 4 commands, autonomous watchman, state-based save.`
- Quick start now shows the full 4-command arc (init → self-care → work → save) in one block.
- Tightened "daily ritual" prose (dropped "canonical"; "spawns the lanes" → "spawns lanes"; etc).
- Added save/resume sentence: "At end of day, `/kingdom:save` snapshots lane + task state so the next `/kingdom:work` picks up where you left off."
- Dropped slogany phrases ("Just Claude + git worktrees + a clean discipline").
- All internal links verified — no broken refs.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.29.1`.

---

## [0.29.0] — 2026-05-19

**Hard break: 6 commands collapsed to 4. Autonomous watchman with Haiku x10 fan-out. State.json save protocol.** Major restructure shipped via 8 parallel Sonnet agents.

### Hard-break command rename

Five commands deleted from `commands/`. Three new commands created. One kept and slimmed.

| Old (deleted) | New | Notes |
|---|---|---|
| `/kingdom:day` | `/kingdom:work` | folded |
| `/kingdom:start` | `/kingdom:work` (Step 0.4 spawn phase) | folded |
| `/kingdom:update` | `/kingdom:work` (Step 1 audit phase) | folded |
| `/kingdom:exit` | `/kingdom:save` | semantics simplified — see below |
| `/kingdom:doctor` | `/kingdom:self-care` | renamed |
| `/kingdom:init` | `/kingdom:init` | kept, slimmer (no prereq checks; moved to self-care) |

**No deprecation aliases** — the old commands are gone. Running them returns "Unknown command" from Claude Code.

### Added

- **`commands/work.md`** (606 lines) — `/kingdom:work [<project>] [target=N-M/<day|week|month>] [cap=N] [worker=N] [co-worker=N] [watchman=N]`. Three invocation shapes: no-args (interactive), `<project>`, `<project> + flags`. Per-session shape overrides via `worker=N` / `co-worker=N` / `watchman=N` (take precedence over `kingdom.json.shape` for THIS session, not persisted).
- **`commands/save.md`** (278 lines) — `/kingdom:save [<project>]`. State snapshot only. NO commits, NO pushes. Branches are the natural save; state.json is the bookmark.
  - Captures per lane: branch, HEAD SHA, uncommitted file count, in-flight task file path + Status + Layer + Blockers.
  - Captures open PRs: number, branch, state.
  - Computes `ready_for_fresh_work` flag.
  - Atomic write to `.kingdom/<project>/state.json` (schema_version=1).
  - Parallel close lane workspaces (`cmux close-workspace &; wait`); keeps King's workspace alive.
- **`commands/self-care.md`** (332 lines) — `/kingdom:self-care` (no args). 8 prereq checks: cmux/tmux/jq/gh/git/settings.json/tasks-writable/orphan-audit. Renders `doctor-report` card with 3 variants (all-pass / partial-pass / failed). Renamed from `/kingdom:doctor`.
- **R39 (Tier 1) Watchman runs fully autonomously.** Watchman owns its own `/loop` schedule. King NEVER blocks waiting on watchman, never dispatches work to watchman. Watchman's duties are pull-based. King reads `watchman_state.json` + `WATCH_*.md` at session start (per R14) but never sends watchman briefs via `cmux send`.
- **R40 (Tier 2) Watchman Haiku fan-out cap per tick.** Default `kingdom.json.watchman.haikuCapPerTick = 5`, max `10` (clamped + log warning if exceeded). Prevents API-usage spikes when multiple kingdoms run simultaneously.
- **`watchman.md` autonomous Haiku fan-out section** (+241 lines). Four per-tick fan-out duties: (1) code review per lane with new commits → `WATCH_REVIEW_<UTC>__<lane>.md`, (2) CVE scan per package manager → `WATCH_CVE_<UTC>.md`, (3) cross-lane file-overlap conflict scan → `WATCH_CONFLICTS_<UTC>.md`, (4) git hygiene (stale worktrees, orphan branches, broken sentinels) → `WATCH_GIT_<UTC>.md`. Tick aggregation → `WATCH_TICK_<UTC>.md`.
- **`kingdom.json.template` watchman config block** — `haikuCapPerTick`, `haikuCapMax`, `duties.{codeReview,cveScan,conflictScan,gitHygiene}` toggles.
- **`cards/session-saved.md`** (123 lines, `[!TIP]`) — `/kingdom:save` completion card with lane status + open PRs + ready_for_fresh_work indicator.
- **`cards/watchman-tick.md`** (134 lines, `[!NOTE]` / `[!CAUTION]` variant) — Watchman autonomous tick summary; CAUTION variant when any finding is `urgent` severity.
- **`_primitives.md § Session state persistence`** (+176 lines, 3 helpers): `save_session_state` (jq-based atomic write), `read_session_state` (with schema_version check + warning), `compute_ready_for_fresh_work` (jq filter).
- **`docs/work-cycle.md`** — renamed from `docs/daily-ritual.md`. Updated content for 4-command surface + per-session shape overrides + state.json save protocol.
- **`docs/configuration.md § Watchman config`** — new section documenting `haikuCapPerTick` (default 5, max 10) + `duties.*` toggles.
- **`docs/faq.md` new Q/A**: "What happened to `/kingdom:day`?" — explains the v0.29.0 hard break and all four renames.

### Changed

- **`commands/init.md`** — slimmer. No prereq checks (moved to self-care). Final step now points to `/kingdom:self-care` then `/kingdom:work`.
- **Cross-references across role docs** — old command names replaced throughout `.kingdom/.setting/index.md` (1), `king.md` (6), `worker.md` (3), `cmux.md` (8). Behaviour preserved; only entry-point names changed.
- **README.md** — Quick start now uses `/kingdom:work`; slash command table updated to 4-row surface; install hint uses `/kingdom:self-care`.
- **CLAUDE.md** — version → 0.29.0; version-history row added; directory layout updated (4 commands instead of 6); architectural decisions updated to 24 total (was 22, +R39 +R40).
- `plugin.json`, `marketplace.json`, README badge — version → `0.29.0`.
- `cards/README.md` index — all old command references updated to new commands.

### Cumulative rules count (post-v0.29.0)

| Tier | Count | IDs |
|---|---|---|
| Tier 1 (IRON-CLAD) | 17 | R1-R7, R22, R23, R30, R31, R33, R34, R35, R36, R37, R38, R39 |
| Tier 2 (STRONG DEFAULTS) | 17 | R8-R16, R24-R29, R32, R40 |
| Tier 3 (CONVENTIONS) | 5 | R17-R21 |

### Migration guide for existing users

Hard break — old commands gone. After updating the plugin:

1. Run `/plugin update kingdom`.
2. Re-run `/kingdom:init <project>` to sync new role docs / rules / cards / `skill-routing.md` / template into your workspace copy.
3. Replace any muscle memory:
   - `/kingdom:day` → `/kingdom:work`
   - `/kingdom:start` → `/kingdom:work` (no standalone spawn anymore)
   - `/kingdom:update` → `/kingdom:work` (audit folded in)
   - `/kingdom:exit` → `/kingdom:save` (state snapshot; commits/pushes are separate flows)
   - `/kingdom:doctor` → `/kingdom:self-care`
4. (Optional) Adjust `kingdom.json.watchman.haikuCapPerTick` if you want to raise/lower the Haiku fan-out cap from the default 5.

### Shipped via 8 parallel Sonnet agents

Per R28 parallel-by-default. Each agent owned a file slice end-to-end (no overlap). 5 deletions + 3 new command files + 2 new rules + 1 watchman.md rewrite + 1 template update + 2 new cards + 3 new helpers + 7 cross-reference updates + README/docs/CLAUDE.md update. Total: ~28 files touched, ~2000 lines net change.

---

## [0.28.1] — 2026-05-19

10-agent Haiku audit + 8-agent Sonnet fix-up. Aggregated cleanups across the repo: public-plugin hygiene (`Ter` → `the user` across role docs), CLAUDE.md sync to v0.28.0, helper consolidation per R37, em-dash density reduction in command docs.

### Changed

- **`Ter` → `the user`** across `.kingdom/.setting/` role docs (king.md ~45 replacements, co-worker.md ~40, worker.md 8, watchman.md 4, git.md 7, cmux.md 3, _primitives.md 2, rules.md, index.md 4, plus docs/*.md). Remaining `Ter` occurrences are all inside fenced code/mermaid blocks (untouched per safety rules).
- **`CLAUDE.md` synced to v0.28.0** — version footer, directory layout, plus 5 new rows in version-history table (v0.24-v0.28) and 9 new architectural-decision entries for R30-R38. Now 22 total architectural decisions (was 13).
- **Helper consolidation per R37**: `make_artifact_id`, `raw_path`, `curated_path` moved from inline `worker.md` definitions to canonical home in `_primitives.md § Artifact path helpers`. `worker.md` now references `_primitives.md` instead of inlining.
- **Em-dash density reduction** in 4 command docs: `commands/day.md` 49 → 33, `commands/update.md` 44 → 33, `commands/doctor.md` 44 → 34, `commands/start.md` 39 → 29. Targeted prose appositives + list-separators only; headings, code blocks, structural definition lists untouched.
- `plugin.json`, `marketplace.json`, README badge — version → `0.28.1`.

### Audit verification (10 parallel Haiku scans, post-fix)

- ✅ All 38 rules unique IDs, no contradictions, tier classifications consistent
- ✅ CHANGELOG 51 versions monotonically descending, all dates valid
- ✅ No AI-slop wording detected across repo (no `linchpin`/`robustly`/`leverages`/`comprehensive solution`/etc)
- ✅ Step numbering in `commands/day.md` clean (0.0 → 0.6, 1 → 6)
- ✅ Skill-routing table: prefixed/unprefixed duplicates pre-cleaned (no `frontend-design` + `frontend-design:frontend-design` overlap)
- ✅ `cards/dispatch-brief.md` Variables table includes `${STORY_HEADING}`

### Known remaining (deferred to next release)

- 13 broken cross-link anchors verified by audit — Agent 5 (anchor-fix sub-agent) hit a transient API ConnectionRefused error; verified rules.md anchors are clean but cmux.md / watchman.md anchor verification deferred. Most use GitHub-correct format already (manual spot-check passed); a comprehensive sweep can land in a future patch.

---

## [0.28.0] — 2026-05-19

**Visible-first execution model + interactive no-args mode.** Three Tier-1 rules that make the kingdom feel responsive AND keep all work observable in cmux, plus a new interactive `/kingdom:day` (no args) that asks the user "what do you want to work on?" and parses natural-language replies.

### Added

- **R36 (Tier 1) Visible workspace progress BEFORE any processing.** On `/kingdom:day` invocation:
  1. Within ~1s: King renames its OWN workspace to `👑 King · <project>` (amber, pinned) + sets description `Starting <project>…`. User sees immediate visual feedback.
  2. Within ~5-10s: ALL lane workspaces from `kingdom.json.shape` spawn in parallel — every `worker-N`, `co-worker-N`, `watchman-N` appears in sidebar before any audit/dispatch.
  3. Render `spawn-complete` card.
  4. ONLY AFTER step 3 does processing begin.
  No "Crunched for 30s while sidebar looks dead" allowed.
- **R37 (Tier 1) Heavy processing runs IN lane workspaces, not King's session.** Audit fan-outs, pattern-grep scans, doc-digest fan-outs dispatch to lanes via `cmux send --workspace worker-N -- "..."`. King's main session does only: reading state, rendering cards, making dispatch decisions. Every lane has a Claude session already running — use them as parallel compute instead of spinning hidden in-process Agents.
- **R38 (Tier 1) Sub-agent spawns are TABS or LANE DISPATCH — never in-process Agent().** The cmux native "1 local agent · ctrl+t to hide tasks" compressed bottom-pane indicator is banned for kingdom work. Allowed mechanisms: `cmux tab-action --action new-terminal-right --workspace <lane-ws>` (visible tab, auto-closes on sentinel) OR `cmux send --workspace worker-N -- "..."` (route to existing lane Claude session). Banned: `Agent(subagent_type="general-purpose", ...)` in King's main session.
- **Interactive `/kingdom:day` mode** (new Step 0.0). `/kingdom:day` with NO args triggers interactive resolution: King renders `what-to-work-on` card listing all projects in workspace + live actionable state (open PRs awaiting review, in-flight task files with blockers, recently idle lanes). User replies with natural language; King parses project + task_hint + inline caps/targets. Confirmation gate prints back the parsed interpretation before proceeding. Three invocation shapes total:
  - `/kingdom:day <project> [target=...] [cap=...]` — standard
  - `/kingdom:day <project>` — standard, no caps
  - `/kingdom:day` — interactive, asks user what to work on
- **`cards/what-to-work-on.md`** (new, 21st card) — `[!IMPORTANT]` flavour, renders project list + live state + reply-format hints. Includes reply parsing rules table (natural-language → structured args), project fuzzy-matching, conversational vs invocation detection (`"hi"` → reply normally without starting kingdom).
- **`commands/day.md` Step 0.4 — Visible-progress kickoff** (new step BEFORE Step 0.5). Renames King's workspace + spawns all lanes in parallel (background `&` jobs + `wait`), then renders `spawn-complete` card before any other processing.
- **`commands/day.md` Step 1 — Audit dispatches to lanes** (not Agent()). Each of the 4 specialists routes to `worker-1..4` via `cmux send`; fallback for shapes with <4 workers spawns visible tabs in King's own workspace.

### Changed

- **`kingdom.json.template` `subAgentSpawnByModel` defaults** flipped: was `{"haiku":"background", "sonnet":"background", "opus":"tab"}`. Now `{"haiku":"tab", "sonnet":"tab", "opus":"tab"}`. Background (in-process Agent) is opt-in per-model. Tabs are slower (~10-20s boot) but visible, cancellable, audit-trail-clean.
- `plugin.json`, `marketplace.json`, README badge — version → `0.28.0`.

### Incidents that motivated this release (2026-05-19)

- User screenshot showed cmux bottom of King's pane: `1 local agent · ctrl+t to hide tasks` with `general-purpose Phase B: per-app debug-data + /api/_dev/me proxy` running invisibly. R38 closes this.
- Separate complaint: King spent ~5 minutes "Crunched" before sidebar showed any movement (no immediate rename/spawn feedback). R36 closes this.
- Need to invoke `/kingdom:day` with a vague intent without remembering exact project names + budget syntax. Interactive mode (Step 0.0 + `what-to-work-on` card) closes this.

### Apply on consumer side

Re-run `/kingdom:init <project>` (or workspace-only `/kingdom:init`) to sync new `rules.md`, updated `kingdom.json.template` defaults, and new `cards/what-to-work-on.md` into the workspace copy.

### Cumulative rules count

| Tier | Count | IDs |
|---|---|---|
| Tier 1 (IRON-CLAD) | 16 | R1-R7, R22, R23, R30, R31, R33, R34, R35, R36, R37, R38 |
| Tier 2 (STRONG DEFAULTS) | 16 | R8-R16, R24-R29, R32 |
| Tier 3 (CONVENTIONS) | 5 | R17-R21 |

---

## [0.27.0] — 2026-05-19

**Multi-window cmux.app: explicit support.** Tested live against an 8-window cmux setup. Confirmed: `cmux new-workspace` (no `--window`) lands in the caller's process window (where the King's bash session lives), NOT the user's focused window. Workspace refs are globally unique so all dispatch ops (`cmux send` / `notify` / `workspace-action` / `tab-action` / `close-workspace`) work cross-window with no extra flags. Existing kingdom code "just worked" for multi-window because the default-to-caller's-window behaviour is exactly what we want.

### Added

- **`kingdom.json.cmux.spawnWindow` config** (default: `"current"`). Three valid values:
  - `"current"` — no `--window` flag passed; lanes spawn in caller's process window (King's window). Behaviour unchanged from pre-0.27.0.
  - `"new"` — kingdom calls `cmux new-window` once at session start, caches UUID in `workspace-refs.env` as `KING_WINDOW`, passes `--window $KING_WINDOW` on every lane spawn. Use when you want the kingdom to claim a dedicated window.
  - `"window:N"` or `"<uuid>"` — explicit pin to a known window.
- **`spawn_master_workspace` helper updated** to read `kingdom.json.cmux.spawnWindow` and apply the right `--window` flag. Caches `KING_WINDOW` UUID once for the session in `<LOGS>/workspace-refs.env`.
- **`cmux.md` § Multi-window cmux.app** — new section documenting the tested behaviour: identify vs current-window difference, default-to-caller's-window, globally-unique refs, R31 cross-window verification, and the `spawnWindow` config table.

### Tested live (2026-05-19)

In an 8-window cmux.app setup:

- `cmux current-window` returned UUID of FOCUSED window (window:7).
- `cmux identify --json` reported `window_ref: window:1` for the caller's process (where the bash session lives).
- Spawning 3 test workspaces (workspace:41/42/43) via `cmux new-workspace --name "🧪 test-worker-N" --cwd ~ --command "echo ..."` without `--window` flag → all landed in window:1 (caller's window), NOT window:7 (focused window).
- `cmux workspace-action --action set-color --color Purple` applied successfully across-window (window:1 from a caller in window:1, all 3 refs).
- Parallel `cmux close-workspace --workspace workspace:41 & cmux close-workspace --workspace workspace:42 & cmux close-workspace --workspace workspace:43 &; wait` closed all 3 in <1s.
- `cmux tree --all` enumerated all 8 windows + their workspaces globally.

**Conclusion: the kingdom's pre-0.27.0 cmux dispatch code was multi-window-compatible by accident** (because `cmux new-workspace` defaults to caller's window and all targeted ops use globally-unique refs). v0.27.0 makes the multi-window support explicit via the `spawnWindow` config and documents the tested behaviour, but doesn't change the default.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.27.0`.

### Apply on consumer side

Re-run `/kingdom:init <project>` to sync the updated `kingdom.json.template` (now includes `cmux.spawnWindow`) — though omitting the key keeps the default `"current"` behaviour, so no action needed unless you want `"new"` or a pinned ref.

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
- **R32 (Tier 2) "Staged / waiting / dormant" is co-worker-ONLY.** Workers auto-claim from queue (per `king.md` § Lane utilisation). If queue empty, lane shows `🐾 Idle (no claimable task)` but King keeps polling. Workers NEVER sit "awaiting your dictation" — only co-workers wait, only for explicit `pair on co-worker-N`. Watchmen always run `/loop`, never idle/waiting.
- **`/kingdom:day` Step 0.5 — Lane-readiness gate.** New mandatory step BETWEEN Step 0 (parse args) and Step 1 (audit). Verifies every expected lane is listed in `workspace-refs.env` AND alive in `cmux tree --all`. Forces a `/kingdom:start` re-run if any lane is missing or stale. No dispatch fires until lanes are confirmed.
- **`/kingdom:day` Step 4 — R30 budget enforcement.** Explicit `DISPATCH_START` timestamp; warns at 60s elapsed without first `cmux send`. Anti-pattern call-outs in step 4 prose: no multi-batch tables in chat, no "waiting for direction" for workers.

### Incident summary (2026-05-19 morning)

User's day: zero tasks completed. Symptoms:
1. King chat history showed "Worker-1 plan (final)" 9-row markdown table with scope decisions ("Admin dropped from FE-P0-FOUND.5") + file-by-file changes + verification steps. That's worker work, not King work.
2. Screenshot showed ONE cmux pane (King only). No worker / co-worker / watchman workspace tabs in the sidebar.
3. King displayed `co-worker-1 staged · awaiting your dictation` AND treated worker-1 as if it was waiting too. User: "WTF for waiting i said that for co-working but you waiting for wtf is that shit."
4. King had been "Crunched for 1m 48s · 1 local agent still running" — local agent was King's own planning, no real lane work.

Root cause: previous rules said WHAT King does (`king.md` § Dispatch) but didn't HARD-BAN King from executing work itself. R30/R31/R32 close those gaps as Tier-1/2 rules.

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.24.0`.

### Companion file

- **`CLAUDE.md` (new at repo root)** — orients future Claude sessions to project state, recent version history, 13 key architectural decisions, working conventions, open threads, and pointers. Read this on every fresh session BEFORE touching the plugin.

---

## [0.23.0] — 2026-05-19

Per-task skill routing. King now picks up to 3 Claude Code skills per dispatch from a keyword mapping table, and the dispatch-brief carries them into the lane. Skills are **per-task, not per-lane-lifetime**: worker-2 doing a Supabase task gets `supabase:supabase`; the same worker-2 doing a shadcn task tomorrow gets `shadcn:shadcn-ui`. Previous-task skills don't persist (skills are per-invocation via the `Skill` tool anyway).

### Added

- **`.kingdom/.setting/reference/skill-routing.md`** — canonical keyword → skill mapping table (~40 mappings across P1/P2/P3 tiers). Covers Next.js, shadcn, Tailwind, OKLCH, frontend-design; Supabase + Postgres; Stripe; Claude API; PDF/XLSX/PPTX/DOCX/lark-doc; Figma; Hugging Face; plugin-dev (commands/agents/skills/hooks/MCP); CLAUDE.md management; code review; security review; superpowers process skills (brainstorming, writing-plans, TDD, systematic-debugging, verification-before-completion); commit-commands; git worktrees; doc-coauthoring; playground.
- **`pick_skills_for_task` helper** in `_primitives.md` — reads the routing table, greps task brief + AC + linked reference files (lowercase, whole-word, case-insensitive), returns up to 3 matching skills sorted by priority. Returns multi-line text ready for `${SUGGESTED_SKILLS}` substitution in the dispatch-brief.
- **`cards/dispatch-brief.md` updated** — new `Suggested skills` block in the template + `${SUGGESTED_SKILLS}` variable. If empty (no keyword matched), the entire section is dropped from the brief.
- **User override surface** — `worker-2: skill=figma:figma-implement-design pick BE-P0-AUTH.2` short-circuits the matcher with the user's verbatim skill list. `skill=none` clears the list (no skills suggested). Multiple skills comma-separated.

### Changed

- `commands/init.md` Step 2 now copies `skill-routing.md` into the workspace scaffold alongside `cards/`.
- `index.md` doc-index table updated to register `cards/` and `skill-routing.md` (was missing both from the canonical entry-point doc).
- `plugin.json`, `marketplace.json`, README badge — version → `0.23.0`.

### Customisation note

Edit the workspace copy at `.kingdom/.setting/reference/skill-routing.md` (not the plugin source) to add project-specific mappings. Matcher reads the workspace copy at every dispatch, so changes apply on the next task without restarting the King. Common additions: project-specific framework keywords (Vue/Nuxt, Rust), internal DSL reserved words, organisation-specific skills.

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

Closing the post-push overlay-discard loophole. The behaviour was already documented in `king.md` Step 8 and implemented as `kingdom_discard_overlay` in `_primitives.md`, but it wasn't enforced via `rules.md` — so a lane-spawned King session could (and today did) skip it and leave the kingdom branch with stale overlay files after push.

### Added

- **R29 (Tier 2) After every successful push, kingdom MUST be reset to `origin/develop` tip** — `git reset --hard origin/develop` + `git clean -fd` fires immediately after the last `gh pr create` in the batch returns. Distinguished from R26 (post-merge resync, which fires when the lead clicks Merge and advances `origin/develop`). R29 fires per-push (no remote movement); R26 fires per-merge (remote advances).

### Incident summary (motivating R29)

A King session pushed 4 PRs to bfg-swt (#255, #257, #258, #259) successfully, but never ran `kingdom_discard_overlay` after `gh pr create`. Ter opened GitHub Desktop, saw 18 stale uncommitted files on the kingdom branch, and asked "shouldn't kingdom be clean after push?" — yes. `king.md` Step 8 said so, but `rules.md` didn't, so the sub-King missed it.

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
- `watchman.md` — new "PR-number backfill duty" section (under R27); Sonnet watchman now owns this work, not King.
- `cmux.md` — `#notify` anchor in the command index fixed to `#notification-system` (canonical GitHub heading anchor); new "Teardown / close commands" section documenting the canonical `close-workspace` / `close-surface` / `close-window` command family + the three common wrong incantations + the parallel teardown pattern (R28).

### Changed

- `plugin.json`, `marketplace.json`, README badge — version → `0.19.0`.
- **`/kingdom:exit` Step 5 fix** — switched from broken `cmux tab-action --action close --workspace <ref>` (errors `Unknown tab action`) to canonical `cmux close-workspace --workspace <ref>` AND parallelised the 5-lane teardown (each `close-workspace` is now `&`-backgrounded with a single `wait` at the end). Previous serial version took ~5× longer than necessary; the wrong command name also forced King to trial-and-error through `tab-action close-others`, `cmux --help`, etc.
- **Role-doc bash trim** — duplicate helper definitions inlined across `king.md` (2 blocks) and `worker.md` (4 blocks: 3-helper pool + `cmux_set_state`) now reference `_primitives.md` as the single source of truth. Usage examples remain inline (they show HOW the helper is called for that role); the function bodies move to `_primitives.md`. Approximate trim: `king.md` 1320 → ~1290 lines, `worker.md` 779 → ~735 lines. Behaviour unchanged — the helper names + signatures are identical.

### Pending for follow-up (not in 0.19.0)

- `parallel_edit_fanout` helper in `_primitives.md` (R28 references it; spec-only for now).
- Wiring the call site for `kingdom_resync_after_merge` into `king.md` § Push approval gate Step 7 (helper exists in `_primitives.md`; the role-doc Step 7 still inlines the old per-lane cleanup pattern from before R26).

---

## [0.18.1] — 2026-05-18

Light doc minification — removed 3 "Why this matters" motivational sections from role docs (2 in `cmux.md`, 1 in `king.md`). Pure prose removal; no behavioural rules changed. Saves ~12 lines / ~1KB across the role docs read by King at session start.

### Honest minification report

Role doc footprint (read by King at every `/kingdom:start` session per v0.14.8):

| File | Lines | Lines in code blocks | Notes |
|---|---|---|---|
| `king.md` | 1327→1320 | ~540 (40%) | Bulk is canonical bash patterns; non-trivial to trim safely |
| `worker.md` | 779 | ~349 (45%) | Same — pool helper + closer templates are load-bearing |
| `watchman.md` | 631 | ~353 (56%) | /loop body bash + scan logic dominate |
| `cmux.md` | 617→610 | ~194 (31%) | Command reference; each block is canonical |
| `index.md` | 290 | ~65 | Mostly prose; tightest doc |
| `git.md` | 258 | ~115 | Branch model reference |
| `co-worker.md` | 190 | ~33 | Already light |
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

New section in `.kingdom/.setting/roles/worker.md` § "Pre-warmed sub-agent pool" with full pool management bash.

### 🆕 Auto-generated PR bodies from task files

King's push approval gate now auto-fills `gh pr create --body` from the lane's task file. No manual PR-writing — the task file's discipline (Brief / Plan / Final summary) feeds directly into the PR body.

Field mapping:
- `## Brief` → `## Summary`
- `## Plan (multi-layer)` checked items → `## Implementation` list
- `## Final summary` → `## Verification`
- `KING_*__<lane>__<id>.md` test report → linked at bottom
- Footer: `🤖 PR body auto-generated from kingdom task file: tasks/<UTC>__<lane>__<id>.md`

Override available via dispatch brief `PR body: manual` — King skips auto-generation and asks Ter to paste a body before pushing. Default: auto-generate.

New section in `.kingdom/.setting/roles/king.md` § "Auto-generated PR body from task file".

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

- **`.kingdom/.setting/roles/worker.md` Layer-1 Discovery section rewritten** with the "lazy implementor antidote" rule:
  - **Default stance**: "The project HAS a pattern; my job is to find it. Burden of proof is on me to show one doesn't exist."
  - **Mandatory exhaustive pattern grep** before any implementation. Use sub-agents in parallel (capacity is unlimited).
  - Concrete checklist: grep across the project, read `.env*` and `.env.example`, read all relevant `scripts/`, read `lib/*-defaults.*` for HOW-TO comments, read `compose.*.yml`, read project `CLAUDE.md`.
  - Synthesise findings in task file Step 1: either "pattern found at <file:line>, reusing it" OR "no pattern found; grepped N files; confirming new approach with King BEFORE implementing".
- **`.kingdom/.setting/roles/king.md` dispatch brief schema gets a NEW mandatory field**: `Patterns to grep first` — King specifies the file globs / search terms the worker MUST grep before implementing. Plus a `Default stance` line: "The project HAS a pattern. Find it before inventing. Burden of proof: if 'no pattern exists' — show me the grep output that proves it."

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

- **`.kingdom/.setting/roles/king.md` § "STRICT: `feature/<topic>` = `worker-N` tip, byte-for-byte identical"** — new subsection inside "Kingdom as review staging". Rules:
  - `feature/<topic>` is a fast-forward checkout from `worker-N` tip
  - King MUST NOT add commits on the feature branch after carving
  - Kingdom = source of truth for what's about to ship; feature branches = exact mirrors
  - Concrete correct + wrong bash snippets
- **`king.md` § "What to do when you want extra content in the PR"** — explicit decision matrix:
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

- No schema, command, or behaviour changes outside the king.md procedural rules.
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

- **`king.md` § "Calibrated philosophy — 60% conservative core, 40% industrial overlay"** — new top-level section defining the balance:
  - **Conservative core (60%)**: human-gated push, mandatory kingdom merge, non-skippable gate, watchman passive by default, confirmation on risky moves, small inline work allowed
  - **Industrial overlay (40%)**: big work auto-delegated, auto-load idle capacity, plan for max parallelism, parallel duplicate dispatch (Ter-initiated), watchman test-verification duty
  - **Conflict resolution**: when the two halves disagree, conservative wins (60% is the floor, 40% layers on top)
- **`king.md` § "Two-tier gate — light per-lane, heavy on kingdom"** — formalises kingdom as test environment:
  - **Tier 1 (lane)**: typecheck only, runs in `.worktrees/<lane>`. Fast feedback in seconds.
  - **Tier 2 (kingdom)**: full tests + smoke + lint on the integrated kingdom branch. Catches cross-lane bugs Tier 1 misses.
  - Push approval requires Tier 2 pass (not just Tier 1).
- **`king.md` § "Lane utilisation — load idle capacity"** — bash logic for the utilisation check + default behaviour rules:
  - 2+ idle lanes + 2+ pending → auto-dispatch obvious matches
  - 1 idle + 1 pending → suggest, await nod
  - Controversial work → always suggest, never auto-dispatch
- **`king.md` § "Parallel duplicate dispatch (Ter-initiated)"** — explicit pattern for race-style exploration: same sub-task-id, different briefs/models, lanes named with `-A` / `-B` suffix in their task files. Winner ships; loser archived for audit.
- **`watchman.md` § "On-demand test verification (King-dispatched, read-only)"** — new role expansion:
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

- **`.kingdom/.setting/roles/worker.md` § "Task-artifact naming — strict"** — new top-level section right before "Task file" subsection. Defines:
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

- **`.kingdom/.setting/roles/king.md` § "Kingdom as review staging — MANDATORY before any push"** — new top-level section right before "Push approval gate". Defines:
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
- **`worker.md` "Tab vs Agent decision" rewritten** — now explains the **spawn-cost reality** table (tab ~10–20s vs Agent ~2s), the **model-tiered defaults**, and a **per-task override** mechanism via the dispatch brief's `Spawn mode:` line.
- **`king.md` dispatch brief schema** — added optional `Spawn mode: tab|background|split` field. Master honours the override; otherwise uses model-tiered defaults.

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

- **`.kingdom/.setting/reference/cmux.md` § "Spawn → name → color → describe (the 4-call pattern)"** — explicit doc of the hard-won 4-call sequence per workspace creation, with the full `spawn_lane ()` helper and rationale for each step.
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

- **`.kingdom/.setting/reference/cmux.md` § "Attention markers — mark-read / mark-unread"** — new section before "Dynamic workspace descriptions":
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

- **`.kingdom/.setting/reference/cmux.md` § "Dynamic workspace descriptions"** — full reference for live state lines:
  - **State-emoji vocabulary**: `▶` running · `⏸` waiting · `⚠` needs attention · `✅` done · `❌` failed · `🐾` idle · `▰▰▰▱` progress bar
  - **Per-role description schema** with concrete examples for King / Worker / Co-worker / Watchman
  - **Update-site table** — when each role rewrites its description (12 trigger points across roles)
  - **`cmux_set_state` bash helper** — common pattern across all role docs
  - **Watchman-cross-update** — when the blocked-lane scan finds a stalled lane, it ALSO updates that lane's description to `⚠ Blocked · permission prompt` (visible immediately in sidebar)
- **`worker.md` "Live workspace description" subsection** — workers update at every layer transition (L1 → L2 → L3 → L4) + closer + idle, with the 4-layer progress bar `▰▰▰▰`.
- **`king.md` "Live workspace description" subsection** — King updates at idle / gate-start / gate-pass / gate-fail / pushed. Push-state holds for 5 min then reverts to idle.

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

- **`king.md` § "Auto-gate on completion (King never sits on an un-gated sentinel)"** — new top-level section before "Working WITH the Watchman". Defines:
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
- **`.kingdom/.setting/roles/worker.md` "Spawning sub-agents" section restructured.** Tab is now the documented default; `Agent(...)` is the **opt-in** exception for cheap Haiku fan-outs (Layer-1 Discovery scans, doc digests, fan-outs of >3 short agents where N tabs would be cramped). Three options total: `"tab"` (default), `"background"`, `"split"`.
- **Visual fan-out example added** — concrete ASCII diagram of worker-1's workspace as 3 Sonnet sub-agents spawn for Layer 3 parallel code edits, then disappear cleanly when each writes its sentinel.

### Added

- **5-step closer robustness clarified** — Step 5 (`cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`) MUST fire on every exit path (success / blocked / error). Documented as a wrapper-pattern in the sub-agent's brief template.
- **Watchman orphan-tab sweep** — new `/loop` tick duty. Enumerates each lane master workspace's surfaces, finds tabs with title prefix `"🐱 sub"` whose recent output mentions "sentinel written" / "closer complete" AND have been idle ≥5 min → closes them via `cmux tab-action --action close`. Belt-and-suspenders for the rare case Step 5 fails (cmux unreachable, killed process). Sweeps logged to `master_agent.log`.

### Why this matters

Real test feedback: "and when master working i don't see it parallel work with sub-agent yet, if sub-agent running it will split screen or it will make more tab, tab or screen must auto close tho". Two fixes in one release: (1) make the default visible (flip default to `"tab"`), (2) make auto-close bulletproof (Step 5 + watchman sweep).

### Compatibility notes

- **`kingdom.json` schema is additive** — existing kingdoms without `cmux.subAgentSpawnDefault` get the new `"tab"` default automatically. To preserve v0.14.8 behaviour, set `"subAgentSpawnDefault": "background"` in your kingdom.json.
- **Cost note** — tabs are full Claude Code sessions; spawning many simultaneously costs more than headless Agent() calls. For cheap Haiku fan-outs (Layer-1 scans, doc digests), masters should explicitly use `Agent(...)` — documented in worker.md.

### Also bundled (small cleanup)

- **`king.md` kickoff synthesis** — removed the duplicate "Good morning. Checking watchman state..." paragraph that was left dangling after v0.14.8. Now there's exactly one synthesis block (the merged Context loaded + Watchman state version).

---

## [0.14.8] — 2026-05-18

The "King reads ALL context at session start" release. v0.14.7 made the King read watchman state at every decision point — but that's only half the picture. The other half is the foundational context Ter has written down: workspace CLAUDE.md, project CLAUDE.md, auto-memory entries, personal notes. Without those, the King may dispatch tasks against rules Ter explicitly documented ("never use Prisma migrations", "confirm before every edit", "no source-project attribution in commits") — burning trust + cycles re-correcting.

### Added

- **`king.md` Step −1 — Session-start context load (mandatory)** — King reads, in this order, before doing ANYTHING else (including watchman state):
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

- **`.kingdom/.setting/roles/king.md` § "Working WITH the Watchman (mandatory when one exists)"** — new top-level section right after King's responsibilities. Defines:
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

- **Watchman blocked-lane scan** — new duty in `watchman.md`. Every `/loop` tick, watchman `cmux capture-pane`s each lane workspace and pattern-matches the last 30 lines against:
  - `Do you want to proceed\?` — Claude Code's standard permission prompt
  - `Esc to cancel` — same prompt's footer
  - `\[y/N\]` — common interactive y/n confirmations
  - `allow .* during this session` — session-scoped permission option
  - `Press Enter` — generic "press enter to continue" prompts

  When any pattern matches, watchman fires **dual** `cmux notify`:
  - `--surface <lane>` → blue ring on the lane's pane + tab lights up
  - `--workspace $KING_WS` → sidebar badge on King's workspace + bell-panel entry

  Idempotent + debounced via `watchman_state.json.blocked_lanes` — won't re-notify the same blocked lane every tick. Clears when the lane unblocks.
- **`.kingdom/.setting/reference/cmux.md` § Read pane contents** — documents `cmux capture-pane` + `cmux read-screen`, the watchman pattern set, and the prevention-vs-detection split (prevention preferred via expanded allow-list; detection catches what slips through).

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

- **4-step closer Step 4** in `worker.md` and `co-worker.md` — mandatory dual `cmux notify` calls:
  - `--surface "$CMUX_SURFACE_ID"` → blue ring on the lane's own pane + tab lights up
  - `--workspace "$KING_WS"` → badge on King's sidebar entry + bell-panel logs the event
  - Previously was an optional "+ optional `cmux notify --pane <self>`" with the wrong flag (`--pane` doesn't exist; correct is `--surface`).
- **Watchman alerts** in `watchman.md` — schema standardised: `--title "🕵️ watchman-N"` + `--subtitle "<event class>"` (e.g., `develop RED`, `CI failed · PR #N`, `Ready to merge · PR #N`) + `--body "<one-line context>"`. All target `--workspace "$KING_WS"`.
- **King gate notifications** in `king.md`:
  - Pre-commit gate FAIL → notify originating master's workspace (so the lane gets a sidebar badge + ring)
  - Pre-commit gate PASS, asking "push?" → notify `$KING_WS` (Ter may be in another workspace; sidebar badge surfaces the prompt)

### Added

- **`.kingdom/.setting/reference/cmux.md` § Notification system** — fully rewritten with three visible surfaces table (ring / badge / panel), kingdom notification schema (8 canonical events), targeting cheat-sheet, "what NOT to notify" list. Single source of truth for every notification call across the kit.

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
- **`.kingdom/.setting/reference/cmux.md` updated** with the workspace-action vs tab-action distinction (new "Rename" section table, new "Set workspace color + description" section, new "Common pitfalls" row for the renamed-wrong-thing case).

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

- **`.kingdom/.setting/reference/cmux.md`** — new canonical cmux reference doc for every role. 300+ lines covering: three-tier hierarchy (Workspace → Tab → Split), every cmux command kingdom uses (`new-workspace`, `tab-action`, `new-split`, `send`, `notify`, `rename-tab`, `identify`, `tree`, `list-panes`), env vars (`CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`), common pitfalls, and reference URLs. All other role docs link here for cmux details instead of repeating commands inline. Scaffolded by `/kingdom:init` into every workspace.
- **Three-tier hierarchy** (PRIMARY mode):
  - 🏢 **Workspace** per master — King + every worker + co-worker + watchman gets its own cmux.app workspace (sidebar entry, full screen, native session restore).
  - 📑 **Tab** for visible sub-agent spawns inside a master's workspace — auto-closes on sentinel flag (new 5-step closer).
  - 🪟 **Split** for predefined dual-view (watchman's claude + `gh pr watch`).
- **`kingdom.json.cmux` block** — controls layout behaviour: `pinKingWorkspace` (true), `workspaceColors` (per role), `subAgentSpawnDefault` ("background" — Agent calls; alternative "tab"), `watchmanLayout` (vertical split with top=claude, bottom=`gh pr list --watch`).
- **5-step closer for tab-spawned sub-agents** — extends the standard 4-step closer with Step 5: `cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`. Tabs self-destruct after the sentinel flag; master doesn't clean up. Agent-spawned sub-agents (default, headless) skip Step 5 (no tab to close).
- **`commands/start.md` Phase 5 + 6 rewrite** — PRIMARY mode uses `cmux new-workspace --name --cwd --command "claude"` per lane (no more broken `cmux claude-teams`). Returns workspace refs which persist to `$LOGS/workspace-refs.env` so King + watchman can address lanes by stable refs across session restarts.
- **`commands/doctor.md` Check 1 expanded** — now verifies the 9 specific cmux commands kingdom uses (`new-workspace`, `new-split`, `tab-action`, `send`, `notify`, `rename-tab`, `identify`, `tree`, `list-panes`). Catches cmux versions too old for kingdom v0.13.
- **King dispatch via workspace refs** — `king.md` updated: `cmux send --workspace "$WORKER_WS_1" -- "<brief>"` replaces the broken `cmux send --lane "worker-1"` (which doesn't exist in manaflow/cmux).

### Changed

- **`commands/start.md` Phase 5 + 6** — full rewrite. PRIMARY mode uses workspace-per-master; FALLBACK (raw tmux) tightened with pane-title emoji prefixes; HEADLESS unchanged.
- **`.kingdom/.setting/roles/king.md` dispatch templates** — `--lane <name>` → `--workspace <ref>` everywhere; ref sourced from `$LOGS/workspace-refs.env`.
- **`.kingdom/.setting/roles/worker.md`** — new "Spawning sub-agents — Tab vs Agent decision" section at top; 5-step closer added inline after the 4-step closer doc (5-step applies only to tab-spawned sub-agents).
- **`.kingdom/.setting/roles/watchman.md`** — documents the optional vertical split layout for the watchman workspace.
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
- **King action table** (in `king.md` → "Reviewing watchman audit findings") gets two new rows for Gap A and Gap B with the recommended follow-up per row (backfill log line vs dispatch doc-update task).
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
- **King assigns task scope per dispatch**, not per config. New "Dispatch brief schema" section in `king.md` documents what King sends each worker. Cross-lane conflict prevention shifted entirely to (a) King's Layer-1 planning (sub-agents scan candidate task overlap) + (b) FINAL `git merge-tree` check at push gate. The combination replaces what `ownsPaths` did in v0.4.0 without the path-staleness problem.
- **`gate.*` keys are now explicitly arbitrary.** Template still ships `typecheck`/`tests`/`smoke`/`lint` as dev-friendly defaults, but role docs + template comments make clear the keys are user-defined. Finance kingdoms use `validate`/`audit`; science kingdoms use `reproduce`/`peer-review`; writing kingdoms use `spellcheck`/`fact-check`. Same `kingdom.json` schema, different vocabulary.
- **Domain-agnostic framing.** README hero + tagline + worker.md now state explicitly: kingdom works for any domain that uses git for versioning, not just software dev.
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
- **Watchman docs audit duty** — new section in `watchman.md` granting watchman scoped write authority on its own project's `tasks/`+`logs/` for low-risk fixes during idle `/loop` time (stale checkboxes, missing log lines, dead `[[name]]` links). Higher-risk findings (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md` for King review.
- **`WATCH_DOCS_AUDIT.md`** — new single-file-per-project rolling artifact at `<workspace>/.kingdom/<project>/logs/WATCH_DOCS_AUDIT.md`. Watchman appends findings; King reviews + clears bullets after acting.
- **"Reviewing watchman audit findings" section** in `king.md` — documents how/when King consumes `WATCH_DOCS_AUDIT.md` and what to do with each finding category.
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
- **Multi-layer planning** — explicit recursive fan-out pattern in lane master execution. Layer 1 (Discovery, Haiku fan-out) → Layer 2 (Strategy, Sonnet/Opus) → Layer 3 (Execution, Sonnet parallel) → Layer 4 (Verification). Documented as the canonical pattern in `worker.md`; cross-referenced from `king.md`, `co-worker.md`, `index.md`.
- **Role Control authoritative table** in `index.md` — single source of truth for what each role can/can't do (writes / reads / spawns / pushes / edits / plans). Per-role files now document HOW; this table defines WHAT.
- **Auto-detect outer host mode** — `/kingdom:start` and `/kingdom:doctor` now auto-detect PRIMARY (manaflow/cmux.app) vs FALLBACK (raw tmux) vs HEADLESS (`claude -p`). No user config needed; King adapts to what's installed.
- **Native Mermaid diagrams** — every ASCII chart in role docs, README, and git.md converted to Mermaid (16 diagrams total: 2 in README + 4 in git.md + 4 in king.md + 3 in worker.md + 2 in watchman.md + 1 in co-worker.md + 1 in index.md). No theme directive — GitHub auto-adapts to user's light/dark theme.
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
- 6 role docs in `templates/role-files/`: `index.md`, `king.md`, `worker.md`, `co-worker.md`, `watchman.md`, `git.md`.
- `kingdom.json.template` config template.
- `CMUX-Guide.md` (manaflow/cmux reference).
- `TMUX-Guide.md` (tmux 101 for the fallback path).
- README with install + usage + role overview.
- LICENSE (MIT).
