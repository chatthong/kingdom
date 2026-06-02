---
description: Archive OLD, closed artifacts out of the hot paths (tasks/, logs/) into tasks/archive/<YYYY-Qn>/ + logs/archive/<YYYY-Qn>/ and rotate a bloated master_agent.log. Keeps a month-long King session fast. Safe from /kingdom:save or a weekly watchman idle duty.
argument-hint: "[project] [--older-than=30d] [--dry-run]"
---

You are pruning a kingdom project's runtime artifacts. Over a month, `tasks/` and `logs/` grow unbounded — closed task files, raw worker dumps, curated digests, watch heartbeats, and an ever-growing `master_agent.log` all pile up in the SAME directories the resume scan and master read tier walk every session. Nothing else archives them. This command moves the OLD, no-longer-needed ones out of the hot paths so `/kingdom:work` stays fast.

**It never touches anything in-flight, never touches config, never touches the project's own git tree.** It only relocates closed/aged artifacts into quarter-stamped `archive/` subfolders (and rotates the log). Default asks for confirmation showing counts; `--dry-run` lists what WOULD move and stops.

Safe to run standalone, from the tail of `/kingdom:save`, or as a weekly watchman idle duty.

## Step 0 — Parse arguments + resolve project

From `$ARGUMENTS`, extract:

- `project` — the first positional token. If absent, default to `basename "$PWD"`.
- `--older-than=<N>d` — the age window (`30d` / `7d` / `90d`). Default `30d`.
- `--dry-run` — list-only, move nothing.

```bash
# Defaults
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: split $ARGUMENTS in the for-loop (else flags are ignored)
project=""
OLDER_THAN_DAYS=30
DRY_RUN=0

for tok in $ARGUMENTS; do
  case "$tok" in
    --dry-run)        DRY_RUN=1 ;;
    --older-than=*)   OLDER_THAN_DAYS=$(echo "${tok#--older-than=}" | tr -dc '0-9') ;;
    --*)              echo "Ignoring unknown flag: $tok" ;;
    *)                [ -z "$project" ] && project="$tok" ;;
  esac
done
[ -z "$project" ] && project="$(basename "$PWD")"
[ -z "$OLDER_THAN_DAYS" ] && OLDER_THAN_DAYS=30

echo "Archive plan: project=${project}  older-than=${OLDER_THAN_DAYS}d  dry-run=${DRY_RUN}"
```

Verify the project is initialised:

```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom:init ${project}` was never run, and stop.

