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

King prints the interpreted budget in the kickoff brief so Ter can correct before the loop fires.

### Step 0.2 — Print parse summary BEFORE acting

```text
👑 Parsed arguments:
   project = bfg-swt
   target  = 30-50/week  → today's budget 6-10 · week 30-50 · month 120-200
   cap     = (none)

Proceeding to audit + spawn + kickoff...
```

If the parse is ambiguous (unknown period, malformed range), print the issue + stop.

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

## Step 3 — Daily kickoff (with local date+time + Suggested next task)

King reads in the order R14 mandates (rules.md → workspace + project CLAUDE.md → README.md → docs/ → MEMORY.md → personal notes → watchman state) and prints:

```bash
LOCAL_DATETIME=$(date '+%A, %B %-d, %Y · %H:%M %Z')
```

```text
👑 Good morning, Ter.
   ${LOCAL_DATETIME}

Daily ritual running for ${project}.

Target: 30-50/week → today's budget 6-10 tasks
        (this week so far: <DONE_THIS_WEEK> done · <IN_FLIGHT> in-flight)

Context loaded:
   • rules.md / CLAUDE.md / README.md / docs/ / MEMORY.md / TER.md
   • Watchman state: develop <STATUS> @ <LAST_TICK>
   • PR queue: <N_OPEN> open · <N_MERGED_TODAY> merged today
   • Lanes blocked: <N_BLOCKED>

Suggested next task:
   → <BEST_FIT_TASK_ID> · <one-line why this one fits next>
   OR: <ALT_TASK_ID> · <one-line why>
   OR: new — pick from <TASK_LEDGER_PATH> <SECTION>

Today's auto-dispatch plan (within cap/target):
   • worker-1 → <task>
   • worker-2 → <task>
   • worker-3 → <task>
   • co-worker-1 → (held for paired work)
   • watchman-1 → /loop running

I'll auto-dispatch + auto-gate + overlay onto kingdom as work completes.
You'll be notified when I need: review approval, push approval, or blocked-lane resolution.
```

The **Suggested next task** synthesis draws from (in priority order):
1. **Unfinished prior-session work** — task files in `.kingdom/${project}/tasks/` with Status ∈ `planning|executing|verifying` and no matching sentinel in `logs/done/`.
2. **Lead-requested follow-ups** — open PRs with unresolved review comments.
3. **Unflipped acceptance criteria** in the project task-ledger (`TODO_*.md`, `TODO_Master.csv`, `STEP.md`) that match an idle lane's domain.
4. **Watchman gap findings** in `WATCH_DOCS_AUDIT.md`.
5. **New work** — first unstarted heading in the task-ledger that has no dependency-blocking.

King picks 1-3 candidates and presents them as a numbered choice; Ter can pick one or say "go" to accept the first.

## Step 4 — Auto-dispatch (within cap/target)

For each idle lane with an obvious pending task match (per kings.md § Lane utilisation rules), King dispatches automatically. Respects `cap` (hard) and `target` (soft):

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
        cmux_set_state "⚠" "Review live diff · ${LANE} · ${SUBTASK_ID}"
        cmux workspace-action --action mark-unread --workspace "$KING_WS"
        cmux notify --workspace "$KING_WS" \
          --title "👑 King · review ready" \
          --subtitle "${LANE} · ${SUBTASK_ID}" \
          --body "Tier-2 passed. Review live diff in GitHub Desktop; reply 'push' to publish."
        wait_for_ter_decision
      else
        cmux notify --workspace "$KING_WS" --title "👑 King · Tier-2 FAIL" \
          --subtitle "${LANE} · ${SUBTASK_ID}" \
          --body "<failure summary>"
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

## Step 6 — On Ter's "push" approval per PR

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

- Ter runs `/kingdom:exit ${project}` (graceful teardown)
- Ter says "stop" or "hold" in chat (King exits the auto-loop; lanes stay alive)
- `cap=N` reached + no in-flight gates pending (King exits loop, waits for next-day instruction)
- All lanes idle AND no pending work AND no in-flight PRs (King exits loop, says "Day complete; run `/kingdom:exit` to close lanes.")

## Conventions

- **Daily ritual.** `/kingdom:day <project>` is THE canonical daily entry point. Use it every morning. Composes `/kingdom:update` (always) + `/kingdom:start` (idempotent) + kickoff + auto-gate-poll loop + per-push approval gates.
- **Building-block commands stay available.** `/kingdom:update` and `/kingdom:start` remain as standalone commands for power users (mid-day re-audit, resume-only after King crash). Most users won't invoke them directly.
- **Blocks only on human decisions.** Review approval, push approval, blocked-lane resolution. Everything else flows autonomously per kingdom rules.
- **Argument parsing is forgiving.** `target=30-50/week` and `cap=5` are interpreted then echoed back in Step 0.2 so Ter can correct typos before the loop fires.
- **State machine.** `/kingdom:day` is the orchestrator; `/kingdom:update` and `/kingdom:start` are the building blocks. Same audit trail, same artifacts, same gate flow.
