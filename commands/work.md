---
description: Daily work cycle. Audit + spawn lanes + dispatch + poll. Shape overrides per-session. Interactive when no args.
argument-hint: [project] [target=N-M/<day|week|month>] [cap=N] [worker=N] [co-worker=N] [watchman=N]
---

You are running the kingdom's **full daily work cycle** as one orchestrated flow. The user typed ONE command and expects the kingdom to "just run the day": audit the project state, spawn the lanes, brief the user with the local date+time and a suggested next task, then auto-dispatch + auto-gate until something needs a human decision. Block ONLY on genuine human-decision points.

## Step 0 — Resolve project + parse arguments (3 invocation modes)

`/kingdom:work` accepts three invocation shapes:

| Form | Behaviour |
|---|---|
| `/kingdom:work <project> [target=...] [cap=...] [worker=N] [co-worker=N] [watchman=N] [seniors=N] [lane=N]` | Standard: explicit project + optional budget + optional shape overrides. `lane=N` sets a total-lane budget the King auto-composes (v0.32.0). Skip to Step 0.1. |
| `/kingdom:work <project>` | Standard: explicit project, no caps, no overrides. Skip to Step 0.1. |
| `/kingdom:work` *(no args)* | **Interactive mode:** King asks "What do you want to work on today?", waits for natural-language reply, auto-parses project + task scope. See Step 0.0 below. |

### Shape overrides (per-session)

Two ways to set the shape for this run (neither rewrites `kingdom.json`):

1. **Per-role:** `worker=N`, `co-worker=N`, `watchman=N`, `seniors=N` set each role explicitly. Example: `/kingdom:work bfg-swt worker=5 co-worker=2 watchman=1 seniors=1`.
2. **Total budget (v0.32.0):** `lane=N` sets the TOTAL number of lanes (workers + co-workers + watchmen + seniors; the King is separate). The King auto-composes the split to fill the budget. Any per-role flag becomes a PIN that the King honors and fills the rest around. Examples: `/kingdom:work my-app lane=8` (King picks 8 lanes), `/kingdom:work my-app lane=8 watchman=1` (1 watchman pinned + 7 auto), `/kingdom:work my-app lane=12 seniors=2` (2 Senior-led pods + the rest workers), `/kingdom:work my-app lane=12 cap=5`.

```bash
# Effective shape resolution (per-session override wins over JSON):
if [ -n "$ARG_LANE" ]; then
  # lane=N: total-lane budget; King auto-composes, honoring per-role pins.
  CAPV=$(jq -r '.shape.sanityCap // 10' "$KJSON")
  LANE_BUDGET="$ARG_LANE"
  if [ "$LANE_BUDGET" -gt "$CAPV" ]; then
    echo "⚠️ lane=$LANE_BUDGET exceeds sanityCap=$CAPV; capping to $CAPV"; LANE_BUDGET="$CAPV"
  fi
  # Pins (explicit role flags) are fixed; defaults: 1 watchman if budget >= 2, pods opt-in (seniors only if pinned).
  WATCHMEN=${ARG_WATCHMAN:-$([ "$LANE_BUDGET" -ge 2 ] && echo 1 || echo 0)}
  SENIORS=${ARG_SENIOR:-0}
  COWORKERS=${ARG_COWORKER:-0}
  USED=$((WATCHMEN + SENIORS + COWORKERS))
  WORKERS=${ARG_WORKER:-$(( LANE_BUDGET - USED ))}
  [ "$WORKERS" -lt 0 ] && WORKERS=0
  echo "👑 lane=$LANE_BUDGET → workers=$WORKERS co-workers=$COWORKERS watchman=$WATCHMEN seniors=$SENIORS (King's composition; pins honored)"
else
  WORKERS=$([ -n "$ARG_WORKER" ] && echo "$ARG_WORKER" || jq -r '.shape.workers // 3' "$KJSON")
  COWORKERS=$([ -n "$ARG_COWORKER" ] && echo "$ARG_COWORKER" || jq -r '.shape["co-workers"] // 1' "$KJSON")
  WATCHMEN=$([ -n "$ARG_WATCHMAN" ] && echo "$ARG_WATCHMAN" || jq -r '.shape.watchman // 1' "$KJSON")
  SENIORS=$([ -n "$ARG_SENIOR" ] && echo "$ARG_SENIOR" || jq -r '.shape.seniors // 0' "$KJSON")
fi
```

If a per-session override (or `lane=N`) exceeds `sanityCap`, print a warning and cap to `sanityCap` — never silently accept a huge shape. With `lane=N`, the King composes within the budget at audit time; pinning `seniors=K` is how you ask for `K` story pods.

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
3. **Inline caps/targets** — `"5 tasks today"` → `cap=5`; `"30-50 per week"` → `target=30-50/week`.
4. **Shape overrides** — `"5 workers"` → `worker=5`.

