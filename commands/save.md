---
description: Snapshot lane state to state.json + close lane workspaces. No commits, no pushes — branches are the natural save.
argument-hint: [project]
---

You are snapshotting the kingdom for ONE project. **No commits, no pushes, no git mutations.** The branches in each worktree are the natural checkpoint; this command only records what's where so `/kingdom:work` can resume cleanly next session.

Default behaviour: collect lane git state + task status, write `.kingdom/<project>/state.json`, close all lane workspaces, keep King's workspace alive.

## Step 0 — Resolve project

From `$ARGUMENTS`, extract the first positional token as `<project>`. If absent, default to `basename "$PWD"`.

Verify the project is initialised:

```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom:init ${project}` was never run, and stop.

Source workspace refs:

```bash
LOGS="$PWD/.kingdom/${project}/logs"
TASKS_DIR="$PWD/.kingdom/${project}/tasks"
REFS="$LOGS/workspace-refs.env"
[ -f "$REFS" ] && source "$REFS"
```

Read lane shape from `kingdom.json`:

```bash
KJSON="$PWD/.kingdom/${project}/kingdom.json"
WORKERS=$(jq -r '.shape.workers // 3' "$KJSON")
COWORKERS=$(jq -r '.shape["co-workers"] // 1' "$KJSON")
WATCHMEN=$(jq -r '.shape.watchman // 1' "$KJSON")
BASE=$(jq -r '.git.base // "develop"' "$KJSON")
PROJ="$PWD/${project}"
```

## Step 1 — Collect lane state

For each lane in the effective shape, capture: current HEAD SHA, short status file count, the active task file (if any) and its Status field, and any staged/unstaged files.

```bash
collect_lane_state () {
  local lane="$1"
  local worktree="$PROJ/.worktrees/$lane"

  if [ ! -d "$worktree" ]; then
    echo "{\"lane\":\"$lane\",\"worktree_missing\":true}"
    return
  fi

  local head_sha branch uncommitted task_file task_status task_id

  head_sha=$(git -C "$worktree" rev-parse HEAD 2>/dev/null || echo "unknown")
  branch=$(git -C "$worktree" branch --show-current 2>/dev/null || echo "unknown")
  uncommitted=$(git -C "$worktree" status --short 2>/dev/null | wc -l | tr -d ' ')

  # Find the newest task file that belongs to this lane + has no sentinel
  task_file=""
  task_id=""
  task_status="null"
  for tf in $(ls -1t "$TASKS_DIR"/*.md 2>/dev/null); do
    base=$(basename "$tf" .md)
    tf_lane=$(echo "$base" | sed 's/^[0-9-]*T[0-9]*Z__//;s/__.*//')
    if [ "$tf_lane" = "$lane" ]; then
      tid=$(echo "$base" | sed 's/.*__//')
      has_sentinel=0
      ls "$LOGS/done"/*"__${lane}__${tid}.flag" >/dev/null 2>&1 && has_sentinel=1
      if [ "$has_sentinel" = "0" ]; then
        task_file="$tf"
        task_id="$tid"
        task_status=$(grep -E '^- \[x\] (planning|executing|verifying|done|blocked|cancelled)' "$tf" \
          | tail -1 | grep -oE '(planning|executing|verifying|done|blocked|cancelled)' || echo "planning")
        break
      fi
    fi
  done

  jq -n \
    --arg lane "$lane" \
    --arg branch "$branch" \
    --arg head_sha "$head_sha" \
    --argjson uncommitted "$uncommitted" \
    --arg task_id "${task_id:-}" \
    --arg task_status "${task_status:-null}" \
    --arg task_file "${task_file:-}" \
    '{
      lane: $lane,
      branch: $branch,
      head_sha: $head_sha,
      uncommitted_files: $uncommitted,
      task: (if $task_id == "" then null else {
        id: $task_id,
        status: $task_status,
        file: $task_file
      } end)
    }'
}

LANE_STATES='[]'
for I in $(seq 1 "$WORKERS"); do
  STATE=$(collect_lane_state "worker-$I")
  LANE_STATES=$(echo "$LANE_STATES" | jq ". + [$STATE]")
done
for I in $(seq 1 "$COWORKERS"); do
  STATE=$(collect_lane_state "co-worker-$I")
  LANE_STATES=$(echo "$LANE_STATES" | jq ". + [$STATE]")
done
for I in $(seq 1 "$WATCHMEN"); do
  STATE=$(collect_lane_state "watchman-$I")
  LANE_STATES=$(echo "$LANE_STATES" | jq ". + [$STATE]")
done
```

Print the collected lane states for the user to review before writing.

## Step 2 — Collect open PRs

```bash
OPEN_PRS=$(gh pr list --state open --json number,state,headRefName 2>/dev/null \
  || echo '[]')
echo "Open PRs: $(echo "$OPEN_PRS" | jq length)"
```

## Step 3 — Compute ready_for_fresh_work

`ready_for_fresh_work` is `true` if and only if EVERY lane satisfies BOTH conditions:
- `task` is `null` (no in-flight task file without a sentinel)
- `uncommitted_files` is `0`

```bash
READY_FOR_FRESH_WORK=$(echo "$LANE_STATES" | jq '
  all(.[]; .task == null and .uncommitted_files == 0)
')

if [ "$READY_FOR_FRESH_WORK" = "true" ]; then
  echo "All lanes clean. ready_for_fresh_work=true"
else
  echo "In-flight work detected. ready_for_fresh_work=false"
  echo "$LANE_STATES" | jq '.[] | select(.task != null or .uncommitted_files > 0) | .lane'
fi
```

