# Stability / performance audit — 2026-06-10 (v0.43.5)

5-agent Sonnet audit: core functions, cmux/tmux backends, commands, roles+rules, reference/cards/config.
~70 findings. Severity counts: 9 critical, 14 high, 24 medium, rest low.

---

## CRITICAL

### C1. `work.md`: `$POD_ASSIGNMENTS` is used but never built — story-pod dispatch is dead code
`commands/work.md:464-491`. The loop `for POD in $POD_ASSIGNMENTS` iterates a variable no code ever assigns (the comment describes the intended R50 partitioning, but the partition step was never written). With `integration.enabled=true`, story branches, Senior briefs, and `spawn_loop` never fire — zero iterations, zero errors.
**Fix:** implement the partition step (read task-ledger, group by `$UNIT`, emit `<story-id>=<worker-a,worker-b>` lines) before the loop.

### C2. `work.md`: `$TOPIC` unset on the solo-worker path → `git checkout -b "feature/"`
`commands/work.md:687` uses `${TOPIC}` but only the story-pod path (line 602) ever sets it. Solo path Step 6 creates a branch literally named `feature/` (collides on second PR).
**Fix:** `TOPIC="${SUBTASK_ID}"; export TOPIC` in the solo Tier-2-pass block.

### C3. `pick_skills_for_task.sh:7` reads `skill-routing.md` from the wrong path — skill routing silently dead
Reads `$WS/.kingdom/.setting/skill-routing.md`; the file lives at `.setting/reference/skill-routing.md` (where init/update copy it). `awk` on a missing file exits 0 with no output → every dispatch gets zero skills, no error.
**Fix:** `local routing="$WS/.kingdom/.setting/reference/skill-routing.md"`.

### C4. `kingdom_overlay_lane.sh:30`: pipe masks `git diff` failure → silent empty overlay
`git diff origin/$base..$lane | git apply --3way` — exit status is `git apply`'s. If `$lane` doesn't exist or diff fails, apply gets empty input and returns 0; the overlay "succeeds" with zero changes and Tier-2 gates run against an empty kingdom branch (the exact failure class v0.31.1 fixed elsewhere).
**Fix:** capture the diff to a variable, fail on diff error / empty patch, then apply.

### C5. `run_tier2_on_story.sh`: false PASS when `kingdom.json` missing
`ok=1` initial; `jq … 2>/dev/null` on a missing file emits nothing; loop never runs; returns 0 (pass). `run_tier1_gate`/`run_tier2_gate` both have the `[ -f "$kjson" ] || return 1` guard — this one was missed.
**Fix:** add the same fail-closed guard.

### C6. `generate_pr_body_from_task_file.sh`: hangs on missing task file
If the `ls -1t …` glob finds nothing, `task_file=""` and `awk … ""` inside the heredoc reads **stdin** — blocks forever.
**Fix:** `[ -n "$task_file" ] && [ -f "$task_file" ] || return 1` before the heredoc.

### C7. `roles/watchman.md`: `$WORKTREES` used at lines 299/412/441/585 but never defined
Expands empty → `git -C /worker-1 …` against filesystem root, errors swallowed by `2>/dev/null`. Every Duty-1 per-lane diff review silently reviews **nothing**, every tick. Line 441 is also unquoted (zsh nomatch hazard).
**Fix:** add `WORKTREES="$PROJ/.worktrees"` to the tick preamble; quote line 441.

### C8. tmux backend: `cmux_new_split` direction words not translated; sub-agent pool entirely broken under tmux
- `kingdom_use_tmux_backend.sh:23` passes `right`/`left`/`up`/`down` straight to `tmux split-window`, which treats the word as a **shell command to run in the new pane**. Needs a `right|left→-h`, `up|down→-v` case map.
- `spawn_pool_slot` / `spawn_subagent_tab` / `init_subagent_pool` / `spawn_subagent_from_pool` all grep for `surface:[0-9]+`; tmux pane IDs are `%N` → never match → the entire pool/visible-sub-agent system is a silent no-op under tmux. Need tmux overrides in `kingdom_use_tmux_backend`.

### C9. `render_card.sh:9` resolves cards via `$WS`, which no command file ever sets
Path becomes `/.kingdom/.setting/cards/…` → "Card not found" for every render. Also: `save.md`/`init.md`/`update.md` call `render_card` without sourcing `_load.sh` first (command-not-found in raw bash). And the variant suffix (`welcome/morning`) is parsed but ignored — the whole card file is always dumped.
**Fix:** `local card_file="${WS:-$_KFN_DIR/..}/cards/${base}.md"` style fallback + `source _load.sh` in the three commands + implement variant extraction.

