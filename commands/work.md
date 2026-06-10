---
description: Daily work cycle. Audit + spawn lanes + dispatch + poll. Shape overrides per-session. Interactive when no args.
argument-hint: [project] [lane=N] [worker=N] [co-worker=N] [watchman=N] [senior=N] [pr-limit=N] [pod-limit=N]
---

You are running the kingdom's **full daily work cycle** as one orchestrated flow. The user typed ONE command and expects the kingdom to "just run the day": audit the project state, spawn the lanes, brief the user with the local date+time and a suggested next task, then — after the user picks a dispatch mode (Step 3.6: seek / assign / resume-only) — auto-gate the resulting work until something needs a human decision. Block ONLY on genuine human-decision points (the dispatch-mode choice, review/push approval, blocked lanes).

## Step 0 — Resolve project + parse arguments (3 invocation modes)

`/kingdom:work` accepts three invocation shapes:

| Form | Behaviour |
|---|---|
| `/kingdom:work <project> [lane=N] [worker=N] [co-worker=N] [watchman=N] [senior=N] [pr-limit=N] [pod-limit=N]` | Standard: explicit project + optional shape + optional limits. `lane=N` sets a total-lane budget the King auto-composes. Skip to Step 0.1. |
| `/kingdom:work <project>` | Standard: explicit project, no caps, no overrides. Skip to Step 0.1. |
| `/kingdom:work` *(no args)* | **Interactive mode:** King asks "What do you want to work on today?", waits for natural-language reply, auto-parses project + task scope. See Step 0.0 below. |

### Parameters (per-session; none rewrite `kingdom.json`)

**Shape (choose one style):**
- `lane=N` — total lanes; the King auto-composes the split (workers + 1 watchman; story pods when `senior=K` is pinned), honoring any per-role pin.
- per-role: `worker=N`, `co-worker=N`, `watchman=N`, `senior=N`.

**Limits (independent hard ceilings; both optional):**
- `pr-limit=N` — stop after **N PRs** opened today.
- `pod-limit=N` — stop after **N pods** today (a pod = one unit of work: milestone / story / task / issue).

**Parsing is forgiving:** singular OR plural is accepted (`worker=`/`workers=`, `senior=`/`seniors=`, `watchman=`/`watchmen=`, `co-worker=`/`co-workers=`, `lane=`/`lanes=`). This doc and the argument hint always show the **singular** form.

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null  # H4: this block precedes _load.sh; guard bare globs locally

# Resolve project (first positional, non-key token) + derive KJSON HERE so the
# jq shape reads below see the real config. (H-x: bash state does NOT persist
# across markdown bash blocks — KJSON was historically assigned in Step 0.4, so
# the shape jq reads in THIS block always fell back to hardcoded defaults.)
# Interactive no-args mode resolves $project later (Step 0.0); this is for the
# standard `/kingdom:work <project> …` shape.
project=$(echo " $ARGUMENTS" | tr ' ' '\n' | grep -vE '=' | grep -vE '^$' | head -1)
if [ -n "$project" ] && [ -d "$PWD/.kingdom/${project}" ]; then
  KJSON="$PWD/.kingdom/${project}/kingdom.json"
  export project KJSON
else
  KJSON=""   # interactive mode: set after Step 0.0 resolves $project
fi

# Normalize args — accept singular or plural; canonical form is singular.
arg () { echo " $ARGUMENTS" | grep -oE "(^| )$1=[^ ]+" | tail -1 | cut -d= -f2; }
ARG_WORKER=$(arg 'workers?');     ARG_COWORKER=$(arg 'co-workers?')
ARG_WATCHMAN=$(arg 'watch(man|men)'); ARG_SENIOR=$(arg 'seniors?')
ARG_LANE=$(arg 'lanes?');          PR_LIMIT=$(arg 'pr-limit'); POD_LIMIT=$(arg 'pod-limit')

# Effective shape resolution (lane=N auto-composes; else per-role override wins over JSON).
# Guard: in interactive mode $KJSON is empty until Step 0.0 resolves $project; defer
# shape resolution to Step 0.4 in that case (the jq reads there re-derive KJSON).
if [ -z "$KJSON" ]; then
  echo "ℹ️ Shape deferred to Step 0.4 (interactive mode — project not yet resolved)."
elif [ -n "$ARG_LANE" ]; then
  CAPV=$(jq -r '.shape.sanityCap // 10' "$KJSON"); LANE_BUDGET="$ARG_LANE"
  [ "$LANE_BUDGET" -gt "$CAPV" ] && { echo "⚠️ lane=$LANE_BUDGET exceeds sanityCap=$CAPV; capping to $CAPV"; LANE_BUDGET="$CAPV"; }
  WATCHMEN=${ARG_WATCHMAN:-$([ "$LANE_BUDGET" -ge 2 ] && echo 1 || echo 0)}
  SENIORS=${ARG_SENIOR:-0}; COWORKERS=${ARG_COWORKER:-0}
  WORKERS=${ARG_WORKER:-$(( LANE_BUDGET - WATCHMEN - SENIORS - COWORKERS ))}
  [ "$WORKERS" -lt 0 ] && WORKERS=0
  echo "👑 lane=$LANE_BUDGET → worker=$WORKERS co-worker=$COWORKERS watchman=$WATCHMEN senior=$SENIORS (King's composition; pins honored)"
else
  WORKERS=${ARG_WORKER:-$(jq -r '.shape.workers // 3' "$KJSON")}
  COWORKERS=${ARG_COWORKER:-$(jq -r '.shape["co-workers"] // 1' "$KJSON")}
  WATCHMEN=${ARG_WATCHMAN:-$(jq -r '.shape.watchman // 1' "$KJSON")}
  SENIORS=${ARG_SENIOR:-$(jq -r '.shape.seniors // 0' "$KJSON")}
