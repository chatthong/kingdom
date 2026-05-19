---
description: The daily ritual. Runs /kingdom:update + /kingdom:start + kickoff brief + auto-gate-poll loop. One command, all of it. Supports target=N-M/<period> and cap=N. Blocks only on human-decision points (review approval, push approval, blocked-lane unblock).
argument-hint: [project] [target=N-M/<period>] [cap=N]
---

You are running the kingdom's **full daily ritual** as one orchestrated flow. The user typed ONE command and expects the kingdom to "just run the day": audit the project state, spawn the lanes, brief the user with the local date+time and a suggested next task, then auto-dispatch + auto-gate until something needs a human decision. Block ONLY on genuine human-decision points.

## Step 0 — Resolve project + parse arguments

From `$ARGUMENTS`:

- **`project`** — first positional token. Defaults to `basename "$PWD"`. Verify `.kingdom/${project}/` exists; if missing, tell the user to run `/kingdom:init ${project}` first and stop.
- **`target=N-M/<period>`** — soft dispatch budget. Period is one of `day`, `week`, `month`. King auto-splits across timeframes (see Step 0.1). Optional. Examples: `target=30-50/week`, `target=5-10/day`, `target=120-200/month`.
- **`cap=N`** — hard ceiling for today's task completions. King will not dispatch more than `N` tasks today; further idle lanes wait. Optional. Overrides `target` for today only.

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
      echo "❌ Unknown period: $period. Use day, week, or month." >&2
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

