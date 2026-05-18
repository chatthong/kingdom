---
description: One-command daily cycle — runs /kingdom:update + /kingdom:start + daily kickoff + auto-gate loop until you need to review/approve. Only blocks for human decisions.
argument-hint: [project=<name>]
---

You are running the kingdom's **full daily cycle** as a single orchestrated flow. The user typed ONE command and expects the kingdom to "just run the day" until it needs review/push approval. Block ONLY on genuine human-decision points.

## Step 0 — Resolve project

From `$ARGUMENTS`, extract `project=<name>` or default to `basename "$PWD"`.

Verify `.kingdom/${project}/` exists. If missing, tell the user to run `/kingdom:init ${project}` first.

## Step 1 — Audit (run `/kingdom:update` if last run was >24h ago)

```bash
LAST_AUDIT=$(ls -1t "$PWD/.kingdom/${project}/logs/kingdom-update-"*.md 2>/dev/null | head -1)
LAST_AUDIT_AGE_HRS=$(if [ -n "$LAST_AUDIT" ]; then
  echo $(( ($(date +%s) - $(stat -f %m "$LAST_AUDIT" 2>/dev/null || stat -c %Y "$LAST_AUDIT")) / 3600 ))
else
  echo 99
fi)

if [ "$LAST_AUDIT_AGE_HRS" -gt 24 ]; then
  echo "👑 Running /kingdom:update first (last audit was ${LAST_AUDIT_AGE_HRS}h ago)..."
  # Invoke the audit pass (parallel Lead + 4 specialists per /kingdom:update spec)
  # Wait for sentinel before continuing
fi
```

## Step 2 — Spin up the kingdom (`/kingdom:start` — idempotent)

```bash
echo "👑 Spinning up kingdom for ${project}..."
# Invoke /kingdom:start ${project} — idempotent; resumes if already running.
```

## Step 3 — Daily kickoff (per kings.md § Daily kickoff routine)

King reads:
- **Step −1**: workspace + project CLAUDE.md, MEMORY.md, personal notes
- **Step 0**: watchman state (`WATCH_*.md` + `WATCH_DOCS_AUDIT.md` + `watchman_state.json`)

Print the synthesis to chat:

```text
👑 Good morning. Daily cycle running for ${project}.

Context loaded:
   • Workspace CLAUDE.md  (...)
   • Project CLAUDE.md    (...)
   • MEMORY.md            (42 entries)
   • Personal notes       (TER.md — read but never quoted)

Watchman state:
   • develop:        green @ <UTC>
   • PR queue:       <N> open
   • Lanes blocked:  <N>
   • Gap findings:   <N> in WATCH_DOCS_AUDIT.md

Today's auto-dispatch plan:
   • worker-1 → <task-1>
   • worker-2 → <task-2>
   • worker-3 → <task-3>
   • co-worker-1 → (held for paired work)
   • watchman-1 → /loop running

I'll auto-dispatch + auto-gate + overlay onto kingdom as work completes.
You'll be notified when I need: review approval / push approval / blocked-lane resolution.
```

## Step 4 — Auto-dispatch (load idle lanes per kings.md § Lane utilisation rules)

For each idle lane with an obvious pending task match, King dispatches automatically (per 60/40 industrial rule). Workers begin work in parallel.

## Step 5 — Auto-gate-poll loop (the magic part)

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

    # On pass → overlay onto kingdom + fire Tier-2
    if [ "$?" = "0" ]; then
      cmux_set_state "▶" "Overlaying ${LANE} onto kingdom"
      overlay_lane_onto_kingdom "${LANE}"

      cmux_set_state "▶" "Tier-2 gate · kingdom overlay"
      run_tier2_gate

      # Tier-2 pass → ask Ter to review (BLOCKING)
      if [ "$?" = "0" ]; then
        cmux_set_state "⚠" "Review live diff · ${LANE} · ${SUBTASK_ID}"
        cmux workspace-action --action mark-unread --workspace "$KING_WS"
        cmux notify --workspace "$KING_WS" \
          --title "👑 King · review ready" \
          --subtitle "${LANE} · ${SUBTASK_ID}" \
          --body "Tier-2 passed. Review live diff in GitHub Desktop; reply 'push' to publish."
        wait_for_ter_decision   # blocks here
      else
        # Tier-2 fail
        cmux notify --workspace "$KING_WS" --title "👑 King · Tier-2 FAIL" \
          --subtitle "${LANE} · ${SUBTASK_ID}" \
          --body "<failure summary>"
        # May dispatch fix-task
      fi
    fi
  done

  # 5b. Check for blocked lanes (per watchmans.md § Blocked-lane scan)
  # (watchman handles this autonomously; King reads watchman_state.json)

  # 5c. Re-check capacity utilisation (idle lanes + pending work)
  # If new pending tasks appeared (Gap A backfill, fix-task, etc), auto-dispatch

  # 5d. Sleep before next tick (blocking poll inside single Bash call = zero token cost)
  sleep 10
done
```

## Step 6 — On Ter's "push" approval per PR

```bash
# Carve feature/<topic> from worker-N tip (byte-for-byte per v0.16.3)
git checkout -b "feature/${TOPIC}" "${LANE}"

# Build auto-generated PR body from task file (v0.18.0)
PR_BODY=$(generate_pr_body_from_task_file "${LANE}" "${SUBTASK_ID}")

# Push + open PR
git push -u origin "feature/${TOPIC}"
gh pr create --base develop --head "feature/${TOPIC}" \
  --title "<from task file Brief>" \
  --body "$PR_BODY"

# After push, discard kingdom overlay (per v0.17.0)
git checkout kingdom
git restore .

cmux_set_state "✅" "Pushed feature/${TOPIC}"
cmux workspace-action --action mark-read --workspace "$KING_WS"
```

See [`kings.md`](.kingdom/.setting/kings.md) → § "Auto-generated PR body from task file" for the body construction rules.

## Step 7 — Loop continues

After each push (or after Ter says "hold"), King returns to Step 5's poll loop. The cycle continues for as long as there's work to do.

## Stopping the day

The day stops on any of:
- Ter runs `/kingdom:exit ${project}` (graceful teardown)
- Ter says "stop" or "hold" or similar in chat (King exits the auto-loop, lanes stay alive)
- All lanes idle AND no pending work AND no in-flight PRs (King exits loop, says "Day complete — kingdom idle. Run `/kingdom:exit` to close lanes.")

## Conventions

- **Single-command flow.** `/kingdom:day my-app` is the canonical daily entry point. Compose of `/kingdom:update` + `/kingdom:start` + auto-gate-poll loop + per-push approval gates.
- **Blocks only on human decisions** — review approval, push approval, blocked-lane resolution. Everything else flows autonomously per kingdom rules.
- **All other slash commands remain available.** `/kingdom:day` is a convenience composition; you can still invoke `/kingdom:update`, `/kingdom:start`, `/kingdom:exit` individually if you want manual control over each phase.
- **State machine.** `/kingdom:day` is the orchestrator; underlying slash commands are the building blocks. Same audit trail, same artifacts, same gate flow — just driven by one command instead of typed sequence.