---

## HIGH

### H1. `work.md` cross-block variable dependencies (bash state does NOT persist between blocks)
- `$KJSON` consumed in Step 0 (lines 39, 47-50) but assigned in Step 0.4 (line 166) → shape defaults always fall back to hardcoded values.
- `$BASE` set line 212, used in poll loop (627, 641) — never exported → overlay against `origin/` if blocks are separate invocations.
- `$SUBTASK_ID` set in poll loop, used in Step 6 — not exported → empty PR bodies.
- `$PRS_OPENED_TODAY` / `$PODS_DONE_TODAY` init Step 4, incremented Step 6 — not exported → pr-limit/pod-limit ceilings never accumulate.
**Fix:** export at assignment sites (PROJ, KING_WS, REFS_FILE, KJSON, BASE, SUBTASK_ID, counters).

### H2. Sentinel glob misses the model prefix — resume queue re-lists completed tasks forever
`work.md:350`, `archive.md:94`, `save.md:73` use `*"__${lane}__${id}.flag"`, but the closer spec writes `<UTC>__<model>-<lane>__<id>.flag` (e.g. `…__opus-worker-1__FE-1.flag`). `opus-worker-1` ≠ `worker-1` → completed tasks look in-flight every session restart; archive/save closed-detection also misses.
**Fix:** glob `*"__"*"-${lane}__${task_id}.flag"` in all three sites.

### H3. Done-flags never pruned post-push in `work.md` Step 6
`king.md:480` specifies `rm -f "$LOGS/done/"*"-${LANE}.flag"` after push; `work.md` Step 6 omits it → `done/` grows unbounded, the 10s poll scan goes O(N-pushes). (This is the v0.42.0 longevity fix not actually wired into the command file.)

### H4. zsh nomatch aborts in `self-care.md` (lines 218/240/247/340) and `init.md` (82-86, 237)
Neither file sources `_load.sh` (which sets `no_nomatch`), so `for KJSON in "$PWD"/.kingdom/*/kingdom.json` aborts the whole block when no project exists. Also `work.md:61` (Step 0.0 interactive block) runs **before** `_load.sh` is sourced. The v0.43.4 "session-wide" no_nomatch only holds if Step 0.4 ran first.
**Fix:** `[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch` at the top of each affected block, or use `find`.

### H5. `kingdom_resync_after_merge.sh`: unguarded `$WORKTREE` + only rebases `worker-*`
- If `$WORKTREE` unset, `git -C ""` operates on **cwd** — and this function runs `reset --hard`, `clean -fd`, `branch -f`, `rebase`. Destructive on whatever repo you happen to be in.
- Lane rebase loop lists only `worker-*`; `co-worker-*`/`watchman-*` drift from base forever.

### H6. `random_task_done_line.sh:18-22`: infinite loop when the pool has exactly 1 line
`while true; idx=$((RANDOM % 1))` always 0; `[ "0" != "0" ]` never breaks → session hang.

### H7. `pattern_grep_fanout.sh:12`: BSD grep doesn't support `--include='*.{ts,tsx,…}'` brace patterns
Zero files ever match on macOS — the scan silently returns nothing for all 11 extensions.

