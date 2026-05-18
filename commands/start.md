---
description: Spawn the kingdom for a project — reads .kingdom/<project>/kingdom.json, creates lane worktrees via git worktree add, then dispatches per MODE (primary/fallback/headless)
argument-hint: <project>
---

Parse `$ARGUMENTS`: first positional token = `<project>` (required). Must match a real subdirectory under `$PWD`.

If `<project>` is missing, stop and ask: "Which project? (subdirectory name under $PWD)".

**Shape is read from `kingdom.json` — no override args.** To change worker/co-worker/watchman counts, either edit `.kingdom/<project>/kingdom.json` directly or re-run `/kingdom:init <project> workers=N co-workers=M watchman=K` (which preserves your `gate.*` customisations? — actually it asks before overwriting).

---

## Phase 1 — Read config + validate

Run these checks in order. Stop at the first failure and report clearly.

```bash
WS="$PWD"
PROJECT="<project>"          # substituted from $ARGUMENTS
PROJ="$WS/$PROJECT"
KJSON="$WS/.kingdom/$PROJECT/kingdom.json"
SETTING="$WS/.kingdom/.setting/index.md"
```

1. Verify `$SETTING` exists.
   - If not: "`.kingdom/.setting/index.md` not found — run `/kingdom:init` first, then retry."
   - Stop.

2. Verify `$PROJ` exists as a directory.
   - If not: "`$PROJECT` is not a subdirectory of `$PWD`."
   - Stop.

3. Verify `$KJSON` exists.
   - If not: "`.kingdom/$PROJECT/kingdom.json` not found — run `/kingdom:init $PROJECT` first, then retry."
   - Stop.

4. Read shape + git config via `jq`:

```bash
WORKERS=$(jq -r '.shape.workers'         "$KJSON" 2>/dev/null || echo 3)
COWORKERS=$(jq -r '.shape."co-workers"' "$KJSON" 2>/dev/null || echo 1)
WATCHMEN=$(jq -r '.shape.watchman'      "$KJSON" 2>/dev/null || echo 1)
SANITY_CAP=$(jq -r '.shape.sanityCap // 10' "$KJSON")
BASE=$(jq -r '.git.base // "develop"'   "$KJSON")
TASK_SOURCE=$(jq -r '.taskSource // "(not set)"' "$KJSON")
```

5. Validate: `WORKERS + COWORKERS + WATCHMEN <= SANITY_CAP`.
   - If exceeded: "Total lane count ($((WORKERS+COWORKERS+WATCHMEN))) exceeds sanityCap ($SANITY_CAP). Reduce counts or raise sanityCap in kingdom.json."
   - Stop.

6. Auto-detect outer host mode:

```bash
# Auto-detect outer host mode
if [ -n "$CMUX_CLAUDE_PID" ] && [ -d "/Applications/cmux.app" ]; then
  MODE=primary       # manaflow/cmux + native splits
elif command -v tmux >/dev/null 2>&1; then
  MODE=fallback      # raw tmux + git worktree
else
  MODE=headless      # claude -p, no panes
fi
echo "Kingdom mode: $MODE"
```

7. Print the resolved plan and ask for confirmation before proceeding:

```
Resolved plan for "$PROJECT":
  mode:         $MODE
  base branch:  $BASE
  workers:      $WORKERS
  co-workers:   $COWORKERS
  watchmen:     $WATCHMEN
  task source:  $TASK_SOURCE
  logs dir:     $WS/.kingdom/$PROJECT/logs/

Proceed? (yes / no)
```

Wait for explicit approval before continuing.

---

## Phase 2 — Verify project git state

```bash
cd "$PROJ"
git fetch origin
git status
```

- If `git status` shows any modified/untracked files: STOP. Report the dirty files. Ask:
  "Working tree is dirty. Stash (`git stash`), commit, or abort?"
  Wait for the user's answer. Do not proceed until the tree is clean.

- Once clean:

```bash
git checkout kingdom 2>/dev/null || git checkout -b kingdom
git merge --no-edit "origin/$BASE"
```

- If the merge produces conflicts: STOP. Report the conflicting files. Do not auto-resolve.

---

## Phase 3 — Ensure dirs + .gitignore entry

```bash
LOGS="$WS/.kingdom/$PROJECT/logs"
mkdir -p "$LOGS/claims" "$LOGS/done" "$LOGS/raw"
mkdir -p "$WS/.kingdom/$PROJECT/tasks"   # task files (per-task audit trail)

grep -q "^\.worktrees/" "$PROJ/.gitignore" 2>/dev/null \
  || echo ".worktrees/" >> "$PROJ/.gitignore"
```