Proceeding to audit + spawn + kickoff...
```

If the parse is ambiguous (unknown period, malformed range), print the issue + stop.

### Step 0.3 — The counting unit (what `cap` and `target` actually count)

**1 task = 1 task file (`.kingdom/<project>/tasks/<UTC>__<lane>__<id>.md`) = 1 sentinel (`<LOGS>/done/<UTC>__<sub>-<lane>__<id>.flag`) ≈ 1 PR (`feature/<topic>`).**

The kingdom counts **sentinel fires** (Step 4 of the 4-step closer), not PR merges. Mapping:

| Unit | Counted? |
|---|---|
| **Task file** + sentinel | ✅ THE unit |
| **TODO Story / heading** (e.g. `FE-P0-FOUND.7`) | ✅ usually 1:1 with a task file |
| **Sub-task / AC bullet** (one `- [x]` under a Story) | ❌ flips inside one task file |
| **PR** (`feature/<topic>`) | ✅ usually 1:1; a follow-up cleanup PR adds 1 |
| **Milestone** (`M01-M20`) | ❌ spans many tasks |

So `target=30-50/week` ≈ 30-50 PRs/week ≈ 30-50 Stories closed per week. King echoes this unit definition back in the kickoff brief.

## Step 0.5 — Lane-readiness gate (rules.md R31 · MANDATORY) (v0.24.0+, mode-aware in v0.25.0)

Before ANY further step, verify lane infrastructure. Per R31, the kingdom runs in three modes (PRIMARY=cmux / FALLBACK=tmux / AGENT=in-process) and the universal "lanes exist" check is **`.worktrees/<lane>/` directories**.

```bash
LANES_EXPECTED=$(jq -r '
  (.shape.workers // 0) as $w
  | (.shape["co-workers"] // 0) as $c
  | (.shape.watchman // 0) as $wm
  | (
      [range(1; $w + 1)  | "worker-\(.)"],
      [range(1; $c + 1)  | "co-worker-\(.)"],
      [range(1; $wm + 1) | "watchman-\(.)"]
    ) | flatten | .[]
' "$PWD/.kingdom/${project}/kingdom.json")

# Step 0.5a — Universal check: .worktrees/ directories exist
PROJ="$PWD/${project}"
MISSING_WORKTREES=""
for lane in $LANES_EXPECTED; do
  [ -d "$PROJ/.worktrees/$lane" ] || MISSING_WORKTREES="$MISSING_WORKTREES $lane"
done

if [ -n "$MISSING_WORKTREES" ]; then
  echo "⚠ Worktrees missing: $MISSING_WORKTREES"
  echo "   Running /kingdom:start to create them (idempotent)..."
  FORCE_START=1
fi

# Step 0.5b — Mode detection (PRIMARY vs FALLBACK vs AGENT)
MODE="AGENT"   # default
REFS_FILE="$PWD/.kingdom/${project}/logs/workspace-refs.env"

if command -v cmux >/dev/null 2>&1 && [ -f "$REFS_FILE" ]; then
  ALIVE_REFS=$(cmux tree --all 2>/dev/null | grep -oE 'workspace:[0-9]+' | sort -u)
  ALL_ALIVE=1
  for lane in $LANES_EXPECTED; do
    REF=$(grep "^${lane}_WS=" "$REFS_FILE" 2>/dev/null | cut -d= -f2)
    if [ -z "$REF" ] || ! echo "$ALIVE_REFS" | grep -qF "$REF"; then
      ALL_ALIVE=0
      break
    fi
  done
  [ "$ALL_ALIVE" = "1" ] && MODE="PRIMARY"
fi

if [ "$MODE" = "AGENT" ] && tmux ls 2>/dev/null | grep -q "^kingdom-${project}:"; then
  MODE="FALLBACK"
fi

echo "▶ Dispatch mode: $MODE"
```

**If `FORCE_START=1`**: run Step 2 (`/kingdom:start`) before Step 4 dispatch.

**If worktrees exist but PRIMARY/FALLBACK verification failed**: do NOT re-spawn cmux workspaces. Drop to `MODE=AGENT` and dispatch via `Agent(subagent_type=general-purpose, prompt="cd .worktrees/<lane> && ...")`. Re-spawning cmux when worktrees are already alive wastes time and may re-enter prior silent-failure modes (per memory `feedback_kingdom_cmux_dispatch_fallback.md`).

Render the [`spawn-complete`](../.kingdom/.setting/cards/spawn-complete.md) card with the detected MODE so the user knows which dispatch mechanism is active.

**Never dispatch to a lane whose worktree directory doesn't exist.** That's the silent-failure invariant: worktree absent = dispatch goes to /dev/null.

## Step 0.6 — Resume scan (rules.md R33 · MANDATORY) (v0.25.0+)

Read existing task state BEFORE deciding what to dispatch. King MUST resume in-flight work before opening new task files.

```bash
TASKS_DIR="$PWD/.kingdom/${project}/tasks"
DONE_DIR="$PWD/.kingdom/${project}/logs/done"

RESUME_QUEUE=""
DECISION_QUEUE=""

# Scan tasks newest-first
for task_file in $(ls -1t "$TASKS_DIR"/*.md 2>/dev/null); do
  base=$(basename "$task_file" .md)
  lane=$(echo "$base" | sed 's/^[0-9-]*T[0-9]*Z__//;s/__.*//')
  task_id=$(echo "$base" | sed 's/.*__//')

  # Check status
  status=$(grep -E '^- \[x\] (planning|executing|verifying|done|blocked|cancelled)' "$task_file" | tail -1 | grep -oE '(planning|executing|verifying|done|blocked|cancelled)')
  [ -z "$status" ] && status="planning"

  # Check sentinel
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

# Render the resume-queue card if anything in either queue
if [ -n "$RESUME_QUEUE" ] || [ -n "$DECISION_QUEUE" ]; then
  export RESUME_QUEUE DECISION_QUEUE
  render_card "resume-queue"
fi
```

**Resume queue takes priority over new dispatch.** In Step 4, lanes already in-flight get re-briefed with `[RESUME]` flag pointing at the same task ID + the last `## Progress notes` line. NEVER open a fresh task file for a lane that already has an in-flight one — that orphans the old file and confuses the audit trail.

**Decision queue items** surface in the [`suggested-task`](../.kingdom/.setting/cards/suggested-task.md) card as `→ Unblock <task-id>` candidates so the user resolves blockers before new work loads.

## Step 1 — Audit (always — `/kingdom:update` runs at EVERY `/kingdom:day` invocation)

## Step 1 — Audit (always — `/kingdom:update` runs at EVERY `/kingdom:day` invocation)

```bash
echo "👑 Step 1/5 · Running /kingdom:update (refreshing project state)..."
# Invoke the audit pass (parallel Lead + 4 specialists per /kingdom:update spec).
# Wait for the sentinel before continuing.
```

The audit is **always run** at the start of `/kingdom:day`. There is no "skip if recent" gate; the audit is cheap (parallel fan-out, ~1-3 min) compared to acting on stale information. If you need to skip the audit deliberately (rare — King session crashed mid-day and you only want to resume the poll loop), invoke `/kingdom:start` directly + drop into Step 5 of this file manually.

## Step 2 — Spin up the kingdom (`/kingdom:start` — idempotent)

```bash
echo "👑 Step 2/5 · Spinning up kingdom for ${project}..."
# Invoke /kingdom:start ${project}. Idempotent — resumes if already running, spawns missing lanes.
```

## Step 3 — Daily kickoff (4-card brief, v0.22.0+)

King reads in the order R14 mandates (rules.md → workspace + project CLAUDE.md → README.md → docs/ → MEMORY.md → personal notes → watchman state), then prints a **4-card brief** by calling `render_card` for each card in `.kingdom/.setting/cards/`:

```bash
LOCAL_DATETIME=$(date '+%A, %B %-d, %Y · %H:%M %Z')
WX_LINE=$(fetch_weather_line)   # _primitives.md helper; 3s timeout; silent on failure

# Pick welcome variant by hour
HOUR=$(date '+%-H')
if   [ "$HOUR" -ge 5 ]  && [ "$HOUR" -lt 12 ]; then VARIANT=morning
elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then VARIANT=afternoon
elif [ "$HOUR" -ge 18 ] && [ "$HOUR" -lt 22 ]; then VARIANT=evening
else                                                 VARIANT=late
fi

# Render the 4 kickoff cards in order
render_card "welcome/${VARIANT}"
render_card "daily-status"
render_card "suggested-task"
render_card "dispatch-plan"

# Closing line
cat <<'EOF'

I'll auto-dispatch + auto-gate + overlay onto kingdom as work completes.
You'll be notified when I need: review approval, push approval, or blocked-lane resolution.
EOF
```

Each card's full template + variable list + variants lives in [`.kingdom/.setting/cards/`](../.kingdom/.setting/cards/):

- [`cards/welcome.md`](../.kingdom/.setting/cards/welcome.md) — 4 time-of-day variants (morning/afternoon/evening/late) + weather slot
- [`cards/daily-status.md`](../.kingdom/.setting/cards/daily-status.md) — project + counting unit + target + watchman + PR queue
- [`cards/suggested-task.md`](../.kingdom/.setting/cards/suggested-task.md) — 1-3 candidates with reasoning
- [`cards/dispatch-plan.md`](../.kingdom/.setting/cards/dispatch-plan.md) — lane assignments for today

**Card formatting summary:**

- Each card is a box-drawn body (`╭─╮│╰╯`) wrapped in a GitHub alert (`[!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`) so it renders with a coloured frame in Claude Code chat.
- Internal width: 58 chars (60 total with borders).
- Weather line silently skipped on API failure or `kingdom.json.welcome.weather = false`.
- Variant by hour: morning (5-11), afternoon (12-17), evening (18-21), late (22-4).

Other cards fired by `/kingdom:day` later in the cycle (Step 5 poll loop / Step 6 push gate):

- [`cards/task-complete.md`](../.kingdom/.setting/cards/task-complete.md) — Tier-2 gate pass (~20 random congratulatory lines)
- [`cards/push-prompt.md`](../.kingdom/.setting/cards/push-prompt.md) — Tier-2 passed, awaiting "push" word
- [`cards/gate-fail.md`](../.kingdom/.setting/cards/gate-fail.md) — Tier-1 or Tier-2 fail
- [`cards/cap-reached.md`](../.kingdom/.setting/cards/cap-reached.md) — `cap=N` hit
- [`cards/end-of-day.md`](../.kingdom/.setting/cards/end-of-day.md) — day stops (exit, cap reached, all idle)
- [`cards/pr-merged.md`](../.kingdom/.setting/cards/pr-merged.md) — PR flips MERGED (triggers R26 resync)
- [`cards/conflict-detected.md`](../.kingdom/.setting/cards/conflict-detected.md) — `git merge-tree` finds drift at push time

See [`cards/README.md`](../.kingdom/.setting/cards/README.md) for the full index + alert-flavour mapping.

The **Suggested next task** synthesis draws from (in priority order):
1. **Unfinished prior-session work** — task files in `.kingdom/${project}/tasks/` with Status ∈ `planning|executing|verifying` and no matching sentinel in `logs/done/`.
2. **Lead-requested follow-ups** — open PRs with unresolved review comments.
3. **Unflipped acceptance criteria** in the project task-ledger (`TODO_*.md`, `TODO_Master.csv`, `STEP.md`) that match an idle lane's domain.
4. **Watchman gap findings** in `WATCH_DOCS_AUDIT.md`.
5. **New work** — first unstarted heading in the task-ledger that has no dependency-blocking.

King picks 1-3 candidates and presents them as a numbered choice; the user can pick one or say "go" to accept the first.

## Step 4 — Auto-dispatch (within cap/target) — HARD 60s TIME BUDGET (R30)

**R30 hard rule:** from this step starting, no more than 60 seconds elapses before the first `cmux send` fires to a worker. King is ORCHESTRATOR, not executor. If King catches itself drafting a multi-batch execution plan in chat instead of dispatching — STOP and dispatch with the brief as-is. Layer-2 Strategy happens INSIDE the lane after dispatch, not in chat before dispatch.

```bash
DISPATCH_START=$(date +%s)
for lane in $IDLE_LANES; do
  # Skip co-workers (R32 — co-workers wait for explicit pair-on signal)
  [[ "$lane" == co-worker-* ]] && continue
  # Skip watchmen (always running /loop, never task-dispatched)
  [[ "$lane" == watchman-* ]] && continue

  # Pick next task from queue (skill-routing applied per R23)
  TASK=$(pick_next_task_for "$lane")
  [ -z "$TASK" ] && { echo "🐾 $lane idle (no claimable task)"; continue; }

  SUGGESTED_SKILLS=$(pick_skills_for_task "$TASK" "$lane")
  export LANE="$lane" TASK_ID="$TASK" SUGGESTED_SKILLS
  BRIEF=$(render_card "dispatch-brief")

  cmux send --workspace "$(grep "^${lane}_WS=" "$REFS_FILE" | cut -d= -f2)" -- "$BRIEF"
  echo "▶ Dispatched $lane → $TASK"
  TASKS_DISPATCHED_TODAY=$((TASKS_DISPATCHED_TODAY + 1))

  # R30 budget check
  ELAPSED=$(( $(date +%s) - DISPATCH_START ))
  if [ "$ELAPSED" -gt 60 ]; then
    echo "⚠ R30: dispatch budget exceeded (${ELAPSED}s). Continuing remaining dispatches but flag for review."
  fi
done
```

Cap/target enforcement:

```bash
if [ "$TASKS_DISPATCHED_TODAY" -ge "$CAP" ]; then
  echo "🛑 Daily cap (cap=$CAP) reached. Holding further dispatch."
  break
fi
if [ "$TASKS_DISPATCHED_TODAY" -ge "$TARGET_DAY_HI" ]; then
  echo "🟢 Daily target band reached ($TARGET_DAY_LO-$TARGET_DAY_HI). Continuing at lower pace."
  # King still dispatches but flags as "above target" in chat
fi
```

Workers begin work in parallel (per rules.md R28 parallel-by-default).

**Anti-pattern (R30 violation):** drafting "Worker-N plan (final)" multi-batch tables in CHAT before dispatching. That table belongs in the lane's task file as `## Plan` (Layer-2 Strategy), written BY the lane AFTER it receives the brief. King's brief lists the task ID + AC + skills + dependencies — not a 9-batch execution plan.

**Anti-pattern (R32 violation):** printing `worker-1 staged · awaiting your dictation`. Workers don't wait. If worker-1 has no claimable task, mark it `🐾 idle (no claimable task)` and continue to the next lane. Only co-workers wait, and only for the explicit `pair on co-worker-N` signal.

## Step 5 — Auto-gate-poll loop (the perpetual part)

King enters a perpetual poll loop. Each tick:

```bash
LOGS="$PWD/.kingdom/${project}/logs"

while true; do
  # 5a. Detect un-gated sentinels (per kings.md § Auto-gate on completion)
  for FLAG in "$LOGS"/done/*.flag; do
    [ -f "$FLAG" ] || continue
    BASE=$(basename "$FLAG" .flag)
    LANE=$(echo "$BASE" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    SUBTASK_ID=$(echo "$BASE" | sed 's/.*__//')

    # Already gated? (test report exists)
    if ls "$PWD/${project}/docs/test-reports/KING_"*"__${LANE}__${SUBTASK_ID}.md" >/dev/null 2>&1; then
      continue
    fi

    # Fire Tier-1 gate in lane's worktree
    cmux_set_state "▶" "Tier-1 gate · ${LANE} · ${SUBTASK_ID}"
    run_tier1_gate "${LANE}" "${SUBTASK_ID}"

    if [ "$?" = "0" ]; then
      cmux_set_state "▶" "Overlaying ${LANE} onto kingdom"
      overlay_lane_onto_kingdom "${LANE}"

      cmux_set_state "▶" "Tier-2 gate · kingdom overlay"
      run_tier2_gate

      if [ "$?" = "0" ]; then
        # Tier-2 passed: print task-complete card (random congratulatory line),
        # then push-prompt card (requires user's 'push' word per R1)
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

        cmux_set_state "⚠" "Review live diff · ${LANE} · ${SUBTASK_ID}"
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

## Step 6 — On user's "push" approval per PR

```bash
git checkout -b "feature/${TOPIC}" "${LANE}"
PR_BODY=$(generate_pr_body_from_task_file "${LANE}" "${SUBTASK_ID}")
git push -u origin "feature/${TOPIC}"
gh pr create --base develop --head "feature/${TOPIC}" \
  --title "<from task file Brief>" \
  --body "$PR_BODY"

# Post-push overlay discard per rules.md R29
git checkout kingdom
git reset --hard origin/develop
git clean -fd

cmux_set_state "✅" "Pushed feature/${TOPIC}"
cmux workspace-action --action mark-read --workspace "$KING_WS"

TASKS_DISPATCHED_TODAY=$((TASKS_DISPATCHED_TODAY + 1))
```

After push, King returns to Step 5's poll loop. The cycle continues until stopping conditions apply.

## Stopping the day

The day stops on any of:

- User runs `/kingdom:exit ${project}` (graceful teardown)
- User says "stop" or "hold" in chat (King exits the auto-loop; lanes stay alive)
- `cap=N` reached + no in-flight gates pending (King exits loop, waits for next-day instruction)
- All lanes idle AND no pending work AND no in-flight PRs (King exits loop, says "Day complete; run `/kingdom:exit` to close lanes.")

## Conventions

- **Daily ritual.** `/kingdom:day <project>` is THE canonical daily entry point. Use it every morning. Composes `/kingdom:update` (always) + `/kingdom:start` (idempotent) + kickoff + auto-gate-poll loop + per-push approval gates.
- **Building-block commands stay available.** `/kingdom:update` and `/kingdom:start` remain as standalone commands for power users (mid-day re-audit, resume-only after King crash). Most users won't invoke them directly.
- **Blocks only on human decisions.** Review approval, push approval, blocked-lane resolution. Everything else flows autonomously per kingdom rules.
- **Argument parsing is forgiving.** `target=30-50/week` and `cap=5` are interpreted then echoed back in Step 0.2 so the user can correct typos before the loop fires.
- **State machine.** `/kingdom:day` is the orchestrator; `/kingdom:update` and `/kingdom:start` are the building blocks. Same audit trail, same artifacts, same gate flow.
