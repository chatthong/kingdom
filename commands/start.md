---
description: Spawn the kingdom for a project — reads .kingdom/<project>/kingdom.json, creates lane worktrees via git worktree add, then dispatches per MODE (primary/fallback/headless)
argument-hint: <project> [workers=N] [co-workers=M] [watchman=K]
---

Parse `$ARGUMENTS` before doing anything:

- First positional token = `<project>` (required). Must match a real subdirectory under `$PWD`.
- Any `workers=N`, `co-workers=M`, `watchman=K` tokens override the values from `kingdom.json`.

If `<project>` is missing, stop and ask: "Which project? (subdirectory name under $PWD)".

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

5. Apply CLI overrides if given in `$ARGUMENTS` (e.g., `workers=2` → `WORKERS=2`).

6. Validate: `WORKERS + COWORKERS + WATCHMEN <= SANITY_CAP`.
   - If exceeded: "Total lane count ($((WORKERS+COWORKERS+WATCHMEN))) exceeds sanityCap ($SANITY_CAP). Reduce counts or raise sanityCap in kingdom.json."
   - Stop.

7. Auto-detect outer host mode:

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

8. Print the resolved plan and ask for confirmation before proceeding:

```
Resolved plan for "$PROJECT":
  mode:         $MODE
  base branch:  $BASE
  workers:      $WORKERS
  co-workers:   $COWORKERS
  watchmen:     $WATCHMEN
  task source:  $TASK_SOURCE
  logs dir:     $WS/.kingdom/$PROJECT/logs/

Proceed? (yes / no / adjust counts)
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

Show the planned command for the detected $MODE and ask for confirmation before running.

### MODE=primary (manaflow/cmux)

Pre-req check: verify `~/.claude/settings.json` contains:

```json
"teammateMode": "tmux"
```

and environment:

```
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

- If either is missing: "Pre-req not met — run `/kingdom:doctor` to configure, then retry Phase 5."
  Stop here; do not call `cmux claude-teams`.

On approval:

```bash
cmux claude-teams
# Dispatches prompts per lane via:
# cmux send --lane "worker-$I" -l "$PROMPT"
```

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

# Dispatch prompts inside each pane:
tmux send-keys -t "$SESSION:$WIN.<PANE>" -l "$PROMPT"
tmux send-keys -t "$SESSION:$WIN.<PANE>" Enter
```

### MODE=headless (no panes)

Run each lane as a blocking subprocess; no persistent splits:

```bash
( cd "$PROJ/.worktrees/worker-1" && claude -p "$PROMPT" )
# Repeat per lane, sequentially or via background jobs as needed.
```

The artifact protocol (4-step closer, sentinel flag, log writes) is identical across all three modes.

---

## Phase 6 — Pin each teammate to its lane + name tabs (MODE-branched)

### MODE=primary (manaflow/cmux)

Discover the workspace layout:

```bash
WS_ID=$(cmux current-workspace --json | jq -r .id)
cmux list-panes --workspace "$WS_ID" --json
```

Print the raw JSON so the user can verify placement. Then, for each lane, run:

```bash
# Example for worker-1:
HANDLE=$(cmux list-panes --workspace "$WS_ID" --json \
  | jq -r '.[] | select(.title=="worker-1") | .id')
cmux pin-pane --pane "$HANDLE" --worktree "$PROJ/.worktrees/worker-1"
cmux rename-tab --pane "$HANDLE" "👷 worker-1"
```

Repeat for every worker, co-worker, and watchman lane. Tab title convention (see `.kingdom/.setting/index.md` → "Role emoji convention"):

```text
👑 King           — primary checkout, kingdom branch
👷 worker-N       — .worktrees/worker-N
🧑‍💼 co-worker-N   — .worktrees/co-worker-N
🕵️ watchman-N     — .worktrees/watchman-N
```

Note: if `cmux claude-teams` places panes differently than expected, print the discovery
commands below and wait for the user to verify before continuing:

```bash
cmux tree --json
cmux list-panes --workspace "$WS_ID" --json | jq '[.[] | {id, title, worktree}]'
```

This phase may need manual adjustment on the first run of a new `cmux claude-teams` layout.

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