fi
```

Any shape value (or `lane=N`) over `sanityCap` is warned + capped. `pr-limit` and `pod-limit` are independent: whichever the run hits first stops dispatch. Pinning `senior=K` is how you ask for K story pods.

### Step 0.0 — Interactive mode (no-args invocation only)

If `$ARGUMENTS` is empty, do NOT default to `basename "$PWD"`. Instead:

```bash
# H4: this block runs BEFORE Step 0.4 sources _load.sh, so the session-wide
# no_nomatch it sets isn't active yet. Guard locally so a bare glob with no
# match (e.g. no .kingdom/ projects scaffolded) doesn't abort the whole block.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
PROJECTS=$(ls -d "$PWD"/.kingdom/*/ 2>/dev/null \
  | xargs -I{} basename {} | grep -v '^\.setting$')
N_PROJECTS=$(echo "$PROJECTS" | grep -c .)

export AVAILABLE_PROJECTS="$PROJECTS" N_PROJECTS
render_card "what-to-work-on"
```

The card lists what's actionable RIGHT NOW (open PRs awaiting review, in-flight task files, project-ledger heads) so the user can pick from concrete options or type free-form.

**Then wait for the user's reply** (next chat message). Parse it as:

1. **Project name** — match against `${AVAILABLE_PROJECTS}` whitelist. Examples: `"bfg-swt"`, `"work on bfg-swt"`, `"the cert site"` — resolved by fuzzy substring match.
2. **Task scope** — everything else in the reply. Examples: `"fix login bug"`, `"continue worker-1's PDPA task"`, `"review PR 257"`.
3. **Inline limits** — `"5 PRs today"` → `pr-limit=5`; `"3 stories"` → `pod-limit=3`.
4. **Shape** — `"5 workers"` → `worker=5`; `"8 lanes"` → `lane=8`.

Resolve into normalised args:

```bash
project="<matched-project-name>"
task_hint="<free-form scope, OR empty>"
PR_LIMIT="<parsed N, or empty>"
POD_LIMIT="<parsed N, or empty>"
ARG_WORKER="<parsed N, or empty>"   # or ARG_LANE for a total budget
```

If the parse is ambiguous, King prints back the interpretation and asks for confirmation BEFORE proceeding:

```text
👑 Parsed:
   project    = bfg-swt
   task       = continue worker-1 PDPA (matched FE-P0-FOUND.5 task file)
   pr-limit   = (none)
   pod-limit  = (none)
   shape      = worker=3 co-worker=1 watchman=1 senior=1  (from kingdom.json)

   Proceed? Or correct the parse.
```

If the user types something unparseable (e.g. only `"hi"`, or a question), King replies in chat WITHOUT starting the kingdom. Treat it as conversational, not a `/kingdom:work` invocation.

**Resolved args from Step 0 or Step 0.0:**

- `project` — explicit positional OR fuzzy-matched from interactive reply. Verify `.kingdom/${project}/` exists; if missing, tell the user to run `/kingdom:init ${project}` first and stop.
- `PR_LIMIT` — hard ceiling on PRs opened today (optional).
- `POD_LIMIT` — hard ceiling on pods (units of work) today (optional).
- `task_hint` (interactive-mode only) — natural-language scope; King uses it as a strong prior in Step 0.6 resume-scan and `suggested-task` card synthesis.
- `WORKERS`, `COWORKERS`, `WATCHMEN`, `SENIORS` — effective shape for this session (override or from JSON).

### Step 0.1 — Print parse summary BEFORE acting

```text
👑 Parsed arguments:
   project    = bfg-swt
   shape      = worker=3 co-worker=1 watchman=1 senior=1  (from kingdom.json)
   pr-limit   = (none)
   pod-limit  = 5

Proceeding to resume-scan + spawn + kickoff...
```

If the parse is ambiguous (malformed value), print the issue and stop.

### Step 0.3 — The counting unit

Reference (table + rationale: what counts toward `pr-limit` / `pod-limit`): [`docs/work-cycle.md` § The counting unit](../docs/work-cycle.md#the-counting-unit-workmd-step-03). In short: the kingdom counts **sentinel fires** (≈ PRs), not sub-tasks or milestones; a story pod counts as **1**.

### Step 0.3.5 — Skill check (R41 · MANDATORY)

Before Step 0.4 visible-progress fires, resolve King's own process-skill set + verify the project's skill-routing table is current.

King's process skills (invoke directly, not via dispatch-brief):
- `superpowers:brainstorming` — if today's session involves designing new behaviour
- `superpowers:writing-plans` — if multi-step work needs structure
- `superpowers:systematic-debugging` — if today is mostly bug triage
- `superpowers:verification-before-completion` — invoked LATE in cycle, before any "done" claim per R22

Lane skills (computed per-dispatch via pick_skills_for_task in Step 4 from skill-routing.md):
- Domain skills land in dispatch-brief ${SUGGESTED_SKILLS} per R23
- If routing table returns 0 matches, fallback to system-reminder skill list (R41 auto-discovery)

Per R41, no-skill is a valid result. Don't invoke a vague match just to invoke something.

## Step 0.4 — Visible workspace progress IMMEDIATELY (R36, MANDATORY)

**Within ~1 second of `/kingdom:work` receipt, before anything else:** detect the backend (cmux.app vs other), then rename King's own workspace + set description. User must see the kingdom responding, not stare at an unchanged sidebar.

```bash
# Backend detection FIRST — load both backends + pick cmux (cmux.app) or tmux (any other terminal).
# Detection is PER-PROCESS: this King reads its OWN env, so cmux.app being open in another window
# is irrelevant — only the app that launched THIS session counts (see index.md § Multi-session).
source "$PWD/.kingdom/.setting/functions/_load.sh"
load_feature core              # loads cmux + tmux backends + the detector
# Project-scope the tmux session so TWO kingdoms (e.g. 2 Ghostty windows on different projects)
# never share one tmux session. cmux isolates per-window automatically (cmux_identify = caller's window).
export KINGDOM_TMUX_SESSION="kingdom-$(printf '%s' "$project" | tr -c 'A-Za-z0-9_-' '-')"
kingdom_backend_init           # → export KINGDOM_BACKEND=cmux|tmux|standalone, activate, print which
[ "$KINGDOM_BACKEND" = "tmux" ] && tmux_setup_session "${project}" "$PWD"   # FALLBACK: create this project's tmux session
```

```bash
# Capture King's window + workspace refs (identify ONCE, parse twice — the call
# is a cmux round-trip; no reason to pay it twice for one JSON blob).
KING_ID=$(cmux_identify)
KING_WS=$(echo "$KING_ID" | jq -r .caller.workspace_ref)
KING_WIN=$(echo "$KING_ID" | jq -r .caller.window_ref)
# H-x: re-derive + export KJSON here so a fresh bash invocation of this block
# (state does not persist across blocks) still has the config path.
KJSON="$PWD/.kingdom/${project}/kingdom.json"
export KJSON KING_WS KING_WIN
KING_COLOR=$(jq -r '.cmux.workspaceColors.king // "amber"' "$KJSON")

# Rename + describe in parallel (cosmetic, fire-and-forget; R42: bounded wait)
RENAME_PIDS=""
cmux_workspace_action "$KING_WS" rename --title "👑 King · ${project}" &
RENAME_PIDS="$RENAME_PIDS $!"
cmux_workspace_action "$KING_WS" set-color --color "$KING_COLOR" &
RENAME_PIDS="$RENAME_PIDS $!"
cmux_set_state "$KING_WS" "▶" "Starting ${project}..." &
RENAME_PIDS="$RENAME_PIDS $!"
PIN_KING=$(jq -r '.cmux.pinKingWorkspace // true' "$KJSON")
if [ "$PIN_KING" = "true" ]; then
  cmux_workspace_action "$KING_WS" pin &
  RENAME_PIDS="$RENAME_PIDS $!"
fi
_bounded_wait 5 $RENAME_PIDS  # 4 cmux calls × <0.05s nominal; 5s budget covers slow socket

echo "👑 King's workspace renamed. Spawning lanes next..."
```

**Within ~5-10 seconds:** spawn all lane workspaces from the effective shape in parallel (per R28 parallel-by-default). Every `worker-N`, `co-worker-N`, `watchman-N` appears in the sidebar BEFORE audit/dispatch starts.

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: split $LANES_EXPECTED/$SPAWN_PIDS in the loops below (zsh doesn't word-split a scalar → else 1 bogus iteration); auto-reverts
PROJ="$PWD/${project}"
REFS_FILE="$PWD/.kingdom/${project}/logs/workspace-refs.env"
LOGS="$PWD/.kingdom/${project}/logs"
KJSON="${KJSON:-$PWD/.kingdom/${project}/kingdom.json}"   # H-x: re-derive if a fresh invocation
export PROJ REFS_FILE LOGS KJSON PROJECT="$project"
WORKER_COLOR=$(jq -r '.cmux.workspaceColors.worker // "Purple"' "$KJSON")
COWORKER_COLOR=$(jq -r '.cmux.workspaceColors.coworker // "blue"' "$KJSON")
WATCHMAN_COLOR=$(jq -r '.cmux.workspaceColors.watchman // "rose"' "$KJSON")
SENIOR_COLOR=$(jq -r '.cmux.workspaceColors.senior // "Teal"' "$KJSON")
# Effective senior count (v0.32.0+): already resolved in Step 0 (lane=N composition or
# per-role/JSON). Fall back to JSON only if Step 0 didn't set it.
SENIORS=${SENIORS:-$([ -n "$ARG_SENIOR" ] && echo "$ARG_SENIOR" || jq -r '.shape.seniors // 0' "$KJSON")}
mkdir -p "$(dirname "$REFS_FILE")"

# Build lane list from effective shape (seniors spawn empty on base; a story branch
# is checked out into the senior worktree at assignment time — Step 3.5).
LANES_EXPECTED=$(
  (
    for I in $(seq 1 "$WORKERS");   do echo "worker-$I";    done
    for I in $(seq 1 "$COWORKERS"); do echo "co-worker-$I"; done
    for I in $(seq 1 "$WATCHMEN");  do echo "watchman-$I";  done
    for I in $(seq 1 "$SENIORS");   do echo "senior-$I";    done
  )
)
BASE=$(jq -r '.git.base // "develop"' "$KJSON")
export BASE   # H-x: poll loop (Step 5) + Step 6 re-use this; export so separate invocations see it

SPAWN_PIDS=""
for lane in $LANES_EXPECTED; do
  (
    # Skip if workspace ref already present + alive (resume)
    if grep -q "^${lane}_WS=" "$REFS_FILE" 2>/dev/null; then
      ref=$(grep "^${lane}_WS=" "$REFS_FILE" | cut -d= -f2)
      cmux_tree | grep -qF "$ref" && exit 0
    fi
    # Ensure worktree exists
    [ -d "$PROJ/.worktrees/$lane" ] || \
      git -C "$PROJ" worktree add -b "$lane" ".worktrees/$lane" "origin/$BASE" 2>/dev/null
    # Pick color + label
    case "$lane" in
      senior-*)    color="$SENIOR_COLOR";   emoji="🎓" ;;
      worker-*)    color="$WORKER_COLOR";   emoji="👷" ;;
      co-worker-*) color="$COWORKER_COLOR"; emoji="🧑‍💼" ;;
      watchman-*)  color="$WATCHMAN_COLOR"; emoji="🕵️" ;;
    esac
    label="$emoji $lane"
    ref=$(spawn_master_workspace "$label" "$PROJ/.worktrees/$lane" "$color")
    [ -n "$ref" ] && echo "${lane}_WS=$ref" >> "$REFS_FILE"
    # R52: a freshly-spawned lane grounds itself FROM DISK before any task brief.
    # Inject /kingdom:self-<role> as the lane's first message — it re-reads the
    # canonical rules + its role spec from .kingdom/.setting/ (pull, not push), so
    # the lane's rule-knowledge can't inherit the King's drift. The later task
    # brief (Step 4 / Step 3.5) then carries only the task, not the rules.
    if [ -n "$ref" ]; then
      case "$lane" in
        senior-*)    cmux_send "$ref" "/kingdom:self-senior" ;;
        worker-*)    cmux_send "$ref" "/kingdom:self-worker" ;;
        co-worker-*) cmux_send "$ref" "/kingdom:self-co-worker" ;;
        watchman-*)  cmux_send "$ref" "/kingdom:self-watchman" ;;
      esac
    fi
    # v0.31.0 R39: watchmen are autonomous — auto-dispatch /loop on spawn (AFTER the
    # self-ground above). Without this, watchman sits at a shell prompt; the kingdom
    # appears half-alive until the user notices and asks "watchman why do nothing".
    case "$lane" in
      watchman-*) [ -n "$ref" ] && spawn_loop "$ref" "/loop" ;;
    esac
  ) &
  SPAWN_PIDS="$SPAWN_PIDS $!"
done
# R42: bounded wait — git worktree add can stall on .git/index.lock or half-created worktrees;
# 60s budget covers ~5 lanes × (worktree add 2s + 4 cmux calls 0.2s) with 5x safety margin.
_bounded_wait 60 $SPAWN_PIDS || echo "⚠️ spawn cycle hit 60s budget; survivors killed (check cmux_tree + worktree-refs.env)"

echo "👑 All lanes spawned. Sidebar shape confirmed."

export PROJECT="$project"
render_card "spawn-complete"
```

**ONLY AFTER Step 0.4 completes** does processing begin. Per R36, no "thinking for 30s while sidebar looks dead" allowed.

## Step 0.5 — Lane-readiness gate (R31, MANDATORY)

Before ANY further step, verify lane infrastructure. Per R31, the kingdom runs in three modes (PRIMARY=cmux / FALLBACK=tmux / AGENT=in-process) and the universal "lanes exist" check is **`.worktrees/<lane>/` directories**.

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $LANES_EXPECTED in the loops below (else 1 iteration over the whole blob); auto-reverts
MISSING_WORKTREES=""
for lane in $LANES_EXPECTED; do
  [ -d "$PROJ/.worktrees/$lane" ] || MISSING_WORKTREES="$MISSING_WORKTREES $lane"
done

if [ -n "$MISSING_WORKTREES" ]; then
  echo "Worktrees missing: $MISSING_WORKTREES"
  echo "Running spawn step to create them (idempotent)..."
  FORCE_START=1
fi

# Mode detection (PRIMARY vs FALLBACK vs AGENT)
MODE="AGENT"   # default
if command -v cmux >/dev/null 2>&1 && [ -f "$REFS_FILE" ]; then
  ALIVE_REFS=$(cmux_tree | grep -oE 'workspace:[0-9]+' | sort -u)
  ALL_ALIVE=1
  for lane in $LANES_EXPECTED; do
    REF=$(grep "^${lane}_WS=" "$REFS_FILE" 2>/dev/null | cut -d= -f2)
    if [ -z "$REF" ] || ! echo "$ALIVE_REFS" | grep -qF "$REF"; then
      ALL_ALIVE=0; break
    fi
  done
  [ "$ALL_ALIVE" = "1" ] && MODE="PRIMARY"
fi

if [ "$MODE" = "AGENT" ] && tmux ls 2>/dev/null | grep -q "^kingdom-${project}:"; then
  MODE="FALLBACK"
fi

echo "Dispatch mode: $MODE"
```

**If worktrees exist but PRIMARY/FALLBACK verification failed:** drop to `MODE=AGENT` and dispatch via `Agent(subagent_type=general-purpose, prompt="cd .worktrees/<lane> && ...")`. Do NOT re-spawn cmux workspaces. Re-spawning when worktrees are alive wastes time and may re-enter prior silent-failure modes.

**Stale-lane repair (U11, before the dispatch gate).** A rebase/merge can leave a lane's worktree pointing at a branch that no longer exists, or a `workspace-refs.env` entry whose cmux/tmux workspace died — the worktree dir exists (so the gate above passes) but the lane is effectively dead. Run the detect-and-report sweep; if it reports anything, show the user the report and offer the repair.

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
PROJ="${PROJ:-$PWD/${project}}"; REFS_FILE="${REFS_FILE:-$PWD/.kingdom/${project}/logs/workspace-refs.env}"

# Detect-and-report (no-args). Helper lives in functions/ (A1). It cross-checks
# each lane's worktree branch vs `git worktree list` + each refs.env entry vs the
# live backend, and prints a human-readable report of anything broken (empty = healthy).
STALE_REPORT=$(kingdom_repair_stale_lanes 2>/dev/null)
if [ -n "$STALE_REPORT" ]; then
  echo "⚠️ Stale lanes detected (worktree dir present but lane unusable):"
  echo "$STALE_REPORT"
  echo ""
  echo "Reply 'repair' to run kingdom_repair_stale_lanes --repair, or 'skip' to dispatch only to healthy lanes."
  # On 'repair': run the fixer, then re-run Step 0.4 spawn for any lane it freed.
  #   kingdom_repair_stale_lanes --repair
  # On 'skip': continue; the dispatch guards (guard_lane_workspace_exists) will
  #   route around the broken lanes.
fi
```

This is a human-decision point (repair mutates worktrees/branches per R35-adjacent caution): the King reports and waits for `repair`/`skip`, it does NOT auto-fix.

Render the `spawn-complete` card with the detected MODE.

**Never dispatch to a lane whose worktree directory does not exist.** That is the silent-failure invariant.

## Step 0.6 — Resume scan (R33, MANDATORY)

Read existing task state BEFORE deciding what to dispatch. King MUST resume in-flight work before opening new task files.

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null  # glob-heavy block; safe if a fresh invocation precedes _load.sh
TASKS_DIR="$PWD/.kingdom/${project}/tasks"
DONE_DIR="$PWD/.kingdom/${project}/logs/done"
export TASKS_DIR DONE_DIR   # Step 4 re-uses TASKS_DIR

STATE_FILE="$PWD/.kingdom/${project}/state.json"
RESUME_QUEUE=""
DECISION_QUEUE=""

# If a saved state.json exists from a prior /kingdom:save, pre-seed resume data
if [ -f "$STATE_FILE" ]; then
  SAVED_READY=$(jq -r '.ready_for_fresh_work // true' "$STATE_FILE")
  if [ "$SAVED_READY" = "false" ]; then
    echo "Prior session snapshot found (ready_for_fresh_work=false). Pre-populating resume queue..."
    # Read lane state from state.json and merge into task scan below
    SAVED_AT=$(jq -r '.saved_at_utc' "$STATE_FILE")
    echo "  Snapshot taken at: $SAVED_AT"
  fi
fi

# Scan tasks newest-first. Cap at the 40 most-recent files: in-flight tasks (no
# sentinel) are always recent, and /kingdom:archive moves closed/old task files
# out to tasks/archive/, so a month-old hot dir never makes this loop read 1000s
# of files every session + every dispatch round.
for task_file in $(ls -1t "$TASKS_DIR"/*.md 2>/dev/null | head -40); do
  base=$(basename "$task_file" .md)
  lane=$(echo "$base" | sed 's/^[0-9-]*T[0-9]*Z__//;s/__.*//')
  task_id=$(echo "$base" | sed 's/.*__//')

  task_status=$(grep -E '^- \[x\] (planning|executing|verifying|done|blocked|cancelled)' "$task_file" \
    | tail -1 | grep -oE '(planning|executing|verifying|done|blocked|cancelled)')   # NB: `task_status` not `status` — zsh `status` is a read-only special (alias for $?)
  [ -z "$task_status" ] && task_status="planning"

  # H2: sentinels are written as `<UTC>__<model>-<lane>__<id>.flag` (e.g.
  # `…__opus-worker-1__FE-1.flag`), so the lane segment carries a model prefix.
  # The old `*"__${lane}__…"` glob never matched → every completed task looked
  # in-flight on session restart. Match the model-prefixed shape.
  has_sentinel=0
  ls "$DONE_DIR"/*"__"*"-${lane}__${task_id}.flag" >/dev/null 2>&1 && has_sentinel=1

  case "$task_status" in
    done|cancelled)
      continue ;;
    blocked)
      DECISION_QUEUE+="${lane}|${task_id}|blocked"$'\n' ;;
    planning|executing|verifying)
      if [ "$has_sentinel" = "0" ]; then
        RESUME_QUEUE+="${lane}|${task_id}|${task_status}"$'\n'
      fi
      ;;
  esac
done

if [ -n "$RESUME_QUEUE" ] || [ -n "$DECISION_QUEUE" ]; then
  export RESUME_QUEUE DECISION_QUEUE
  render_card "resume-queue"
fi
```

**Resume queue takes priority over new dispatch.** In Step 4, lanes already in-flight get re-briefed with `[RESUME]` flag pointing at the same task ID + the last `## Progress notes` line. NEVER open a fresh task file for a lane that already has an in-flight one.

**Decision queue items** surface in the `suggested-task` card as `→ Unblock <task-id>` candidates.

## Step 1 — Audit (always — runs IN LANE WORKSPACES per R37)

*(Step 2 was folded into Step 1's audit pass when the day/start/update commands merged in v0.29.0 — numbering kept stable for cross-references.)*

The audit's specialists dispatch to lane workspaces via `cmux send`, not to in-process Agent() calls. Per R37, parallelisable work runs in lanes that the user can see.

```bash
echo "👑 Step 1/5 · Dispatching audit specialists to lanes (R37)..."

cmux_set_state "$KING_WS" "▶" "Audit in flight · 5 specialists across lanes"

SPECIALISTS=("audit-lead" "audit-a-project-scan" "audit-b-checkbox-reconcile" \
             "audit-c-digest-quality" "audit-d-log-repair")
N_SPECIALISTS=${#SPECIALISTS[@]}; export N_SPECIALISTS
AUDIT_START=$(date +%s)
i=0
for spec in "${SPECIALISTS[@]}"; do
  i=$((i + 1))
  lane="worker-${i}"
  lane_ws=$(grep "^${lane}_WS=" "$REFS_FILE" 2>/dev/null | cut -d= -f2)
  if [ -n "$lane_ws" ]; then
    BRIEF="/kingdom audit specialist: ${spec}. Scope: \`.kingdom/${project}/\`. \
Write findings to \`.kingdom/${project}/logs/audit-${spec}.md\` + sentinel."
    cmux_send "$lane_ws" "$BRIEF"
  else
    # No lane available — spawn as visible TAB inside King's workspace (R38: never Agent())
    cmux_tab_action new-terminal-right --workspace "$KING_WS" --focus false 2>/dev/null
  fi
done

# Poll for audit sentinels (parallel, each specialist writes its own)
poll_for_sentinels "audit-*" 180   # 3-min timeout total
```

Once the audit sentinels are in, render the `audit-summary` card so the user sees the pass landed (counts derive from the specialists' findings files; each defaults to 0 when a marker is absent, so the card never shows empty `${VARS}`):

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally instead of aborting

AUDIT_DIR=".kingdom/${project}/logs"
# Wall-clock for the audit phase (whole seconds → "Nm Ns")
AUDIT_SECS=$(( $(date +%s) - ${AUDIT_START:-$(date +%s)} ))
DURATION="$(( AUDIT_SECS / 60 ))m $(( AUDIT_SECS % 60 ))s"

# Count findings-file marker lines; missing files / no matches → 0 (grep -c with || echo 0)
_cnt () { grep -c "$1" $AUDIT_DIR/audit-*.md 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}'; }
N_CHECKBOXES_FLIPPED=$(_cnt 'CHECKBOX_FLIPPED')
N_ORPHANS_BACKFILLED=$(_cnt 'ORPHAN_BACKFILLED')
N_LOG_LINES_REPAIRED=$(_cnt 'LOG_REPAIRED')
N_DIGESTS_STALE=$(_cnt 'DIGEST_STALE')
N_TASK_MERGES=$(_cnt 'TASK_MERGE_CANDIDATE')
N_SUSPECT=$(_cnt 'SUSPECT_NO_COMMIT')
REPORT_PATH="${AUDIT_DIR}/audit-lead.md"
PROJECT="${project}"

export PROJECT DURATION N_SPECIALISTS \
  N_CHECKBOXES_FLIPPED N_ORPHANS_BACKFILLED N_LOG_LINES_REPAIRED \
  N_DIGESTS_STALE N_TASK_MERGES N_SUSPECT REPORT_PATH
render_card "audit-summary"
```

**Banned (R38 violation):** no in-process `Agent()` audit specialists inside King — always dispatch to a lane or spawn a visible tab. Rationale + the other cycle anti-patterns: [`docs/work-cycle.md` § Anti-patterns](../docs/work-cycle.md#anti-patterns-workmd-steps-1-and-4).

## Step 3 — Daily kickoff (4-card brief)

King reads in the order R14 mandates (rules.md → workspace + project CLAUDE.md → README.md → docs/ → MEMORY.md → personal notes → watchman state), then prints a **4-card brief**:

```bash
LOCAL_DATETIME=$(date '+%A, %B %-d, %Y · %H:%M %Z')
WX_LINE=$(fetch_weather_line)   # functions/fetch_weather_line.sh; 3s timeout; silent on failure

HOUR=$(date '+%-H')
if   [ "$HOUR" -ge 5 ]  && [ "$HOUR" -lt 12 ]; then VARIANT=morning
elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then VARIANT=afternoon
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 22 ]; then VARIANT=evening
else                                                 VARIANT=late
fi

render_card "welcome/${VARIANT}"
render_card "daily-status"
render_card "suggested-task"
render_card "dispatch-plan"

cat <<'EOF'

Audit + resume scan complete. I'll auto-gate + overlay + request push approval
as work completes — but I won't dispatch new work until you choose how (Step 3.6).
You'll be notified when I need: review approval, push approval, or blocked-lane resolution.
EOF
```

Cards used in Step 3:

- `cards/welcome.md` — 4 time-of-day variants + weather slot
- `cards/daily-status.md` — project + counting unit + target + watchman + PR queue
- `cards/suggested-task.md` — 1-3 candidates with reasoning
- `cards/dispatch-plan.md` — lane assignments for today

**Suggested next task synthesis** draws from (in priority order):

1. Unfinished prior-session work: task files with Status in `planning|executing|verifying` and no matching sentinel.
2. Lead-requested follow-ups: open PRs with unresolved review comments.
3. Unflipped acceptance criteria in the project task-ledger (`TODO_*.md`, `TODO_Master.csv`, `STEP.md`) that match an idle lane's domain.
4. Watchman gap findings in `WATCH_DOCS_AUDIT.md`.
5. New work: first unstarted heading in the task-ledger that has no dependency-blocking.

King picks 1-3 candidates and presents them as a numbered choice; the user can pick one or say "go" to accept the first.

Cards that fire later in the cycle (task-complete, push-prompt, gate-fail, limit-reached, end-of-day, pr-merged, conflict-detected, resume-queue) and the points they fire at: [`docs/work-cycle.md` § Cards fired later in the cycle](../docs/work-cycle.md#cards-fired-later-in-the-cycle-workmd-step-3).

## Step 3.6 — Dispatch-mode choice (U6 · the King STOPS and asks)

**The King does NOT auto-seek jobs.** After the audit (Step 1) and the resume scan (Step 0.6) are complete, the King presents what it found and asks the user ONE question before any new dispatch fires. This is a hard gate: **Step 3.5 (pods) and Step 4 (solo) do not run until the user answers.**

The King prints (a) the resume queue from Step 0.6 (in-flight work it can continue immediately, R33), and (b) the three dispatch modes, then waits for the user's reply:

```text
👑 Audit + resume scan done. How should I proceed?

   In-flight (resume-eligible, R33):
     • worker-1 · FE-P0-5  (executing — last: "wired the form, tests pending")
     • worker-2 · BE-P1-2  (verifying)

   Pick a dispatch mode:
   (s) seek      — I scan the ledger and PROPOSE up to N tasks for your approval
                   before anything dispatches. You see the list, then say go.
   (a) assign    — You name the task(s)/lane(s) yourself; I dispatch exactly those.
   (r) resume-only — Only continue the in-flight work above; open no new tasks.

   (Resume work is listed above either way, but I won't dispatch it until you choose.)
```

Behaviour per choice:

- **(s) seek** — King runs the suggested-task synthesis (the 5 priority sources above), proposes up to `N` candidates (default 3, or the lane count, whichever is smaller) as a numbered list via the `suggested-task` card, and **waits again** for the user to approve the list (`go` accepts all proposed; the user may strike or reorder). Auto-dispatch (Step 3.5 + Step 4) fires ONLY after this approval.
- **(a) assign** — King parses the user's named tasks/lanes (free-form, e.g. `worker-1 do FE-P0-7, senior-1 take story BILL`), confirms the parse, then dispatches exactly those — no ledger seeking.
- **(r) resume-only** — King dispatches ONLY the Step 0.6 resume queue (the `[RESUME]` briefs in Step 4) and opens no fresh task files. Step 4's new-task seeking is skipped entirely.

Until the user answers, the King stays in the Step 5 poll loop for gating/overlay/push of any **already-in-flight** sentinels — it just does not open new work. Record the chosen mode for Step 3.5 / Step 4:

```bash
# Set by the King from the user's reply: "seek" | "assign" | "resume-only".
# Step 3.5 (pods) and Step 4 (solo) branch on this; neither dispatches new work
# unless DISPATCH_MODE is "seek" (post-approval) or "assign".
export DISPATCH_MODE="<seek|assign|resume-only>"
export PROPOSED_TASKS=""   # seek mode, post-approval: the approved task ids (newline-separated)
```

## Step 3.5 — Story-pod assignment (R46/R50, when `integration.enabled` and `seniors > 0`)

If `kingdom.json.integration.enabled` is true and `SENIORS > 0`, the King runs the **pod path** for multi-worker units before the solo Step 4. The King owns cross-story only (R50); each Senior owns its story end-to-end (R48). **The pod path only runs when `DISPATCH_MODE` chose new work** (`seek` post-approval, or `assign`); under `resume-only` it is skipped entirely (Step 3.6).

**The partition step (R50, C1).** `POD_ASSIGNMENTS` is composed by the King — this is judgment, not deterministic bash (same as `pick_next_task_for`): the King reads the project task-ledger (`kingdom.json.taskSource` → `TODO_*.md` / `STEP.md` / `gh issues`), selects the units to attack this session (in `seek` mode = the approved `${PROPOSED_TASKS}`; in `assign` mode = the user's named units), and groups them into pods per `$UNIT`:

- `unit="pod"` (default) → group ALL of a Senior's selected stories under ONE story-id → ONE branch per Senior pod → ONE PR. Each Senior gets a pod of 1-3 workers attacking the grouped scope.
- `unit="story"` → one pod entry (= one branch/PR) per CSV-story/issue, so a Senior owning N stories yields N entries.

The King scopes pods so file-areas do not overlap (R50) and sequences dependencies, staying within `sanityCap` (King + Σ(senior + its workers) + watchman + co-workers ≤ cap). It **emits the assignments as newline-separated `<story-id>=<worker-a>,<worker-b>,…` lines** (one pod per line, no spaces inside a line) into `$POD_FILE` below, then the loop consumes them with a zsh-safe `while read` (no bare-glob, no word-split reliance):

```bash
INTEG_ON=$(jq -r '.integration.enabled // false' "$KJSON")
UNIT=$(jq -r '.integration.unit // "pod"' "$KJSON")   # K13: default "pod" (one branch per Senior → one PR)
# H-x: re-derive consumed vars in case this block is a fresh invocation.
PROJ="${PROJ:-$PWD/${project}}"
REFS_FILE="${REFS_FILE:-$PWD/.kingdom/${project}/logs/workspace-refs.env}"
[ -n "$BASE" ] || BASE=$(jq -r '.git.base // "develop"' "$KJSON")

if [ "$INTEG_ON" = "true" ] && [ "${SENIORS:-0}" -gt 0 ] && [ "$DISPATCH_MODE" != "resume-only" ]; then
  # 1. PARTITION (R50). The King writes the pod assignments it composed (from the
  #    ledger / approved list — see prose above) to $POD_FILE, ONE per line:
  #        <story-id>=<worker-a>,<worker-b>,...
  #    Example the King would write for two pods of two workers each:
  #        printf '%s\n' 'BILL-EPIC=worker-1,worker-2' 'AUTH-EPIC=worker-3,worker-4' > "$POD_FILE"
  #    (No code can guess the grouping — the King fills $POD_FILE before the loop.)
  POD_FILE="$PWD/.kingdom/${project}/logs/pod-assignments.env"
  : > "$POD_FILE"   # King overwrites this with the composed assignments (see above)
  # >>> King: emit the composed "<story-id>=<workers>" lines into "$POD_FILE" here <<<

  if [ ! -s "$POD_FILE" ]; then
    echo "ℹ️ No pod assignments composed (no multi-worker units selected) — all work flows through solo Step 4."
  else
    S=0
    # zsh-safe consumption: while-read over the file, NOT `for POD in $POD_ASSIGNMENTS`
    # (the old form word-split a never-assigned scalar → zero iterations, story pods dead).
    while IFS= read -r POD; do
      [ -n "$POD" ] || continue                # skip blank lines
      case "$POD" in \#*) continue ;; esac     # skip comments
      S=$((S + 1)); SENIOR="senior-$S"
      [ "$S" -gt "$SENIORS" ] && { echo "queued (no free Senior): $POD"; continue; }
      STORY_ID="${POD%%=*}"; PODWORKERS=$(echo "${POD#*=}" | tr ',' ' ')

      # 2. Create the local story branch in the Senior's worktree (R46)
      BRANCH=$(create_story_branch "$PROJ" "$STORY_ID" "$BASE" "$SENIOR")

      # 3. Assign the pod to the Senior + hand cross-cutting conventions, then start
      #    its autonomous loop. guard_dispatch_scope (called inside the Senior)
      #    keeps the Senior in-pod + visible-only (R30 amendment).
      SENIOR_WS=$(grep "^${SENIOR}_WS=" "$REFS_FILE" 2>/dev/null | cut -d= -f2)
      guard_lane_workspace_exists "$SENIOR" || { echo "⏸ $SENIOR has no workspace; skipping pod"; continue; }
      [ -n "$SENIOR_WS" ] || { echo "⏸ $SENIOR has no workspace ref in $REFS_FILE; skipping pod"; continue; }
      cmux_send "$SENIOR_WS" \
        "[STORY] You own $BRANCH. Pod: $PODWORKERS. Conventions: <cross-cutting notes>. Read senior.md and run the story lifecycle. Mark push-eligible when clean; never push.
Questions/blockers → inbox_send king question $STORY_ID yes \"…\" (don't stall silently). Long/multi-file work: fan out via the Workflow tool (R53; check availability first)."
      spawn_loop "$SENIOR_WS" "/loop"   # kick the senior's autonomous story loop (self-senior already grounded it at spawn, R52)
      echo "Assigned $BRANCH → $SENIOR (pod: $PODWORKERS)"
    done < "$POD_FILE"
  fi
fi
```

Pods now run autonomously and in parallel. The King does NOT re-review their internals (R48). Solo (non-pod) tasks still flow through Step 4 below; lanes already claimed by a pod are skipped there.

## Step 4 — Auto-dispatch (within cap/target) — HARD 60s TIME BUDGET (R30)

**Skill resolution (R41 + R23):** `pick_skills_for_task` consults `skill-routing.md` for each lane before building the dispatch-brief. `${SUGGESTED_SKILLS}` in the brief carries the result. R41 governs discovery (system-reminder fallback when routing table returns 0 matches); R23 governs injection into the brief.

**R30 hard rule:** from this step starting, no more than 60 seconds elapses before the first `cmux send` fires to a worker. King is ORCHESTRATOR, not executor. If King catches itself drafting a multi-batch execution plan in chat instead of dispatching: STOP and dispatch with the brief as-is.

**Dispatch-mode gate (U6).** Step 4 honors the `DISPATCH_MODE` chosen in Step 3.6: under `resume-only` it dispatches ONLY the resume queue and opens no fresh tasks (the `pick_next_task_for` seek is skipped); under `assign` it dispatches the user's named tasks; under `seek` (post-approval) it dispatches the approved `${PROPOSED_TASKS}`. The King never auto-seeks without a prior choice.

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $LANES_EXPECTED in the loop below (else 1 iteration over the whole blob); auto-reverts
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
# H-x: re-derive consumed vars (state does not persist across blocks).
PROJ="${PROJ:-$PWD/${project}}"
REFS_FILE="${REFS_FILE:-$PWD/.kingdom/${project}/logs/workspace-refs.env}"
TASKS_DIR="${TASKS_DIR:-$PWD/.kingdom/${project}/tasks}"
DISPATCH_MODE="${DISPATCH_MODE:-resume-only}"   # fail safe: if Step 3.6 didn't run, do NOT auto-seek
DISPATCH_START=$(date +%s)
TASKS_DISPATCHED_TODAY=0
# H-x: export the running ceilings so the pr-limit / pod-limit comparisons hold
# across the Step 5 poll loop + Step 6 (which run as separate bash invocations).
PRS_OPENED_TODAY=0      # incremented at Step 6 (gh pr create)
PODS_DONE_TODAY=0      # incremented when a pod's story PR opens or a solo task ships
export PRS_OPENED_TODAY PODS_DONE_TODAY DISPATCH_MODE

for lane in $LANES_EXPECTED; do
  # Skip co-workers (R32 — co-workers wait for explicit pair-on signal)
  [[ "$lane" == co-worker-* ]] && continue
  # Skip watchmen (always running /loop, never task-dispatched)
  [[ "$lane" == watchman-* ]] && continue
  # Skip seniors (v0.32.0: driven by their own story loop via Step 3.5, not solo dispatch)
  [[ "$lane" == senior-* ]] && continue

  # Resume queue: in-flight lanes get resume brief first
  RESUME_ENTRY=$(echo "$RESUME_QUEUE" | grep "^${lane}|" | head -1)
  if [ -n "$RESUME_ENTRY" ]; then
    TASK_ID=$(echo "$RESUME_ENTRY" | cut -d'|' -f2)
    TASK_STATUS=$(echo "$RESUME_ENTRY" | cut -d'|' -f3)
    TASK_FILE="$TASKS_DIR"/$(ls -1t "$TASKS_DIR"/*.md 2>/dev/null \
      | xargs -I{} basename {} | grep "__${TASK_ID}.md" | head -1)
    LAST_PROGRESS=$(grep '## Progress notes' -A5 "$TASK_FILE" 2>/dev/null | tail -4)
    BRIEF="[RESUME] ${lane} · task ${TASK_ID} · status=${TASK_STATUS}. \
Last progress: ${LAST_PROGRESS}. Continue from where you left off."
    lane_ws=$(grep "^${lane}_WS=" "$REFS_FILE" | cut -d= -f2)
    # v0.31.0 R31+R36 hard gate: refuse dispatch if lane workspace missing.
    # Bypassing this caused "dispatch into the void" in the 2026-05-19 session.
    guard_lane_workspace_exists "$lane" || { echo "⏸ skipping resume of $lane (workspace check failed)"; continue; }
    cmux_send "$lane_ws" "$BRIEF"
    echo "Resumed $lane → $TASK_ID"
    continue
  fi

  # U6: only SEEK new work in seek/assign mode. resume-only stops here — the
  # in-flight resume above already fired; no fresh task files are opened.
  [ "$DISPATCH_MODE" = "resume-only" ] && { echo "$lane: resume-only mode, no new task"; continue; }

  # seek (post-approval) draws from $PROPOSED_TASKS; assign + the default path
  # fall through to pick_next_task_for (King judgment over the ledger).
  TASK=$(pick_next_task_for "$lane")
  [ -z "$TASK" ] && { echo "$lane idle (no claimable task)"; continue; }

  SUGGESTED_SKILLS=$(pick_skills_for_task "$TASK" "$lane")

  # U5 — "Read first" list (Shared spec 3). The King composes 3-7 entries the lane
  # MUST read before any code/plan: the project CLAUDE.md, the most relevant docs/
  # files for this task's domain, and the task's key source files. Pick them by:
  #   1) always include the project CLAUDE.md if present;
  #   2) grep the docs index / docs/ for the task's domain keywords (1-3 hits);
  #   3) grep the source tree for the task's primary symbol/path (1-3 files).
  # One path per line; this fills ${READ_FIRST_LIST} in the dispatch-brief card.
  # This is King JUDGMENT (like pick_next_task_for / the skill pick) — the King
  # builds the multi-line value from the greps above; there is no deterministic
  # helper for it. Example of what the King assigns:
  #   READ_FIRST_LIST=$'  • CLAUDE.md\n  • docs/auth.md\n  • src/app/login/route.ts'
  READ_FIRST_LIST="${READ_FIRST_LIST:-  • <project CLAUDE.md>\n  • <most relevant docs/ file>\n  • <key source file(s)>}"
  export LANE="$lane" TASK_ID="$TASK" SUGGESTED_SKILLS READ_FIRST_LIST PROJECT="$project"
  BRIEF=$(render_card "dispatch-brief")
  # The brief card (A4) carries, near the top: the 📚 Read-first list, the R53
  # Workflow-fanout reminder ("Long/multi-file work → Workflow tool; check
  # availability first"), and the inbox one-liner ("Questions/blockers →
  # inbox_send king question <task> yes \"…\" — don't stall silently").

  lane_ws=$(grep "^${lane}_WS=" "$REFS_FILE" | cut -d= -f2)
  # v0.31.0 R31+R36 hard gate: refuse dispatch if lane workspace missing.
  # The 2026-05-20 morning incident was a dispatch that ran without a visible
  # workspace — work happened in King's session, the user saw nothing happen.
  guard_lane_workspace_exists "$lane" || { echo "⏸ skipping $lane (workspace check failed)"; continue; }
  cmux_send "$lane_ws" "$BRIEF"
  echo "Dispatched $lane → $TASK"
  TASKS_DISPATCHED_TODAY=$((TASKS_DISPATCHED_TODAY + 1))

  ELAPSED=$(( $(date +%s) - DISPATCH_START ))
  if [ "$ELAPSED" -gt 60 ]; then
    echo "R30: dispatch budget exceeded (${ELAPSED}s). Continuing remaining dispatches."
  fi

  # Limit enforcement (independent ceilings; whichever hits first stops dispatch)
  if [ -n "$PR_LIMIT" ] && [ "$PRS_OPENED_TODAY" -ge "$PR_LIMIT" ]; then
    LIMIT_KIND="pr-limit" LIMIT_VAL="$PR_LIMIT" render_card "limit-reached"; break
  fi
  if [ -n "$POD_LIMIT" ] && [ "$PODS_DONE_TODAY" -ge "$POD_LIMIT" ]; then
    LIMIT_KIND="pod-limit" LIMIT_VAL="$POD_LIMIT" render_card "limit-reached"; break
  fi
done
```

`PRS_OPENED_TODAY` increments at Step 6 (each `gh pr create`); `PODS_DONE_TODAY` increments when a pod's story PR opens or a solo task ships. Both counters live across the Step 5 poll loop so the limits hold for the whole session.

Workers begin work in parallel (per R28 parallel-by-default).

**Anti-patterns (R30, R32):** no multi-batch plan tables in chat before dispatching; no `staged · awaiting your dictation` (workers don't wait — mark idle lanes `idle (no claimable task)` and continue). Detail: [`docs/work-cycle.md` § Anti-patterns](../docs/work-cycle.md#anti-patterns-workmd-steps-1-and-4).

## Step 5 — Auto-gate-poll loop (the perpetual part)

King enters a perpetual poll loop. Each tick:

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null  # glob-heavy loop; safe if a fresh invocation precedes _load.sh
# H-x: re-derive every var the loop consumes — this block may be a fresh bash
# invocation, so nothing from Step 0/3/4 is guaranteed to be in the environment.
LOGS="$PWD/.kingdom/${project}/logs"
PROJ="${PROJ:-$PWD/${project}}"
KJSON="${KJSON:-$PWD/.kingdom/${project}/kingdom.json}"
REFS_FILE="${REFS_FILE:-$LOGS/workspace-refs.env}"
[ -n "$BASE" ] || BASE=$(jq -r '.git.base // "develop"' "$KJSON")
[ -n "$KING_WS" ] || KING_WS=$(cmux_identify 2>/dev/null | jq -r .caller.workspace_ref)
export LOGS PROJ KJSON REFS_FILE BASE KING_WS

while true; do
  # 5a-inbox (U4). Each tick, triage the King's inbox BEFORE gating sentinels.
  # List pending messages (new inbox/ format + legacy king-inbox/ for back-compat),
  # then the King handles each per the protocol prose below (answer / write memory /
  # escalate) and consumes it. Scaffolding only — the ANSWER is King judgment.
  for MSG in $(inbox_list king 2>/dev/null); do
    [ -f "$MSG" ] || continue
    inbox_read "$MSG"          # King reads the front matter (from/type/task/needs-reply) + body
    # King decides, per the type:
    #   question/flag + needs-reply:yes → answer the lane:  inbox_reply <from> <task> "<answer>"
    #                                     then nudge it:     cmux_send <lane_ws> "📬 King replied in your inbox re <task>"
    #                                     OR escalate to the user if only they can decide (don't guess).
    #   memory-request                  → King writes the memory itself (U8), then inbox_reply confirms.
    #   info/docs-update                → note it; no reply needed.
    inbox_read "$MSG" --consume   # archive after handling
  done
  # Legacy fallback: pre-inbox king-inbox/ drops (durable tmux_notify writes, older lanes).
  LEGACY_INBOX="$PWD/.kingdom/${project}/king-inbox"
  if [ -d "$LEGACY_INBOX" ]; then
    for MSG in "$LEGACY_INBOX"/*; do
      [ -f "$MSG" ] || continue
      cat "$MSG"          # King reads + handles as above, then consumes
      rm -f "$MSG"
    done
  fi

  # 5a. Detect un-gated sentinels
  for FLAG in "$LOGS"/done/*.flag; do
    [ -f "$FLAG" ] || continue
    # v0.31.1: rename from BASE → FLAG_BASE to stop shadowing the outer
    # git-base var ($BASE = develop/main from line 227). The shadow silently
    # broke kingdom_overlay_lane and the N_MODIFIED count for every push-prompt.
    FLAG_BASE=$(basename "$FLAG" .flag)

    # 5a-pre (v0.32.0): a Senior push-eligible story flag (<UTC>__senior-N__<story-id>)
    # skips the per-worker overlay path. The Senior already ran Tier-2 + the review
    # loop (R47/R48); the King's only job is the cross-story check (R50) + the push.
    if echo "$FLAG_BASE" | grep -q '__senior-[0-9]\+__'; then
      STORY_ID=$(echo "$FLAG_BASE" | sed 's/.*__senior-[0-9]*__//')
      SENIOR=$(echo "$FLAG_BASE" | sed 's/.*__\(senior-[0-9]*\)__.*/\1/')
      ls "$PWD/${project}/docs/test-reports/KING_"*"__${SENIOR}__${STORY_ID}.md" >/dev/null 2>&1 && continue
      # Cross-story drift check (R50): consume the watchman's signal across story branches
      DRIFT=$(cross_story_scan "$PROJ")
      echo "$DRIFT" | grep -q 'drift:' && echo "⚠️ ${DRIFT} — King coordinates rebase of story/${STORY_ID} before PR"
      # NO re-review of internals (R48). Show the Senior's clean verdict, then the
      # story-PR push-prompt, and wait (R1).
      export LANE="$SENIOR" TASK_ID="$STORY_ID" TOPIC="$STORY_ID" STORY_ID
      render_card "senior-verdict"   # reads the SENIOR_ report for the clean verdict
      render_card "push-prompt"
      cmux_notify "$KING_WS" "👑 King · story review ready" \
        "story/${STORY_ID}" "Senior cleared it. Reply 'push' to open the PR."
      wait_for_ter_decision   # on "push": carve story/${STORY_ID} → develop PR (Step 6)
      continue
    fi

    LANE=$(echo "$FLAG_BASE" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    SUBTASK_ID=$(echo "$FLAG_BASE" | sed 's/.*__//')
    # C2/H-x: set TOPIC for the SOLO push HERE, per-sentinel, so it tracks the
    # current sub-task (not a stale value from a prior push). The story path sets
    # its own TOPIC=STORY_ID separately (5a-pre). Step 6 reads both.
    TOPIC="$SUBTASK_ID"
    export LANE SUBTASK_ID TOPIC   # Step 6 (a separate invocation on 'push') reads these for the PR body + branch

    # Already gated? (test report exists)
    ls "$PWD/${project}/docs/test-reports/KING_"*"__${LANE}__${SUBTASK_ID}.md" \
      >/dev/null 2>&1 && continue

    cmux_set_state "$KING_WS" "▶" "Tier-1 gate · ${LANE} · ${SUBTASK_ID}"
    run_tier1_gate "${LANE}" "${SUBTASK_ID}"

    if [ "$?" = "0" ]; then
      cmux_set_state "$KING_WS" "▶" "Overlaying ${LANE} onto kingdom"
      # v0.31.1: was a stale-name no-op call (overlay_lane_onto_kingdom is not
      # defined anywhere — bash silently skipped, then Tier-2 ran against the
      # empty kingdom branch). The real helper is kingdom_overlay_lane and it
      # takes ($PROJ, $LANE, $BASE). See functions/kingdom_overlay_lane.sh (the hard-gate helpers).
      kingdom_overlay_lane "$PROJ" "${LANE}" "${BASE}" || {
        echo "⚠️ Overlay failed for ${LANE} — see helper output above. Skipping Tier-2 for this lane this tick."
        continue
      }

      cmux_set_state "$KING_WS" "▶" "Tier-2 gate · kingdom overlay"
      run_tier2_gate

      if [ "$?" = "0" ]; then
        DURATION=$(compute_task_duration "${LANE}" "${SUBTASK_ID}")
        RANDOM_LINE=$(random_task_done_line)
        export LANE TASK_ID="${SUBTASK_ID}" DURATION RANDOM_LINE
        render_card "task-complete"

        N_MODIFIED=$(git diff --name-only "origin/${BASE}" | wc -l | tr -d ' ')
        N_NEW=$(git status --short | grep -c '^??')
        GATE_DURATION=$(compute_gate_duration "${LANE}" "${SUBTASK_ID}")
        PR_TITLE=$(extract_pr_title_from_task_file "${LANE}" "${SUBTASK_ID}")
        export N_MODIFIED N_NEW GATE_DURATION PR_TITLE
        render_card "push-prompt"

        cmux_set_state "$KING_WS" "⚠" "Review live diff · ${LANE} · ${SUBTASK_ID}"
        cmux_workspace_action "$KING_WS" mark-unread
        cmux_notify "$KING_WS" "👑 King · review ready" \
          "${LANE} · ${SUBTASK_ID}" "Tier-2 passed. Reply 'push' to publish."

        wait_for_ter_decision    # per R1: only the literal 'push' word counts
      else
        TIER="Tier-2" TIER_SCOPE="kingdom overlay" \
          FAILURE_SUMMARY=$(summarise_gate_failure) \
          REPORT_PATH=$(latest_test_report "${LANE}" "${SUBTASK_ID}")
        export LANE TASK_ID="${SUBTASK_ID}" TIER TIER_SCOPE FAILURE_SUMMARY REPORT_PATH
        render_card "gate-fail"
        cmux_notify "$KING_WS" "👑 King · Tier-2 FAIL" \
          "${LANE} · ${SUBTASK_ID}" "$FAILURE_SUMMARY"
      fi
    fi
  done

  # 5b. Check for blocked lanes (watchman handles autonomously; King reads watchman_state.json)

  # 5c. Re-check capacity utilisation (idle lanes + pending work)
  # If new pending tasks appeared, auto-dispatch within cap/target

  # 5d. Sleep before next tick (blocking poll inside single Bash call = zero token cost)
  sleep 10
done
```

### Inbox (U4 · two-way lane↔King, non-blocking)

Lanes never stall silently waiting on the King. When a lane hits a question or a blocker it posts a message and keeps any continuable work moving; the King's poll loop (5a-inbox above) drains the inbox every tick. The shared protocol (tracker Shared spec 1):

- **Location/format:** `$WS/.kingdom/<project>/inbox/king/<UTC>__<from>__<type>.md`, with YAML front matter (`from`/`to`/`type`/`task`/`needs-reply`) + a free-text body. Types: `question | flag | info | memory-request | docs-update`. Handled messages move to `inbox/king/.archive/`.
- **Lane side:** `inbox_send king question <task> yes "<text>"` (sets its own cmux state to `❓ waiting on King`, does NOT block). Lanes check their own inbox (`inbox_list <self>`) at task start, when blocked, and before the closer.
- **King side (each tick):** `inbox_list king` → for each pending message:
  - `question` / `flag` with `needs-reply: yes` → King answers with `inbox_reply <from> <task> "<answer>"` + a `cmux_send` nudge to that lane; OR, if only the user can decide (scope/priority/risk call), the King escalates it to the user in chat instead of guessing.
  - `memory-request` → memory writes are King-only (U8): the King writes the memory itself, then `inbox_reply` confirms.
  - `info` / `docs-update` → noted, no reply.
  - Consume with `inbox_read <file> --consume` after handling.
- **Back-compat:** the loop also drains the legacy `king-inbox/` directory (older lanes + the durable `tmux_notify` fallback write here).

**Post-push overlay discard per R29:**

```bash
[ -n "$BASE" ] || BASE=$(jq -r '.git.base // "develop"' "$PWD/.kingdom/${project}/kingdom.json")
git checkout kingdom
git reset --hard "origin/${BASE}"
git clean -fd
```

## Step 6 — On user's "push" approval per PR (R1)

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null  # the done-flag prune glob below must not abort on no-match
# H-x: re-derive everything this block consumes — 'push' arrives as a fresh
# chat turn, so this is a separate bash invocation from the Step 5 loop.
PROJ="${PROJ:-$PWD/${project}}"
LOGS="${LOGS:-$PWD/.kingdom/${project}/logs}"
KJSON="${KJSON:-$PWD/.kingdom/${project}/kingdom.json}"
[ -n "$BASE" ] || BASE=$(jq -r '.git.base // "develop"' "$KJSON")

# C2: the solo path never set TOPIC (only the story path did at line ~758), so
# `feature/${TOPIC}` was literally `feature/` on the first solo PR and collided
# on the second. Derive it from the sub-task id, then GUARD: never create a
# branch named `feature/` from an empty topic.
TOPIC="${TOPIC:-$SUBTASK_ID}"
export TOPIC
if [ -z "$TOPIC" ]; then
  echo "❌ Step 6 abort: TOPIC empty (SUBTASK_ID not set). Refusing to create 'feature/'." >&2
  echo "   Re-run gating so SUBTASK_ID is set, or pass the topic explicitly." >&2
  return 1 2>/dev/null || exit 1
fi

git checkout -b "feature/${TOPIC}" "${LANE}"
PR_BODY=$(generate_pr_body_from_task_file "${LANE}" "${SUBTASK_ID}")
git push -u origin "feature/${TOPIC}"
gh pr create --base "${BASE}" --head "feature/${TOPIC}" \
  --title "<from task file Brief>" \
  --body "$PR_BODY"

# H3: prune this lane's done-flags now that the lane shipped (king.md:480). The
# 10s poll scan in Step 5 globs ALL of done/*.flag every tick; without this the
# directory grows unbounded and the scan goes O(N-pushes). Flags are written as
# `<UTC>__<model>-<LANE>__<id>.flag`, so match the model-prefixed shape.
rm -f "$LOGS/done/"*"-${LANE}__"*.flag

# Post-push overlay discard (R29)
git checkout kingdom
git reset --hard "origin/${BASE}"
git clean -fd

cmux_set_state "$KING_WS" "✅" "Pushed feature/${TOPIC}"
cmux_workspace_action "$KING_WS" mark-read
# H-x: counters must persist across invocations — re-read prior values, increment, re-export.
PRS_OPENED_TODAY=$(( ${PRS_OPENED_TODAY:-0} + 1 ))   # toward pr-limit
PODS_DONE_TODAY=$(( ${PODS_DONE_TODAY:-0} + 1 ))     # this PR completed one unit (solo task or story pod)
export PRS_OPENED_TODAY PODS_DONE_TODAY
```

After push, King returns to Step 5's poll loop.

## Stopping the day

The day stops on any of:

- User says "stop" or "hold" in chat (King exits the auto-loop; lanes stay alive)
- `pr-limit=N` or `pod-limit=N` reached + no in-flight gates pending (King exits loop, waits for next-day instruction)
- All lanes idle AND no pending work AND no in-flight PRs (King exits loop, says "Day complete; run `/kingdom:save` to snapshot, or `/kingdom:work` again tomorrow.")

## Conventions

- **`/kingdom:work <project>` is THE canonical daily entry point.** Use it every morning. Composes resume-scan + spawn + kickoff + auto-gate-poll loop + per-push approval gates.
- **Blocks only on human decisions.** Review approval, push approval, blocked-lane resolution. Everything else flows autonomously per kingdom rules.
- **Argument parsing is forgiving.** Singular or plural role flags are accepted (`worker=`/`workers=`, etc.); `pr-limit=` and `pod-limit=` are interpreted then echoed back in Step 0.1 so the user can correct typos before the loop fires.
- **Per-session shape overrides** are reflected in the sidebar immediately — the overridden lane count spawns in Step 0.4, not the JSON count.
- **R14 session-start read** (rules.md → workspace + project CLAUDE.md → README → docs/ → MEMORY.md) happens between Step 0 parse and Step 1 audit.