## Step 4 — Write state.json

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
STATE_FILE="$PWD/.kingdom/${project}/state.json"

jq -n \
  --arg schema_version "1" \
  --arg saved_at_utc "$UTC" \
  --arg project "$project" \
  --argjson lanes "$LANE_STATES" \
  --argjson open_prs "$OPEN_PRS" \
  --argjson ready_for_fresh_work "$READY_FOR_FRESH_WORK" \
  '{
    schema_version: ($schema_version | tonumber),
    saved_at_utc: $saved_at_utc,
    project: $project,
    lanes: $lanes,
    open_prs: $open_prs,
    ready_for_fresh_work: $ready_for_fresh_work
  }' > "$STATE_FILE"

echo "Wrote state.json to $STATE_FILE"
cat "$STATE_FILE"
```

**State.json schema:**

```json
{
  "schema_version": 1,
  "saved_at_utc": "2026-05-18T1430Z",
  "project": "bfg-swt",
  "lanes": [
    {
      "lane": "worker-1",
      "branch": "worker-1",
      "head_sha": "a1b2c3d",
      "uncommitted_files": 3,
      "task": {
        "id": "FE-P0-FOUND-5",
        "status": "executing",
        "file": ".kingdom/bfg-swt/tasks/2026-05-18T1100Z__worker-1__FE-P0-FOUND-5.md"
      }
    }
  ],
  "open_prs": [
    { "number": 258, "state": "OPEN", "headRefName": "feature/auth-bff" }
  ],
  "ready_for_fresh_work": false
}
```

## Step 5 — Close lane workspaces in parallel

Per R28 (parallel-by-default), close all lane workspaces concurrently. King's workspace (`$KING_WS`) is NOT closed — your conversation persists.

```bash
echo "Closing lane workspaces..."

# Collect lane workspace refs
LANE_WSes=""
for I in $(seq 1 "$WORKERS");   do
  REF=$(grep "^worker-${I}_WS=" "$REFS" 2>/dev/null | cut -d= -f2)
  [ -n "$REF" ] && LANE_WSes="$LANE_WSes $REF"
done
for I in $(seq 1 "$COWORKERS"); do
  REF=$(grep "^co-worker-${I}_WS=" "$REFS" 2>/dev/null | cut -d= -f2)
  [ -n "$REF" ] && LANE_WSes="$LANE_WSes $REF"
done
for I in $(seq 1 "$WATCHMEN");  do
  REF=$(grep "^watchman-${I}_WS=" "$REFS" 2>/dev/null | cut -d= -f2)
  [ -n "$REF" ] && LANE_WSes="$LANE_WSes $REF"
done

CLOSE_PIDS=""
for ws in $LANE_WSes; do
  cmux close-workspace --workspace "$ws" 2>/dev/null &
  CLOSE_PIDS="$CLOSE_PIDS $!"
done
# R42: bounded wait — cmux close-workspace usually <0.05s but can stall if a workspace
# is mid-spawn or has unresponsive surface; 15s budget is generous.
_bounded_wait 15 $CLOSE_PIDS || echo "⚠️ teardown hit 15s budget; survivors killed (next /kingdom:work will rebuild)"

echo "All lane workspaces closed."

# Clear stale workspace refs (invalid after close; next /kingdom:work rebuilds)
rm -f "$REFS"
```

If `workspace-refs.env` was absent (kingdom not run in PRIMARY mode), print: "No workspace refs found — skipping cmux close step."

## Step 6 — Append session-end line + render session-saved card

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
DONE_COUNT=$(ls "$LOGS/done/"*.flag 2>/dev/null | wc -l | tr -d ' ')

echo "[$UTC] 👑 kingdom:save · session snapshotted · ${project} · ${DONE_COUNT} sentinels · ready_for_fresh_work=${READY_FOR_FRESH_WORK}" \
  >> "$LOGS/master_agent.log"
```

Render the `session-saved` card:

```bash
export PROJECT="$project" SAVED_AT_UTC="$UTC" DONE_COUNT READY_FOR_FRESH_WORK
export OPEN_PR_COUNT=$(echo "$OPEN_PRS" | jq length)
render_card "session-saved"
```

**`session-saved` card template** (inline — no separate card file required; King renders it directly):

```markdown
> [!TIP]
> ```
> ╭─ 💾 Session saved · ${PROJECT} ────────────────────────╮
> │  ${SAVED_AT_UTC}                                        │
> │                                                         │
> │  Sentinels fired:  ${DONE_COUNT}                        │
> │  Open PRs:         ${OPEN_PR_COUNT}                     │
> │  Ready for fresh:  ${READY_FOR_FRESH_WORK}              │
> │                                                         │
> │  state.json written. Lanes closed.                      │
> │  Next: /kingdom:work ${PROJECT} to resume.              │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Conventions

- **No commits, no pushes.** Branches in worktrees ARE the save. `/kingdom:save` only records where each lane's HEAD is so King can re-orient on resume.
- **Idempotent.** Re-running overwrites `state.json` with fresh snapshot. Safe to run twice.
- **King's workspace stays alive.** Pass nothing to close King too; that's reserved for a full teardown you do manually.
- **Won't remove worktrees.** `.worktrees/<lane>/` directories persist. `/kingdom:work` will re-attach to them on next session.
- **state.json is consumed by `/kingdom:work` Step 0.6** (resume scan). If `ready_for_fresh_work=false`, the resume-queue card pre-populates.
