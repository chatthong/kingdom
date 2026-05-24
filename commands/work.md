---
description: Daily work cycle. Audit + spawn lanes + dispatch + poll. Shape overrides per-session. Interactive when no args.
argument-hint: [project] [lane=N] [worker=N] [co-worker=N] [watchman=N] [senior=N] [pr-limit=N] [pod-limit=N]
---

You are running the kingdom's **full daily work cycle** as one orchestrated flow. The user typed ONE command and expects the kingdom to "just run the day": audit the project state, spawn the lanes, brief the user with the local date+time and a suggested next task, then auto-dispatch + auto-gate until something needs a human decision. Block ONLY on genuine human-decision points.

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
# Normalize args — accept singular or plural; canonical form is singular.
arg () { echo " $ARGUMENTS" | grep -oE "(^| )$1=[^ ]+" | tail -1 | cut -d= -f2; }
ARG_WORKER=$(arg 'workers?');     ARG_COWORKER=$(arg 'co-workers?')
ARG_WATCHMAN=$(arg 'watch(man|men)'); ARG_SENIOR=$(arg 'seniors?')
ARG_LANE=$(arg 'lanes?');          PR_LIMIT=$(arg 'pr-limit'); POD_LIMIT=$(arg 'pod-limit')

# Effective shape resolution (lane=N auto-composes; else per-role override wins over JSON):
if [ -n "$ARG_LANE" ]; then
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

**Within ~1 second of `/kingdom:work` receipt, before anything else:** rename King's own workspace + set description. User must see the kingdom responding, not stare at an unchanged sidebar.

```bash
# Capture King's window + workspace refs
KING_WS=$(cmux_identify | jq -r .caller.workspace_ref)
KING_WIN=$(cmux_identify | jq -r .caller.window_ref)
KJSON="$PWD/.kingdom/${project}/kingdom.json"
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
PROJ="$PWD/${project}"
REFS_FILE="$PWD/.kingdom/${project}/logs/workspace-refs.env"
WORKER_COLOR=$(jq -r '.cmux.workspaceColors.worker // "violet"' "$KJSON")
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
    # v0.31.0 R39: watchmen are autonomous — auto-dispatch /loop on spawn.
    # Without this, watchman sits at a shell prompt; the kingdom appears half-alive
    # until the user manually notices and asks "watchman why do nothing".
    case "$lane" in
      watchman-*) [ -n "$ref" ] && spawn_watchman_loop "$ref" ;;
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

Render the `spawn-complete` card with the detected MODE.

**Never dispatch to a lane whose worktree directory does not exist.** That is the silent-failure invariant.

## Step 0.6 — Resume scan (R33, MANDATORY)

Read existing task state BEFORE deciding what to dispatch. King MUST resume in-flight work before opening new task files.

```bash
TASKS_DIR="$PWD/.kingdom/${project}/tasks"
DONE_DIR="$PWD/.kingdom/${project}/logs/done"

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

