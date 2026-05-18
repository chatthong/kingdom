---
description: Gracefully teardown the kingdom — check in-flight work, save state, close all lane workspaces (King's workspace stays by default).
argument-hint: [project=<name>] [--force] [--include-king] [--audit]
---

You are gracefully closing the kingdom for ONE project. Default behaviour: ask about in-flight work, then close all lane workspaces (workers / co-workers / watchmen) while keeping the King's workspace alive. Idempotent — safe to run twice.

## Step 0 — Resolve project + flags

From `$ARGUMENTS`:

- `project=<name>` — optional; defaults to `basename "$PWD"`.
- `--force` — optional; skips the in-flight check (still saves logs). Use when you know lanes are idle and want a fast close.
- `--include-king` — optional; ALSO closes the King's workspace at the end. Default: keep the King's workspace (your conversation persists).
- `--audit` — optional; runs `/kingdom:update` before closing (pre-exit gap synthesis). Default: skip audit (faster exit; user can run audit manually first if wanted).

Verify the project exists:

```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom:init ${project}` was never run, stop.

Source workspace refs from the file `/kingdom:start` persisted:

```bash
LOGS="$PWD/.kingdom/${project}/logs"
REFS="$LOGS/workspace-refs.env"

if [ ! -f "$REFS" ]; then
  echo "No workspace-refs.env — kingdom wasn't started in PRIMARY mode (or refs were cleaned)."
  echo "Falling back to manual workspace discovery via cmux tree."
  # Skip the cmux-managed close steps; just write the session-end log line.
fi

[ -f "$REFS" ] && source "$REFS"
```

## Step 1 — In-flight check

```bash
echo "👑 Checking for in-flight work..."

# Scan claims
CLAIMS=$(ls "$LOGS/claims/"*.lane 2>/dev/null | wc -l | tr -d ' ')
echo "  Active claims: $CLAIMS"
[ "$CLAIMS" -gt 0 ] && ls "$LOGS/claims/" 2>/dev/null

# Scan task files for unchecked-but-not-blocked status
MID_TASK=0
for TF in "$PWD/.kingdom/${project}/tasks/"*.md; do
  [ -f "$TF" ] || continue
  STATUS_LINE=$(grep -E '^- \[[ x]\] (planning|executing|verifying|done|blocked)' "$TF" | head -1)
  # If any non-done, non-blocked task with unchecked sub-bullets exists
  if grep -qE '^\s*- \[ \]' "$TF" && ! grep -qE 'Status:.*\b(done|blocked)\b' "$TF"; then
    MID_TASK=$((MID_TASK + 1))
    echo "  ⚠️  Mid-task: $(basename "$TF")"
  fi
done
echo "  Mid-task lanes: $MID_TASK"
```

If `--force` is given, skip the prompt and proceed to Step 2.

Otherwise, if `CLAIMS > 0 OR MID_TASK > 0`, ask the user (the 3-option Option C dialogue):

```
⚠️  Kingdom has in-flight work for "${project}":
   - $CLAIMS active claims
   - $MID_TASK lanes mid-task

How do you want to proceed?

  1) Wait for completion — block until all sentinels appear (max 5 min, then force-close)
  2) Force-close       — close workspaces now; task files stay with last-known state
  3) Abort             — cancel /kingdom:exit; resolve manually

Choice [1/2/3]:
```

Branch on response:

- **1 wait**: enter a polling loop:
  ```bash
  WAIT_DEADLINE=$(($(date +%s) + 300))
  while [ "$CLAIMS" -gt 0 ] && [ "$(date +%s)" -lt "$WAIT_DEADLINE" ]; do
    sleep 10
    CLAIMS=$(ls "$LOGS/claims/"*.lane 2>/dev/null | wc -l | tr -d ' ')
    echo "  Waiting... $CLAIMS active claims"
  done
  [ "$CLAIMS" -gt 0 ] && echo "  Timeout — proceeding with force-close on remaining $CLAIMS lanes"
  ```
- **2 force**: continue to Step 2 immediately, leave a footnote in each mid-task file.
- **3 abort**: stop. Tell user: "Aborted. No state changed."

If clean (no in-flight): just continue.

## Step 2 — Optional audit pass

If `--audit` was given:

```bash
echo "👑 Running final /kingdom:update before close..."
# Effectively re-dispatch the existing /kingdom:update flow
# (The slash command itself can't easily re-invoke another slash command;
# instead, instruct the King to call /kingdom:update via the Agent tool,
# wait for sentinel, then continue.)
```

If `--audit` was NOT given, skip — just print: "Skipping pre-exit audit (pass `--audit` to enable)."

## Step 3 — Notify each lane

For each lane workspace (sourced from workspace-refs.env):

```bash
notify_lane () {
  local ws="$1" label="$2"
  cmux notify --workspace "$ws" \
    --title "👑 kingdom:exit" \
    --subtitle "Session ending" \
    --body "Saving state and closing $label in ~5s." 2>/dev/null
}

for I in $(env | grep -E '^WORKER_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  notify_lane "$REF" "👷 worker-${I#WORKER_WS_}"
done
for I in $(env | grep -E '^COWORKER_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  notify_lane "$REF" "🧑‍💼 co-worker-${I#COWORKER_WS_}"
done
for I in $(env | grep -E '^WATCHMAN_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  notify_lane "$REF" "🕵️ watchman-${I#WATCHMAN_WS_}"
done

sleep 5    # give lanes a moment to see the notification
```

## Step 4 — Graceful Claude exit per lane

Send `/clear` to each lane's Claude session so it gets a chance to persist state:

```bash
exit_lane () {
  local ws="$1"
  # /clear is the safest "wrap up" signal; Claude Code persists conversation history regardless
  cmux send --workspace "$ws" -- "/clear" 2>/dev/null
  cmux send --workspace "$ws" Enter 2>/dev/null
}

for I in $(env | grep -E '^(WORKER|COWORKER|WATCHMAN)_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  exit_lane "$REF"
done

sleep 3    # let Claude process the /clear
```

## Step 5 — Close lane workspaces (PARALLEL — rules.md R28)

Use the canonical `cmux close-workspace` — NOT `cmux tab-action --action close --workspace` (that errors with `Unknown tab action`). See [`cmux.md` § Teardown / close commands](../.kingdom/.setting/cmux.md#teardown--close-commands).

```bash
# Parallel fan-out: each lane workspace closes independently (no cross-lane dependency)
for I in $(env | grep -E '^(WORKER|COWORKER|WATCHMAN)_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  cmux close-workspace --workspace "$REF" 2>/dev/null &
done
wait
echo "✓ All lane workspaces closed"
```

If `--include-king` was given (King's workspace closes LAST and serially — it terminates your conversation):

```bash
# Serial + last — closing King's own workspace ends the session
cmux close-workspace --workspace "$KING_WS" 2>/dev/null
```

Otherwise (default): leave `$KING_WS` alone. Your conversation persists.

## Step 6 — Session-end log + report

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
DONE_COUNT=$(ls "$LOGS/done/"*.flag 2>/dev/null | wc -l | tr -d ' ')
GAP_COUNT=0
LATEST_GAP=$(ls -1t "$LOGS/kingdom-update-"*.md 2>/dev/null | head -1)
if [ -n "$LATEST_GAP" ]; then
  GAP_COUNT=$(grep -c '^- ' "$LATEST_GAP" 2>/dev/null || echo 0)
fi

# Append the session-end marker
{
  echo "[$UTC] 👑 kingdom:exit · session closed · ${DONE_COUNT} sentinels in this project · ${GAP_COUNT} gap-items in most recent audit"
} >> "$LOGS/master_agent.log"

# Clear stale workspace-refs.env (refs are now invalid; next /kingdom:start rebuilds)
rm -f "$REFS"
```

Print a final summary to the user:

```
👑 Kingdom session closed for "${project}"

  Closed workspaces:
    👷 worker-1 .. worker-N
    🧑‍💼 co-worker-1 .. co-worker-M
    🕵️ watchman-1 .. watchman-K
  King's workspace: <kept | also closed>

  Session stats:
    Sentinels written:    ${DONE_COUNT}
    Latest audit gaps:    ${GAP_COUNT}
    Session-end logged:   master_agent.log

Next time, run `/kingdom:start ${project}` to rebuild lanes.
```

---

## Conventions

- **Default keeps King.** Pass `--include-king` for full teardown.
- **Always ask on in-flight.** Default behaviour. Override with `--force`.
- **Idempotent.** Re-running on an already-exited kingdom prints "no workspaces to close" and updates the session-end line only.
- **Won't kill external worktrees.** `/kingdom:exit` does NOT remove the `.worktrees/*` directories — those persist for `/kingdom:start` to re-attach. Use `git worktree remove` manually if you want them gone.
- **Won't push or commit.** `/kingdom:exit` never runs `git push` or `git commit`. King's push gate is independent — push your in-flight work via the normal "push?" flow before calling exit.