Resolve into normalised args:

```bash
project="<matched-project-name>"
task_hint="<free-form scope, OR empty>"
cap="<parsed N, or empty>"
target="<parsed N-M/<period>, or empty>"
worker="<parsed N, or empty>"
```

If the parse is ambiguous, King prints back the interpretation and asks for confirmation BEFORE proceeding to Step 0.1:

```text
👑 Parsed:
   project   = bfg-swt
   task      = continue worker-1 PDPA (matched FE-P0-FOUND.5 task file)
   cap       = (none)
   target    = (none)
   shape     = worker=3 co-worker=1 watchman=1  (from kingdom.json)

   Proceed? Or correct the parse.
```

If the user types something unparseable (e.g. only `"hi"`, or a question), King replies in chat WITHOUT starting the kingdom. Treat it as conversational, not a `/kingdom:work` invocation.

**Resolved args from Step 0 or Step 0.0:**

- `project` — explicit positional OR fuzzy-matched from interactive reply. Verify `.kingdom/${project}/` exists; if missing, tell the user to run `/kingdom:init ${project}` first and stop.
- `target=N-M/<period>` — soft dispatch budget; auto-split in Step 0.1.
- `cap=N` — hard daily ceiling.
- `task_hint` (interactive-mode only) — natural-language scope; King uses it as a strong prior in Step 0.6 resume-scan and `suggested-task` card synthesis.
- `WORKERS`, `COWORKERS`, `WATCHMEN` — effective shape for this session (override or from JSON).

### Step 0.1 — Auto-split `target` across timeframes

If `target=N-M/<period>` was passed, compute the daily / weekly / monthly views (assumes 5 working days per week, 4 weeks per month):

```bash
parse_target () {
  local raw="$1"                              # e.g. "30-50/week"
  local range="${raw%/*}"                     # "30-50"
  local period="${raw##*/}"                   # "week"
  local lo="${range%-*}"                      # "30"
  local hi="${range#*-}"                      # "50"

  local day_lo day_hi week_lo week_hi month_lo month_hi
  case "$period" in
    day)
      day_lo=$lo;   day_hi=$hi
      week_lo=$((lo*5));  week_hi=$((hi*5))
      month_lo=$((lo*20)); month_hi=$((hi*20))
      ;;
    week)
      week_lo=$lo;  week_hi=$hi
      day_lo=$((lo/5));   day_hi=$((hi/5))
      month_lo=$((lo*4)); month_hi=$((hi*4))
      ;;
    month)
      month_lo=$lo; month_hi=$hi
      week_lo=$((lo/4));  week_hi=$((hi/4))
      day_lo=$((lo/20));  day_hi=$((hi/20))
      ;;
    *)
      echo "Unknown period: $period. Use day, week, or month." >&2
      return 1
      ;;
  esac
  echo "TARGET_DAY_LO=$day_lo TARGET_DAY_HI=$day_hi"
  echo "TARGET_WEEK_LO=$week_lo TARGET_WEEK_HI=$week_hi"
  echo "TARGET_MONTH_LO=$month_lo TARGET_MONTH_HI=$month_hi"
}
```

King prints the interpreted budget in the kickoff brief so the user can correct before the loop fires.

### Step 0.2 — Print parse summary BEFORE acting

```text
👑 Parsed arguments:
   project = bfg-swt
   target  = 30-50/week  → today's budget 6-10 · week 30-50 · month 120-200
   cap     = (none)
   shape   = worker=3 co-worker=1 watchman=1  (from kingdom.json)

Proceeding to resume-scan + spawn + kickoff...
```

If the parse is ambiguous (unknown period, malformed range), print the issue and stop.

### Step 0.3 — The counting unit

**1 task = 1 task file (`.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`) = 1 sentinel (`<LOGS>/done/<UTC>__<sub>-<lane>__<id>.flag`) ≈ 1 PR (`feature/<topic>`).**

The kingdom counts **sentinel fires** (Step 4 of the 4-step closer), not PR merges.