# Scan tasks newest-first
for task_file in $(ls -1t "$TASKS_DIR"/*.md 2>/dev/null); do
  base=$(basename "$task_file" .md)
  lane=$(echo "$base" | sed 's/^[0-9-]*T[0-9]*Z__//;s/__.*//')
  task_id=$(echo "$base" | sed 's/.*__//')

  status=$(grep -E '^- \[x\] (planning|executing|verifying|done|blocked|cancelled)' "$task_file" \
    | tail -1 | grep -oE '(planning|executing|verifying|done|blocked|cancelled)')
  [ -z "$status" ] && status="planning"

  has_sentinel=0
  ls "$DONE_DIR"/*"__${lane}__${task_id}.flag" >/dev/null 2>&1 && has_sentinel=1

  case "$status" in
    done|cancelled)
      continue ;;
    blocked)
      DECISION_QUEUE+="${lane}|${task_id}|blocked"$'\n' ;;
    planning|executing|verifying)
      if [ "$has_sentinel" = "0" ]; then
        RESUME_QUEUE+="${lane}|${task_id}|${status}"$'\n'
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

The audit's specialists dispatch to lane workspaces via `cmux send`, not to in-process Agent() calls. Per R37, parallelisable work runs in lanes that the user can see.

```bash
echo "👑 Step 1/5 · Dispatching audit specialists to lanes (R37)..."

cmux_set_state "$KING_WS" "▶" "Audit in flight · 4 specialists across lanes"

SPECIALISTS=("audit-lead" "audit-a-project-scan" "audit-b-checkbox-reconcile" \
             "audit-c-digest-quality" "audit-d-log-repair")
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

**Banned (R38 violation):** no in-process `Agent()` audit specialists inside King — always dispatch to a lane or spawn a visible tab. Rationale + the other cycle anti-patterns: [`docs/work-cycle.md` § Anti-patterns](../docs/work-cycle.md#anti-patterns-workmd-steps-1-and-4).

## Step 3 — Daily kickoff (4-card brief)

King reads in the order R14 mandates (rules.md → workspace + project CLAUDE.md → README.md → docs/ → MEMORY.md → personal notes → watchman state), then prints a **4-card brief**:

```bash
LOCAL_DATETIME=$(date '+%A, %B %-d, %Y · %H:%M %Z')
WX_LINE=$(fetch_weather_line)   # _primitives.md helper; 3s timeout; silent on failure

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

I'll auto-dispatch + auto-gate + overlay onto kingdom as work completes.
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

## Step 3.5 — Story-pod assignment (R46/R50, when `integration.enabled` and `seniors > 0`)

If `kingdom.json.integration.enabled` is true and `SENIORS > 0`, the King runs the **pod path** for multi-worker units before the solo Step 4. The King owns cross-story only (R50); each Senior owns its story end-to-end (R48).

```bash
INTEG_ON=$(jq -r '.integration.enabled // false' "$KJSON")
UNIT=$(jq -r '.integration.unit // "story"' "$KJSON")

if [ "$INTEG_ON" = "true" ] && [ "${SENIORS:-0}" -gt 0 ]; then
  # 1. PARTITION (R50): pick units from the task-ledger, scope them so file-areas
  #    do not overlap, sequence dependencies. The King decides pod count + size
  #    within sanityCap (King + Σ(senior + its workers) + watchman + co-workers ≤ cap).
  #    Output: a list of "story-id : worker-1 worker-2 ..." pod assignments.

  S=0
  for POD in $POD_ASSIGNMENTS; do            # each POD = "<story-id>=<worker-a,worker-b,...>"
    S=$((S + 1)); SENIOR="senior-$S"
    [ "$S" -gt "$SENIORS" ] && { echo "queued (no free Senior): $POD"; continue; }
    STORY_ID="${POD%%=*}"; PODWORKERS=$(echo "${POD#*=}" | tr ',' ' ')

    # 2. Create the local story branch in the Senior's worktree (R46)
    BRANCH=$(create_story_branch "$PROJ" "$STORY_ID" "$BASE" "$SENIOR")

    # 3. Assign the pod to the Senior + hand cross-cutting conventions, then start
    #    its autonomous loop. guard_senior_dispatch_scope (called inside the Senior)
    #    keeps the Senior in-pod + visible-only (R30 amendment).
    SENIOR_WS=$(grep "^${SENIOR}_WS=" "$REFS_FILE" | cut -d= -f2)
    guard_lane_workspace_exists "$SENIOR" || { echo "⏸ $SENIOR has no workspace; skipping pod"; continue; }
    cmux_send "$SENIOR_WS" \
      "[STORY] You own $BRANCH. Pod: $PODWORKERS. Conventions: <cross-cutting notes>. Read senior.md and run the story lifecycle. Mark push-eligible when clean; never push."
    spawn_senior_loop "$SENIOR_WS" "$STORY_ID"
    echo "Assigned $BRANCH → $SENIOR (pod: $PODWORKERS)"
  done
fi
```

Pods now run autonomously and in parallel. The King does NOT re-review their internals (R48). Solo (non-pod) tasks still flow through Step 4 below; lanes already claimed by a pod are skipped there.

## Step 4 — Auto-dispatch (within cap/target) — HARD 60s TIME BUDGET (R30)

**Skill resolution (R41 + R23):** `pick_skills_for_task` consults `skill-routing.md` for each lane before building the dispatch-brief. `${SUGGESTED_SKILLS}` in the brief carries the result. R41 governs discovery (system-reminder fallback when routing table returns 0 matches); R23 governs injection into the brief.

**R30 hard rule:** from this step starting, no more than 60 seconds elapses before the first `cmux send` fires to a worker. King is ORCHESTRATOR, not executor. If King catches itself drafting a multi-batch execution plan in chat instead of dispatching: STOP and dispatch with the brief as-is.

```bash
DISPATCH_START=$(date +%s)
TASKS_DISPATCHED_TODAY=0
PRS_OPENED_TODAY=0      # incremented at Step 6 (gh pr create)
PODS_DONE_TODAY=0      # incremented when a pod's story PR opens or a solo task ships

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

  TASK=$(pick_next_task_for "$lane")
  [ -z "$TASK" ] && { echo "$lane idle (no claimable task)"; continue; }

  SUGGESTED_SKILLS=$(pick_skills_for_task "$TASK" "$lane")
  export LANE="$lane" TASK_ID="$TASK" SUGGESTED_SKILLS
  BRIEF=$(render_card "dispatch-brief")

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
LOGS="$PWD/.kingdom/${project}/logs"

while true; do
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
      DRIFT=$(watchman_cross_story_scan "$PROJ")
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
      # takes ($PROJ, $LANE, $BASE). See _primitives.md § Hard gates.
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

**Post-push overlay discard per R29:**

```bash
git checkout kingdom
git reset --hard origin/develop
git clean -fd
```

## Step 6 — On user's "push" approval per PR (R1)

```bash
git checkout -b "feature/${TOPIC}" "${LANE}"
PR_BODY=$(generate_pr_body_from_task_file "${LANE}" "${SUBTASK_ID}")
git push -u origin "feature/${TOPIC}"
gh pr create --base develop --head "feature/${TOPIC}" \
  --title "<from task file Brief>" \
  --body "$PR_BODY"

# Post-push overlay discard (R29)
git checkout kingdom
git reset --hard origin/develop
git clean -fd

cmux_set_state "$KING_WS" "✅" "Pushed feature/${TOPIC}"
cmux_workspace_action "$KING_WS" mark-read
PRS_OPENED_TODAY=$((PRS_OPENED_TODAY + 1))     # toward pr-limit
PODS_DONE_TODAY=$((PODS_DONE_TODAY + 1))       # this PR completed one unit (solo task or story pod)
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