### H8. JSON injection in `spawn_loop.sh:16` / `spawn_subagent_tab.sh:12,14`
`$brief` interpolated raw into `{"text":"$brief\n"}` — any `"` or `\` in a task brief malforms the JSON, the RPC silently fails, the lane sits idle at a prompt. Build payloads with `jq -n --arg`.

### H9. tmux fallback: King never gets blocked-lane alerts
`cmux_attention_override` tmux stub (`kingdom_use_tmux_backend.sh:38`) drops 5 of 7 args including the `tmux_notify` to the King — blocked lanes go unnoticed on the tmux platform. Also `cmux_list_panes`/`cmux_list_pane_surfaces` tmux routes return non-JSON / ignore `--workspace`, breaking all jq callers (watchman handle resolution + orphan-tab sweep).

### H10. Config schema splits (template vs code)
- Template `cmux.subAgentPool.models` (array) vs code reads `.model` (string) → user tuning has no effect.
- `welcome.userName` / `welcome.weather` read by code (`fetch_weather_line`) but absent from template; `USER_NAME` never populated from kingdom.json anywhere → feature dead; weather fails **open** (curls external API even when config missing).
- `work.md:193` fallback color `"violet"` is not a valid cmux color (template says Purple; cmux.md itself warns about violet). Same stale `violet` in `cmux.md:452,677`, `docs/cmux-integration.md:26-27,105`, `cards/spawn-complete.md:32`.

---

## MEDIUM (selected)

- `cmux_send` paste-collapse re-check (`cmux_send.sh:18`) calls `cmux_read_screen "$ref"` which always uses `--workspace` — for `surface:` refs the K3 fix silently doesn't apply.
- `spawn_subagent_tab.sh:8-10` discards the tab-action result and grabs `tail -1` of ALL surfaces — race under concurrent spawns; `spawn_pool_slot` does it right.
- `spawn_subagent_from_pool.sh`: head-then-sed pool consumption is a TOCTOU race — two concurrent dispatchers get the same surface.
- `attach_or_create_worktree.sh` / `carve_and_push_feature.sh` / `kingdom_review_surface.sh`: the last 3 helpers still using cwd-dependent bare `git` (no `-C`), no error propagation (`checkout` failure still pushes).
- `_bounded_wait.sh:30-35`: killed survivors never `wait`ed → zombies accumulate on every timeout.
- `parallel_edit_fanout.sh` / `save_session_state.sh`: mktemp artifacts leak on early return (no `trap`).
- `save_session_state.sh:33-42`: O(lanes × tasks) `ls` subprocesses per save (~1600 procs at 8×200).
- `cross_story_scan.sh:12`: `git merge-tree --write-tree` needs git ≥2.38; older git → silent false "no drift".
- `init_subagent_pool.sh`: unset `$KJSON` → `seq 1 ""` counts down `1 0` → spawns 2 slots instead of failing.
- `work.md` Step 1: "4 specialists" label but 5 in the array; `$SENIOR_WS` not checked for empty before `cmux_send`.
- `self-care.md:480-482`: exports `N_PROJECTS` + `*_VERSION` vars that nothing ever sets → doctor card blanks.
- `browser_verify.sh:13`: only `"` escaped — backticks/backslashes/`$( )` in `$expect` shell-expand or inject JS.
- `tmux_notify` with empty ws → `tmux_set_state "" …` targets invalid `"kingdom:"`.
- `cmux_attention_clear` tmux stub drops the description-restore arg → stale "⚠ Blocked" text.
- R27 references `watchman_backfill_pr_numbers` — a function that does not exist anywhere (real impl is `parallel_edit_fanout` in watchman.md).
- `roles/king.md:682-713` Step −1 omits R14-mandated reads 0/3/4 (rules/index.md, README, docs index) — a Tier-1 rule contradiction.
- `roles/king.md:992-993`: live `git merge --no-edit` on the kingdom branch at creation (R4 tension) — replace with `git reset --hard origin/$BASE` or mark one-time-only.
- `cards/audit-summary.md` is an orphan (never rendered); its "Used by" metadata is stale.

## LOW (selected)

- Stale `_primitives.md` § links in 7 rule files + 3 cards + skill-routing.md (point at `functions/<name>.sh` instead).
- `rules.md:5` and `index.md:12` say `R01…R52` (should be R53).
- `rules/R14:5` "(this file)" self-reference is wrong post-v0.34 split.
- 8 demoted rules still carry `— Tier 1` heading suffix (acknowledged open thread).
- `init.md:237` `N_ROLE_DOCS` counts only top-level `*.md` (3) — misses ~57 in subdirs.
- `update.md:51-57` runs `diff -rq` 4× — capture once.
- `work.md:164-165` calls `cmux_identify` twice for one JSON.
- `work.md` step numbering gap (Step 2 missing).
- `docs/faq.md:50` documents `git.mergeStyle` which exists nowhere.
- `docs/configuration.md` example JSON missing `subAgents`/`integration`/`seniors`.
- `compute_task_duration.sh:11`: GNU-stat fallback lacks `2>/dev/null`.
- `browser_verify` fixed `sleep 2`; `browser_open` single-quote URL injection.
- `tmux_workspace_action.sh:10`: `shift 2 2>/dev/null` suppresses message, not exit status.

---

## Verified healthy

- All four version stamps agree at 0.43.5; manifest's 99 functions all exist on disk; counts (53 rules 10/38/5, 11 commands, 26 cards) all match.
- Every function called from commands/ exists (the historic `overlay_lane_onto_kingdom` ghost survives only as a comment).
- All 22 `cmux_*` wrappers have tmux routes (the gaps are in the higher-level spawn helpers, C8).
- No pre-v0.40 function names anywhere; no ANSI in cards; skill-routing table format matches the awk parser.
- No R37/R38-vs-R53 or R40-vs-R51 contradictions (explicitly resolved in the docs).