| Unit | Counted? |
|---|---|
| **Task file** + sentinel (solo worker) | Yes — THE unit |
| **Story pod** (v0.32.0: a Senior + workers → one `story/<id>` PR) | Yes — the whole pod counts as **1** (it ships one PR) |
| **TODO Story / heading** (e.g. `FE-P0-FOUND.7`) | Yes — usually 1:1 with a task file or one pod |
| **Sub-task / AC bullet** (one `- [x]` under a Story, or one worker's slice of a pod) | **No** — flips inside one task file / pod |
| **PR** (`feature/<topic>` or `story/<id>`) | Yes — usually 1:1; a follow-up cleanup PR adds 1 |
| **Milestone** (`M01-M20`) | No — spans many tasks |

So `cap=5` and `target=30-50/week` count **things that become a PR** (a solo task or a whole story pod), **not** the sub-tasks inside them and **not** milestones. `target=30-50/week` ≈ 30-50 PRs/week ≈ 30-50 Stories closed per week. A 3-worker pod that ships one story PR counts as **1** toward `cap`, not 3.

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
KING_WS=$(cmux identify --json | jq -r .caller.workspace_ref)
KING_WIN=$(cmux identify --json | jq -r .caller.window_ref)
KJSON="$PWD/.kingdom/${project}/kingdom.json"
KING_COLOR=$(jq -r '.cmux.workspaceColors.king // "amber"' "$KJSON")

# Rename + describe in parallel (cosmetic, fire-and-forget; R42: bounded wait)
RENAME_PIDS=""
cmux workspace-action --action rename --workspace "$KING_WS" \
  --title "👑 King · ${project}" 2>/dev/null &
RENAME_PIDS="$RENAME_PIDS $!"
cmux workspace-action --action set-color --workspace "$KING_WS" \
  --color "$KING_COLOR" 2>/dev/null &
RENAME_PIDS="$RENAME_PIDS $!"
cmux workspace-action --action set-description --workspace "$KING_WS" \
  --description "Starting ${project}..." 2>/dev/null &
RENAME_PIDS="$RENAME_PIDS $!"
PIN_KING=$(jq -r '.cmux.pinKingWorkspace // true' "$KJSON")
if [ "$PIN_KING" = "true" ]; then
  cmux workspace-action --action pin --workspace "$KING_WS" 2>/dev/null &
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
      cmux tree --all 2>/dev/null | grep -qF "$ref" && exit 0
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
_bounded_wait 60 $SPAWN_PIDS || echo "⚠️ spawn cycle hit 60s budget; survivors killed (check cmux tree --all + worktree-refs.env)"

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
  ALIVE_REFS=$(cmux tree --all 2>/dev/null | grep -oE 'workspace:[0-9]+' | sort -u)
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

cmux workspace-action --action set-description --workspace "$KING_WS" \
  --description "Audit in flight · 4 specialists across lanes" 2>/dev/null

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
    cmux send --workspace "$lane_ws" -- "$BRIEF" 2>/dev/null
    cmux send --workspace "$lane_ws" Enter 2>/dev/null
  else
    # No lane available — spawn as visible TAB inside King's workspace (R38: never Agent())
    cmux tab-action --action new-terminal-right --workspace "$KING_WS" --focus false 2>/dev/null
  fi
done

# Poll for audit sentinels (parallel, each specialist writes its own)
poll_for_sentinels "audit-*" 180   # 3-min timeout total
```

**Banned (R38 violation):** `Agent(subagent_type="general-purpose", prompt="audit specialist...")` in-process inside King. That hides the work behind the "1 local agent · ctrl+t to hide tasks" indicator. Always dispatch to a lane or spawn a visible tab.

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

Other cards fired later in the cycle:

- `cards/task-complete.md` — Tier-2 gate pass (~20 random congratulatory lines)
- `cards/push-prompt.md` — Tier-2 passed, awaiting "push" word (R1 approval)
- `cards/gate-fail.md` — Tier-1 or Tier-2 fail
- `cards/cap-reached.md` — `cap=N` hit
- `cards/end-of-day.md` — day stops (exit / cap reached / all idle)
- `cards/pr-merged.md` — PR flips MERGED (triggers R26 resync)
- `cards/conflict-detected.md` — `git merge-tree` finds drift at push time
- `cards/resume-queue.md` — in-flight tasks from prior session

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
    cmux send --workspace "$SENIOR_WS" -- \
      "[STORY] You own $BRANCH. Pod: $PODWORKERS. Conventions: <cross-cutting notes>. Read seniors.md and run the story lifecycle. Mark push-eligible when clean; never push."
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
    cmux send --workspace "$lane_ws" -- "$BRIEF" 2>/dev/null
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
  cmux send --workspace "$lane_ws" -- "$BRIEF"
  echo "Dispatched $lane → $TASK"
  TASKS_DISPATCHED_TODAY=$((TASKS_DISPATCHED_TODAY + 1))

  ELAPSED=$(( $(date +%s) - DISPATCH_START ))
  if [ "$ELAPSED" -gt 60 ]; then
    echo "R30: dispatch budget exceeded (${ELAPSED}s). Continuing remaining dispatches."
  fi

  # Cap enforcement
  if [ -n "$CAP" ] && [ "$TASKS_DISPATCHED_TODAY" -ge "$CAP" ]; then
    render_card "cap-reached"
    break
  fi
done
```

Workers begin work in parallel (per R28 parallel-by-default).

**Anti-pattern (R30 violation):** drafting "Worker-N plan (final)" multi-batch tables in CHAT before dispatching. That table belongs in the lane's task file as `## Plan` (Layer-2 Strategy), written BY the lane AFTER it receives the brief.

**Anti-pattern (R32 violation):** printing `worker-1 staged · awaiting your dictation`. Workers don't wait. If worker-1 has no claimable task, mark it `idle (no claimable task)` and continue to the next lane.

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
      cmux notify --workspace "$KING_WS" --title "👑 King · story review ready" \
        --subtitle "story/${STORY_ID}" --body "Senior cleared it. Reply 'push' to open the PR."
      wait_for_ter_decision   # on "push": carve story/${STORY_ID} → develop PR (Step 6)
      continue
    fi

    LANE=$(echo "$FLAG_BASE" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    SUBTASK_ID=$(echo "$FLAG_BASE" | sed 's/.*__//')

    # Already gated? (test report exists)
    ls "$PWD/${project}/docs/test-reports/KING_"*"__${LANE}__${SUBTASK_ID}.md" \
      >/dev/null 2>&1 && continue

    cmux_set_state "" "Tier-1 gate · ${LANE} · ${SUBTASK_ID}"
    run_tier1_gate "${LANE}" "${SUBTASK_ID}"

    if [ "$?" = "0" ]; then
      cmux_set_state "" "Overlaying ${LANE} onto kingdom"
      # v0.31.1: was a stale-name no-op call (overlay_lane_onto_kingdom is not
      # defined anywhere — bash silently skipped, then Tier-2 ran against the
      # empty kingdom branch). The real helper is kingdom_overlay_lane and it
      # takes ($PROJ, $LANE, $BASE). See _primitives.md § Hard gates.
      kingdom_overlay_lane "$PROJ" "${LANE}" "${BASE}" || {
        echo "⚠️ Overlay failed for ${LANE} — see helper output above. Skipping Tier-2 for this lane this tick."
        continue
      }

      cmux_set_state "" "Tier-2 gate · kingdom overlay"
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

        cmux_set_state "" "Review live diff · ${LANE} · ${SUBTASK_ID}"
        cmux workspace-action --action mark-unread --workspace "$KING_WS"
        cmux notify --workspace "$KING_WS" \
          --title "👑 King · review ready" \
          --subtitle "${LANE} · ${SUBTASK_ID}" \
          --body "Tier-2 passed. Reply 'push' to publish."

        wait_for_ter_decision    # per R1: only the literal 'push' word counts
      else
        TIER="Tier-2" TIER_SCOPE="kingdom overlay" \
          FAILURE_SUMMARY=$(summarise_gate_failure) \
          REPORT_PATH=$(latest_test_report "${LANE}" "${SUBTASK_ID}")
        export LANE TASK_ID="${SUBTASK_ID}" TIER TIER_SCOPE FAILURE_SUMMARY REPORT_PATH
        render_card "gate-fail"
        cmux notify --workspace "$KING_WS" --title "👑 King · Tier-2 FAIL" \
          --subtitle "${LANE} · ${SUBTASK_ID}" --body "$FAILURE_SUMMARY"
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

cmux_set_state "" "Pushed feature/${TOPIC}"
cmux workspace-action --action mark-read --workspace "$KING_WS"
TASKS_DISPATCHED_TODAY=$((TASKS_DISPATCHED_TODAY + 1))
```

After push, King returns to Step 5's poll loop.

## Stopping the day

The day stops on any of:

- User says "stop" or "hold" in chat (King exits the auto-loop; lanes stay alive)
- `cap=N` reached + no in-flight gates pending (King exits loop, waits for next-day instruction)
- All lanes idle AND no pending work AND no in-flight PRs (King exits loop, says "Day complete; run `/kingdom:save` to snapshot, or `/kingdom:work` again tomorrow.")

## Conventions

- **`/kingdom:work <project>` is THE canonical daily entry point.** Use it every morning. Composes resume-scan + spawn + kickoff + auto-gate-poll loop + per-push approval gates.
- **Blocks only on human decisions.** Review approval, push approval, blocked-lane resolution. Everything else flows autonomously per kingdom rules.
- **Argument parsing is forgiving.** `target=30-50/week` and `cap=5` are interpreted then echoed back in Step 0.2 so the user can correct typos before the loop fires.
- **Per-session shape overrides** are reflected in the sidebar immediately — the overridden lane count spawns in Step 0.4, not the JSON count.
- **R14 session-start read** (rules.md → workspace + project CLAUDE.md → README → docs/ → MEMORY.md) happens between Step 0 parse and Step 1 audit.