Resolve paths + the destination quarter stamp (`YYYY-Qn`, from the CURRENT date — that's where this run files its sweep):

```bash
KROOT="$PWD/.kingdom/${project}"
TASKS_DIR="$KROOT/tasks"
LOGS="$KROOT/logs"
DONE_DIR="$LOGS/done"
RAW_DIR="$LOGS/raw"
WATCH_DIR="$LOGS/watch"
MASTER_LOG="$LOGS/master_agent.log"

# Quarter stamp: 2026-Q2 etc. BSD date has no %q, so compute the quarter from the month.
YEAR=$(date -u +%Y)
MONTH=$(date -u +%m)
QTR=$(( (10#$MONTH - 1) / 3 + 1 ))
QSTAMP="${YEAR}-Q${QTR}"

TASKS_ARCHIVE="$TASKS_DIR/archive/$QSTAMP"
LOGS_ARCHIVE="$LOGS/archive/$QSTAMP"

echo "Quarter bucket: $QSTAMP"
```

## Step 1 — Identify CLOSED, aged task files

A task file is archivable only when BOTH hold:

- it is **closed** — has a matching sentinel flag in `logs/done/`, OR its status is `done`/`cancelled`
- it is **older than the window** (`find -mtime`)

In-flight task files (no sentinel AND status not done/cancelled) are NEVER archived — they're exactly what `/kingdom:work`'s resume scan needs.

```bash
TASK_MOVES=""   # newline-separated absolute paths queued to move

if [ -d "$TASKS_DIR" ]; then
  # -mtime +N: strictly older than N*24h. -maxdepth 1 so we never recurse into archive/.
  while IFS= read -r tf; do
    [ -z "$tf" ] && continue
    base=$(basename "$tf" .md)
    lane=$(echo "$base" | sed 's/^[0-9-]*T[0-9]*Z__//;s/__.*//')
    task_id=$(echo "$base" | sed 's/.*__//')

    closed=0
    # Sentinel present?
    ls "$DONE_DIR"/*"__${lane}__${task_id}.flag" >/dev/null 2>&1 && closed=1
    # Or terminal status checked off in the file
    if [ "$closed" = "0" ]; then
      status=$(grep -E '^- \[x\] (done|cancelled)' "$tf" | tail -1 \
        | grep -oE '(done|cancelled)' 2>/dev/null)
      [ -n "$status" ] && closed=1
    fi

    [ "$closed" = "1" ] && TASK_MOVES="${TASK_MOVES}${tf}"$'\n'
  done < <(find "$TASKS_DIR" -maxdepth 1 -type f -name '*.md' -mtime +"$OLDER_THAN_DAYS" 2>/dev/null)
fi

TASK_COUNT=$(printf '%s' "$TASK_MOVES" | grep -c . || true)
echo "Closed + aged task files: $TASK_COUNT"
```

## Step 2 — Identify aged logs (raw + curated) and watch heartbeats

```bash
RAW_MOVES=""
CURATED_MOVES=""
WATCH_DELETES=""

# logs/raw/* — worker raw dumps, never read by the master directly (Tier-3 banned).
if [ -d "$RAW_DIR" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && RAW_MOVES="${RAW_MOVES}${f}"$'\n'
  done < <(find "$RAW_DIR" -maxdepth 1 -type f -mtime +"$OLDER_THAN_DAYS" 2>/dev/null)
fi

# Curated digests live directly in logs/ as <UTC>__*.md (one per task). Match that shape
# only — never sweep master_agent.log (handled in Step 3) or non-curated stray files.
if [ -d "$LOGS" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && CURATED_MOVES="${CURATED_MOVES}${f}"$'\n'
  done < <(find "$LOGS" -maxdepth 1 -type f -name '*Z__*.md' -mtime +"$OLDER_THAN_DAYS" 2>/dev/null)
fi

# logs/watch/WATCH_* — pure heartbeat noise. Delete rather than archive (not worth keeping).
if [ -d "$WATCH_DIR" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && WATCH_DELETES="${WATCH_DELETES}${f}"$'\n'
  done < <(find "$WATCH_DIR" -maxdepth 1 -type f -name 'WATCH_*' -mtime +"$OLDER_THAN_DAYS" 2>/dev/null)
fi

RAW_COUNT=$(printf '%s' "$RAW_MOVES" | grep -c . || true)
CURATED_COUNT=$(printf '%s' "$CURATED_MOVES" | grep -c . || true)
WATCH_COUNT=$(printf '%s' "$WATCH_DELETES" | grep -c . || true)
echo "Aged raw outputs:    $RAW_COUNT"
echo "Aged curated digests: $CURATED_COUNT"
echo "Watch heartbeats to delete: $WATCH_COUNT"
```

## Step 3 — Decide whether master_agent.log needs rotation

`master_agent.log` is append-only and the master's Tier-1 read every session. If it exceeds the line threshold (`MASTER_LOG_MAX`, default 5000), rotate: copy the whole thing to `logs/archive/master_agent.log.<UTC>` and keep only the last ~1000 lines live. Below the threshold, leave it alone.

```bash
MASTER_LOG_MAX=5000
MASTER_LOG_KEEP=1000
ROTATE_LOG=0
MASTER_LINES=0

if [ -f "$MASTER_LOG" ]; then
  MASTER_LINES=$(wc -l < "$MASTER_LOG" | tr -d ' ')
  [ "$MASTER_LINES" -gt "$MASTER_LOG_MAX" ] && ROTATE_LOG=1
fi
echo "master_agent.log: ${MASTER_LINES} lines (threshold ${MASTER_LOG_MAX}) → rotate=${ROTATE_LOG}"
```

## Step 4 — Show the plan (always) + confirm (unless --dry-run was the request)

Print the full plan so the user (or the watchman log) sees exactly what moves:

```bash
echo "──────────────────────────────────────────────"
echo "  /kingdom:archive — ${project}  (older than ${OLDER_THAN_DAYS}d)"
echo "──────────────────────────────────────────────"
echo "  → tasks/archive/${QSTAMP}/   ${TASK_COUNT} closed task files"
echo "  → logs/archive/${QSTAMP}/    ${RAW_COUNT} raw + ${CURATED_COUNT} curated"
echo "  ✗ delete                     ${WATCH_COUNT} watch heartbeats"
if [ "$ROTATE_LOG" = "1" ]; then
  echo "  ↻ rotate master_agent.log    ${MASTER_LINES} lines → keep last ${MASTER_LOG_KEEP}"
else
  echo "  · master_agent.log           ${MASTER_LINES} lines (no rotation)"
fi
echo "──────────────────────────────────────────────"
echo "  NEVER touched: in-flight task files, state.json, kingdom.json,"
echo "  watchman_state.json, king-inbox/, the project's own git tree."
echo "──────────────────────────────────────────────"
```

**If `--dry-run` (`DRY_RUN=1`): stop here.** Report "Dry run — nothing moved." and end.

Otherwise ask:

> Move the artifacts above out of the hot paths? Nothing is deleted except `${WATCH_COUNT}` watch heartbeats; everything else is relocated and recoverable. (yes/no)

Wait for an explicit `yes`. On anything else, stop without moving.

## Step 5 — Execute the sweep

```bash
mkdir -p "$TASKS_ARCHIVE" "$LOGS_ARCHIVE"

moved_tasks=0
moved_raw=0
moved_curated=0
deleted_watch=0

# Task files → tasks/archive/<YYYY-Qn>/
printf '%s\n' "$TASK_MOVES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  mv "$f" "$TASKS_ARCHIVE/" && echo "  archived task: $(basename "$f")"
done
moved_tasks="$TASK_COUNT"

# Raw outputs → logs/archive/<YYYY-Qn>/
printf '%s\n' "$RAW_MOVES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  mv "$f" "$LOGS_ARCHIVE/" && echo "  archived raw: $(basename "$f")"
done
moved_raw="$RAW_COUNT"

# Curated digests → logs/archive/<YYYY-Qn>/
printf '%s\n' "$CURATED_MOVES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  mv "$f" "$LOGS_ARCHIVE/" && echo "  archived curated: $(basename "$f")"
done
moved_curated="$CURATED_COUNT"

# Watch heartbeats → deleted
printf '%s\n' "$WATCH_DELETES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  rm -f "$f" && echo "  deleted watch: $(basename "$f")"
done
deleted_watch="$WATCH_COUNT"
```

Rotate the log if Step 3 flagged it. Backup-then-act: copy the full log aside FIRST, then truncate to the live tail — the King's recent context survives, the cold history is recoverable:

```bash
if [ "$ROTATE_LOG" = "1" ]; then
  UTC=$(date -u +%Y-%m-%dT%H%MZ)
  cp "$MASTER_LOG" "$LOGS_ARCHIVE/master_agent.log.$UTC"
  tmp=$(mktemp)
  tail -n "$MASTER_LOG_KEEP" "$MASTER_LOG" > "$tmp" && mv "$tmp" "$MASTER_LOG"
  echo "  rotated master_agent.log → archive/${QSTAMP}/master_agent.log.$UTC (kept last ${MASTER_LOG_KEEP})"
fi
```

## Step 6 — Append a log line + render the completion card

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
echo "[$UTC] 👑 kingdom:archive · ${project} · tasks=${TASK_COUNT} raw=${RAW_COUNT} curated=${CURATED_COUNT} watch_deleted=${WATCH_COUNT} log_rotated=${ROTATE_LOG} · window=${OLDER_THAN_DAYS}d → ${QSTAMP}" \
  >> "$MASTER_LOG"
```

Render an inline completion box (consistent with the card convention — a box-drawn body inside a `[!NOTE]` GitHub alert; no new card file needed):

```markdown
> [!NOTE]
> ```
> ╭─ 🧹 Archived · ${project} ──────────────────────────────╮
> │  window: older than ${OLDER_THAN_DAYS}d  →  bucket ${QSTAMP}
> │                                                         │
> │  Tasks archived:    ${TASK_COUNT}
> │  Raw archived:      ${RAW_COUNT}
> │  Curated archived:  ${CURATED_COUNT}
> │  Watch deleted:     ${WATCH_COUNT}
> │  Log rotated:       ${ROTATE_LOG}  (${MASTER_LINES} lines)
> │                                                         │
> │  Hot paths trimmed. /kingdom:work resume scan stays fast.
> ╰─────────────────────────────────────────────────────────╯
> ```
```

Substitute the real counts when rendering (the King fills the `${…}` placeholders from the variables above).

## Conventions

- **Move, don't delete (except watch heartbeats).** Archived task files and logs stay recoverable under `archive/<YYYY-Qn>/`; only `logs/watch/WATCH_*` is removed (pure heartbeat noise).
- **`--dry-run` first when unsure.** It prints the identical plan and moves nothing.
- **Idempotent.** Re-running finds nothing new to move (already-archived files live under `archive/`, which the `-maxdepth 1` scans skip). Safe to run twice.
- **NEVER touches:** in-flight task files (no sentinel + status not done/cancelled), `state.json`, `kingdom.json`, `watchman_state.json`, `king-inbox/`, or anything under the project's own git tree. This command only ever writes inside `.kingdom/<project>/tasks/archive/` and `.kingdom/<project>/logs/archive/`, deletes watch heartbeats, and truncates `master_agent.log` on rotation.
- **Where to run it from:** standalone (`/kingdom:archive <project>`), at the tail of `/kingdom:save` for a clean checkpoint, or as a weekly watchman idle duty so a month-long King session never accumulates a slow hot dir.
- **macOS BSD-compatible.** Uses `find -mtime +N` (whole-day granularity) and computes the quarter stamp by hand (BSD `date` has no `%q`). No GNU-only flags.