Print: "Log dirs and tasks/ ready. `.worktrees/` entry present in `.gitignore`."

---

## Phase 4 — Create lane worktrees per shape

Show what will be run, then execute:

```bash
cd "$PROJ"

for I in $(seq 1 "$WORKERS"); do
  git worktree add -b "worker-$I" "$PROJ/.worktrees/worker-$I" "origin/$BASE" 2>/dev/null \
    || cd "$PROJ/.worktrees/worker-$I"
done

for I in $(seq 1 "$COWORKERS"); do
  git worktree add -b "co-worker-$I" "$PROJ/.worktrees/co-worker-$I" "origin/$BASE" 2>/dev/null \
    || cd "$PROJ/.worktrees/co-worker-$I"
done

for I in $(seq 1 "$WATCHMEN"); do
  git worktree add -b "watchman-$I" "$PROJ/.worktrees/watchman-$I" "origin/$BASE" 2>/dev/null \
    || cd "$PROJ/.worktrees/watchman-$I"
done
```

Idempotent: `git worktree add` fails silently if the worktree already exists; the `|| cd` branch lands in the existing worktree so subsequent pane setup steps have the right cwd.

---

## Phase 5 — Spawn the team (MODE-branched)

Three-tier hierarchy on cmux.app:

```text
🏢 Workspace per master (King · workers · co-workers · watchman)
   ├── 📑 Tab — visible sub-agent spawns (auto-close on sentinel)
   └── 🪟 Split — predefined dual-view (watchman top: claude, bottom: gh pr watch)
```

Default sub-agent spawn = `Agent(...)` headless (cheaper, no UI noise). Override to **Tab** only when the user wants to watch the sub-agent work. Override controlled by `kingdom.json.cmux.subAgentSpawnDefault` and per-task `--visible` flag in dispatch.

Show the planned commands for the detected $MODE and ask for confirmation before running.

### MODE=primary (manaflow/cmux) — workspace-per-master

Pre-req checks:

1. `~/.claude/settings.json` has `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` and `teammateMode = "tmux"` (Doctor Check 6 handles this).
2. `cmux new-workspace --help` returns OK (Doctor Check 1 verifies).
3. `$CMUX_WORKSPACE_ID` is set (you're inside cmux.app — that's the King's workspace).

If any pre-req fails: "Pre-req not met — run `/kingdom:doctor` to configure, then retry Phase 5." Stop.

On approval, spawn each master as its own workspace:

```bash
KING_WS="${CMUX_WORKSPACE_ID:-workspace:1}"
declare -A WORKER_WS COWORKER_WS WATCHMAN_WS

# Rename the King's own workspace — it's just "Claude Code" by default
cmux tab-action --action rename \
  --workspace "$KING_WS" \
  --title "👑 King · $PROJECT" 2>/dev/null

# Pin the King's workspace so it stays at top of sidebar (per cmux.json config)
PIN_KING=$(jq -r '.cmux.pinKingWorkspace // true' "$KJSON")
[ "$PIN_KING" = "true" ] && cmux tab-action --action pin --workspace "$KING_WS" 2>/dev/null

spawn_master_workspace () {
  local label="$1" path="$2"
  # Returns "OK workspace:N" — capture the ref
  cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --command "claude" \
    --focus false \
    | awk '/workspace:/ {print $2}'
}

# Spawn workers
for I in $(seq 1 "$WORKERS"); do
  WORKER_WS["$I"]=$(spawn_master_workspace "👷 worker-$I" "$PROJ/.worktrees/worker-$I")
done

# Spawn co-workers
for I in $(seq 1 "$COWORKERS"); do
  COWORKER_WS["$I"]=$(spawn_master_workspace "🧑‍💼 co-worker-$I" "$PROJ/.worktrees/co-worker-$I")
done

# Spawn watchmen — with optional dual-view split layout from kingdom.json
WATCHMAN_LAYOUT=$(jq -c '.cmux.watchmanLayout // null' "$KJSON")
for I in $(seq 1 "$WATCHMEN"); do
  if [ "$WATCHMAN_LAYOUT" != "null" ]; then
    # Build inline layout JSON from config
    TOP_CMD=$(jq -r '.cmux.watchmanLayout.topCommand // "claude"' "$KJSON")
    BOT_CMD=$(jq -r '.cmux.watchmanLayout.bottomCommand // "gh pr list --watch --interval 30"' "$KJSON")
    DIR=$(jq -r '.cmux.watchmanLayout.direction // "vertical"' "$KJSON")
    SPLIT=$(jq -r '.cmux.watchmanLayout.split // 0.6' "$KJSON")
    LAYOUT_JSON=$(jq -n --arg t "$TOP_CMD" --arg b "$BOT_CMD" --arg d "$DIR" --argjson s "$SPLIT" '
      {direction: $d, split: $s, children: [
        {pane: {surfaces: [{type: "terminal", command: $t}]}},
        {pane: {surfaces: [{type: "terminal", command: $b}]}}
      ]}')
    WATCHMAN_WS["$I"]=$(cmux new-workspace \
      --name "🕵️ watchman-$I" \
      --description "Kingdom monitor · $(date -u +%Y-%m-%dT%H%MZ)" \
      --cwd "$PROJ/.worktrees/watchman-$I" \
      --layout "$LAYOUT_JSON" \
      --focus false \
      | awk '/workspace:/ {print $2}')
  else
    WATCHMAN_WS["$I"]=$(spawn_master_workspace "🕵️ watchman-$I" "$PROJ/.worktrees/watchman-$I")
  fi
done

# Save the workspace ref map to logs/ for King + watchman to use in dispatch
{
  echo "# Workspace refs — populated by /kingdom:start at $(date -u +%Y-%m-%dT%H%MZ)"
  echo "KING_WS=$KING_WS"
  for I in $(seq 1 "$WORKERS"); do echo "WORKER_WS_$I=${WORKER_WS[$I]}"; done
  for I in $(seq 1 "$COWORKERS"); do echo "COWORKER_WS_$I=${COWORKER_WS[$I]}"; done
  for I in $(seq 1 "$WATCHMEN"); do echo "WATCHMAN_WS_$I=${WATCHMAN_WS[$I]}"; done
} > "$LOGS/workspace-refs.env"
```

The `workspace-refs.env` file lets the King + watchman dispatch via stable refs across the session (and on resume — `/kingdom:start` re-reads it instead of re-spawning).

### MODE=fallback (raw tmux)

```bash
SESSION=kingdom
WIN=1          # pane-base-index 1

tmux has-session -t "$SESSION" 2>/dev/null \
  || tmux new-session -d -s "$SESSION" -c "$PROJ"

# Create one split per lane:
for I in $(seq 1 "$WORKERS"); do
  tmux split-window -t "$SESSION:$WIN" -h -c "$PROJ/.worktrees/worker-$I"
done
for I in $(seq 1 "$COWORKERS"); do
  tmux split-window -t "$SESSION:$WIN" -h -c "$PROJ/.worktrees/co-worker-$I"
done
for I in $(seq 1 "$WATCHMEN"); do
  tmux split-window -t "$SESSION:$WIN" -h -c "$PROJ/.worktrees/watchman-$I"
done
tmux select-layout -t "$SESSION:$WIN" main-vertical

# Set pane titles with role emojis
tmux set -t "$SESSION" -g pane-border-status top
tmux select-pane -t "$SESSION:$WIN.1" -T "👑 King"
# Loop the rest: select-pane -T "👷 worker-$I" / "🧑‍💼 co-worker-$I" / "🕵️ watchman-$I"

# Dispatch prompts inside each pane:
tmux send-keys -t "$SESSION:$WIN.<PANE>" -l "$PROMPT"
tmux send-keys -t "$SESSION:$WIN.<PANE>" Enter
```

### MODE=headless (no panes)

Run each lane as a blocking subprocess; no persistent panes/workspaces:

```bash
( cd "$PROJ/.worktrees/worker-1" && claude -p "$PROMPT" )
# Repeat per lane, sequentially or via background jobs as needed.
```

The artifact protocol (4-step closer, sentinel flag, log writes) is identical across all three modes. The hierarchy (workspace → tab → split) only manifests in PRIMARY mode; fallback uses tmux panes, headless uses no UI at all.

---

## Phase 6 — Verify the layout (MODE-branched)

### MODE=primary (manaflow/cmux)

No pinning step needed — `cmux new-workspace --name --cwd --command` in Phase 5 already labels, sets cwd, and launches Claude in one call.

Verify the resulting layout:

```bash
cmux tree --all 2>&1 | grep -E 'workspace|surface' | head -30
cat "$LOGS/workspace-refs.env"
```

Expected: one workspace per master, each with a Claude session running in its worktree. Sidebar shows:

```text
👑 King              — workspace:1 (or current $CMUX_WORKSPACE_ID, pinned at top)
👷 worker-1          — workspace:N
👷 worker-2          — workspace:N+1
...
🧑‍💼 co-worker-1     — workspace:N+M
🕵️ watchman-1        — workspace:N+M+1   (vertical split if watchmanLayout set)
```

If any workspace is missing or its Claude session didn't auto-launch, print the recovery command and ask:

```bash
# Missing example:
# Recovery (manual): cmux send --workspace <missing-ref> -- "claude" && \
#                    cmux send --workspace <missing-ref> Enter
```

The discovery commands for debugging:

```bash
cmux tree --all
cmux list-panes --workspace <ref> --json | jq '[.panes[] | {ref, surface_refs, focused}]'
cmux identify --json
```

### MODE=fallback (raw tmux)

Panes are already pinned by cwd from the `tmux split-window -c` calls in Phase 5. Pane titles are set in Phase 5 too. No further setup needed — each pane's cwd is its worktree.

### MODE=headless

No panes/workspaces to verify. Skip this phase.

### MODE=fallback (raw tmux)

Panes are already pinned by cwd from the `tmux split-window -c` calls in Phase 5.
Rename each window + set pane titles with the role emoji convention:

```bash
tmux rename-window -t "$SESSION:$WIN" "kingdom-$PROJECT"
tmux set -t "$SESSION" -g pane-border-status top

# Set pane titles per role (pane indices depend on split order from Phase 5):
tmux select-pane -t "$SESSION:$WIN.1" -T "👑 King"
# For each lane pane, e.g.:
#   tmux select-pane -t "$SESSION:$WIN.<idx>" -T "👷 worker-1"
#   tmux select-pane -t "$SESSION:$WIN.<idx>" -T "🧑‍💼 co-worker-1"
#   tmux select-pane -t "$SESSION:$WIN.<idx>" -T "🕵️ watchman-1"
```

No further pinning needed — each pane's cwd is its worktree. Emoji prefixes follow `.kingdom/.setting/index.md` → "Role emoji convention".

### MODE=headless

No panes to pin. Skip this phase.

---

## Phase 7 — Report

```
Kingdom up for <project>:

  branch:     kingdom (merged from origin/$BASE)
  workers:    worker-1 … worker-$WORKERS
  co-workers: co-worker-1 … co-worker-$COWORKERS
  watchmen:   watchman-1 … watchman-$WATCHMEN

  Logs:       $WS/.kingdom/$PROJECT/logs/
  Config:     $WS/.kingdom/$PROJECT/kingdom.json
  Task source: $TASK_SOURCE

Next steps:
- Tell the King what to work on, e.g.:
    "worker-1: claim and start BE-P0-CICD.1"
- Or ask the King to plan the session:
    "Survey the task source and distribute across workers"
- For Ter-paired UI work:
    "Pair on co-worker-1"
- The Watchman monitors develop/PR status — check sidebar for badges.

Useful log commands:
  tail -n 20 $WS/.kingdom/$PROJECT/logs/master_agent.log
  ls -1t $WS/.kingdom/$PROJECT/logs/*.md | head -10
```

---

## Teardown — removing a lane

To remove a lane (e.g., worker-2) cleanly:

```bash
git worktree remove "$PROJ/.worktrees/worker-2" --force
git branch -D "worker-2" 2>/dev/null || true
```

Repeat per lane name as needed. The `--force` flag handles unclean working trees inside the worktree.

---

## Conventions

- **Idempotent.** Re-running on an existing kingdom resumes rather than recreates. `git worktree add` exits non-zero if the worktree exists; the `|| cd` fallback lands in the existing worktree. No lane is ever double-created.
- **Show before act.** Print each planned side effect (git checkout, worktree creation, claude-teams spawn) and wait for confirmation.
- **Config is authoritative.** `kingdom.json` owns the shape; CLI args are overrides only. Never hard-code lane counts.
- **Tier read discipline.** King reads only Tier 1 (`master_agent.log`) by default; Tier 2 (`<ID>.md`, limit=15) on demand; Tier 3 (`raw/*`) is banned.
- **Reference docs.** For any detail not directly covered here, read:
  - `${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/kings.md` — King role, dispatching (MODE-branched cmux/tmux/headless), pre-commit gate, push approval gate
  - `${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/workers.md` — 4-step closer artifact protocol
  - `${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/git.md` — branch model
  - `${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/index.md` — entry-point overview + session-start detection logic
