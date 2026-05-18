---
description: Check kingdom prerequisites + auto-patch ~/.claude/settings.json (show diff, ask once per field)
---

Run 6 checks in order. Report ✅/⚠️/❌ for each. At the end, summarise green/yellow/red counts, overall readiness, and detected operating mode.

---

## Check 1 — manaflow/cmux app + required commands

Run:
```bash
ls -d /Applications/cmux.app 2>/dev/null && echo found || echo missing
```

Also check whether `$CMUX_CLAUDE_PID` is set:
```bash
echo "${CMUX_CLAUDE_PID:-unset}"
```

If cmux.app is found, verify the specific commands kingdom uses:
```bash
for CMD in new-workspace new-split tab-action send notify rename-tab identify tree list-panes; do
  if cmux "$CMD" --help >/dev/null 2>&1; then
    echo "  ✅ cmux $CMD"
  else
    echo "  ❌ cmux $CMD MISSING"
  fi
done
```

- ✅ PRIMARY if cmux.app is `found` AND `$CMUX_CLAUDE_PID` is set AND all 9 commands above return ✅ — print exactly:
  ```
  manaflow/cmux.app detected + $CMUX_CLAUDE_PID set + required commands present → MODE: PRIMARY
  ```
- ⚠️ if cmux.app is `found` but `$CMUX_CLAUDE_PID` is unset — print exactly:
  ```
  manaflow/cmux.app is installed but $CMUX_CLAUDE_PID is not set.
  Launch kingdom sessions from inside cmux.app to activate PRIMARY mode.
  ```
- ⚠️ if any of the 9 commands is MISSING — print exactly:
  ```
  Your cmux is too old for kingdom v0.13+. Required commands missing.
  Upgrade: brew upgrade --cask cmux
  Minimum version: 0.64.6 (manaflow/cmux).
  ```
- ❌ if cmux.app not found — print exactly:
  ```
  cmux.app (manaflow-ai/cmux) is NOT installed. PRIMARY mode unavailable.
  Install via Homebrew:
    brew tap manaflow-ai/cmux
    brew install --cask cmux
  Or download the DMG from: https://github.com/manaflow-ai/cmux/releases
  ```

---

## Check 2 — `tmux` installed

Run:
```bash
which tmux
```

Behaviour depends on Check 1 result:

- If cmux.app was found (PRIMARY or ⚠️ above):
  - ✅ if tmux is present — informational: "tmux available (cmux.app's tmux-compat layer handles tmux-protocol calls)"
  - ⚠️ if tmux is absent — informational: "tmux not found, but cmux.app's tmux-compat layer covers the primary path. Install if needed: brew install tmux"
- If cmux.app was NOT found (FALLBACK path):
  - ✅ if tmux is present — print exactly:
    ```
    tmux found → MODE: FALLBACK (tmux + git worktree)
    ```
  - ❌ if not found — print exactly:
    ```
    tmux is REQUIRED for the fallback kingdom path and is not installed.
    Install:
      brew install tmux
    Without tmux and without cmux.app, only HEADLESS mode (claude -p + git worktree) is available.
    ```

---

## Check 3 — `jq` installed

Run:
```bash
which jq
```

- ✅ if a path is returned.
- ❌ if not found — print exactly:
  ```
  jq is REQUIRED by /kingdom:start to read kingdom.json. Install:
    brew install jq
  ```

---

## Check 4 — `gh` CLI installed and authenticated

Run both:
```bash
which gh
gh auth status
```

- ✅ if `which gh` returns a path AND `gh auth status` exits 0.
- ⚠️ if `gh` is missing or `gh auth status` fails — print exactly:
  ```
  gh CLI is missing or not authenticated. It is required by /kingdom:start
  and the Watchman agent for PR babysitting. Install and authenticate:
    brew install gh
    gh auth login
  ```

---

## Check 5 — `git` >= 2.5 (needed for `git worktree`)

Run:
```bash
git --version
```

Parse the version number from the output (e.g. `git version 2.39.3`).

- ✅ if the version is 2.5 or higher — print exactly:
  ```
  git <version> found — git worktree supported ✅
  ```
- ❌ if git is missing or version < 2.5 — print exactly:
  ```
  git >= 2.5 is REQUIRED for git worktree (kingdom lane management). Install or upgrade:
    brew install git
  ```

---

## Check 7 — `<workspace>/.kingdom/<project>/tasks/` writable

For each project that has a `.kingdom/<project>/kingdom.json`, verify that the `tasks/` directory exists or can be created. Run:

```bash
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  PROJ=$(basename "$(dirname "$KJSON")")
  mkdir -p "$PWD/.kingdom/$PROJ/tasks" 2>/dev/null && echo "OK $PROJ" || echo "FAIL $PROJ"
done
```

- ✅ if all projects print `OK` (directory exists or was created successfully).
- ⚠️ if any project prints `FAIL` — filesystem permissions prevent creation. Report the affected project path and stop; do not auto-fix.

Note: this is an informational check — the `tasks/` directory is auto-created by `/kingdom:init <project>` and `/kingdom:start`. This check exists so the doctor can flag permission issues early, before lanes try to write task files.

If no `.kingdom/*/kingdom.json` files exist yet (kingdom not yet initialised), print:

```
No kingdom.json found — tasks/ check skipped (run /kingdom:init first).
```

and mark this check ✅ (not applicable).

---

## Check 6 — `~/.claude/settings.json` has the right keys

Read the file:
```bash
cat ~/.claude/settings.json
```

Check two fields independently:

### Field A — `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

Read current value:
```bash
jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' ~/.claude/settings.json
```

- ✅ if the value equals `"1"`.
- If missing or wrong, show this diff and ask for confirmation before applying:
  ```
  Proposed change to ~/.claude/settings.json:

  + "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }

  Apply? [y/N]
  ```
  If the user confirms, apply via:
  ```bash
  tmp=$(mktemp)
  jq '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
  ```
  Then report ✅ applied. If the user declines, report ⚠️ skipped.

### Field B — `teammateMode`

Read current value:
```bash
jq -r '.teammateMode // empty' ~/.claude/settings.json
```

- ✅ if the value equals `"tmux"`.
- If missing or wrong, show this diff and ask for confirmation before applying:
  ```
  Proposed change to ~/.claude/settings.json:

  + "teammateMode": "tmux"

  Apply? [y/N]
  ```
  If the user confirms, apply via:
  ```bash
  tmp=$(mktemp)
  jq '.teammateMode = "tmux"' ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
  ```
  Then report ✅ applied. If the user declines, report ⚠️ skipped.

**Important:** Every `jq` write must pass through the full existing document. Never overwrite unrelated keys. Use `jq '.<key> = <value>'` (not `--null-input`) so all other content is preserved.

If `~/.claude/settings.json` does not exist, create it with `{}` as the base before applying any patches:
```bash
[ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
```

---

## Check 8 — Orphan audit artifacts (informational)

For each project with a `.kingdom/<project>/kingdom.json`, look for raw artifacts that have no corresponding curated digest — a sign that a lane closer was interrupted or that `/kingdom:update` is due.

ID extraction strips known shard suffixes (`__kimi-p<N>`, `__shard-<N>`, `__pane<N>`) and falls back to `<UTC>` prefix match when the full ID doesn't resolve. This avoids the over-count when many lane-shard raws are covered by a single parent digest at the same UTC + base slug.

```bash
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  PROJ=$(basename "$(dirname "$KJSON")")
  RAW_DIR="$PWD/.kingdom/$PROJ/logs/raw"
  CURATED_DIR="$PWD/.kingdom/$PROJ/logs"
  [ -d "$RAW_DIR" ] || continue
  ORPHANS=0
  for RAW in "$RAW_DIR"/*.md "$RAW_DIR"/*.txt; do
    [ -f "$RAW" ] || continue
    BASE=$(basename "$RAW")
    BASE="${BASE%.md}"
    BASE="${BASE%.txt}"
    # Strip known shard suffixes
    STRIPPED=$(echo "$BASE" | sed -E 's/__(kimi-p[0-9]+|shard-[0-9]+|pane[0-9]+(-[a-z0-9-]+)?)$//')
    # Exact match?
    if [ -f "$CURATED_DIR/$STRIPPED.md" ]; then
      continue
    fi
    # Fallback: UTC prefix match (first YYYY-MM-DDTHHMMZ token)
    UTC=$(echo "$BASE" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{4}Z' | head -1)
    if [ -n "$UTC" ] && ls "$CURATED_DIR/${UTC}__"*.md >/dev/null 2>&1; then
      continue
    fi
    ORPHANS=$((ORPHANS + 1))
  done
  echo "$PROJ: $ORPHANS orphan(s)"
done
```

- ✅ if every project reports `0 orphan(s)`.
- ⚠️ if any project has orphans — print exactly:
  ```
  Found orphan raw artifacts in <project>. Run /kingdom:update <project>
  to backfill curated digests + master_agent.log lines.
  ```

If no `.kingdom/*/kingdom.json` files exist yet, mark this check ✅ (not applicable).

---

## Check 9 — Git state across projects (informational)

For each project with a `.kingdom/<project>/kingdom.json`, report the worktree state — dirty / branch / up-to-date with origin. Informational only; doesn't block. `/kingdom:update` runs this same check with prompts.

```bash
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  PROJ=$(basename "$(dirname "$KJSON")")
  PROJ_DIR="$PWD/$PROJ"
  [ -d "$PROJ_DIR/.git" ] || { echo "$PROJ: not a git repo (skipped)"; continue; }
  (
    cd "$PROJ_DIR" || exit
    DIRTY="clean"
    git diff --quiet && git diff --cached --quiet || DIRTY="DIRTY"
    BRANCH=$(git branch --show-current)
    BASE=$(jq -r '.git.base // "develop"' "$KJSON")
    SYNC=""
    git fetch origin "$BASE" --quiet 2>/dev/null
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse "origin/$BASE" 2>/dev/null)
    [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ] && SYNC=" / drift vs origin/$BASE"
    echo "$PROJ: $DIRTY on $BRANCH$SYNC"
  )
done
```

- ✅ if every project reports `clean on <recognised-branch>` (recognised = base / kingdom / worker-N / co-worker-N / watchman-N).
- ⚠️ if any project is DIRTY or on an unrecognised branch — print exactly:
  ```
  Project(s) with non-pristine git state — /kingdom:update will prompt before running on them
  (or pass --force to skip prompts).
  ```

Mark ✅ (not applicable) if no `.kingdom/*/kingdom.json` files exist yet.

---

## Check 10 — Workspace `.claude/settings.json` permissions (background sub-agents)

Background sub-agents (spawned by `/kingdom:update`'s Lead + specialists, by Workers' fan-outs, etc.) need an explicit `permissions.allow` list in the **workspace-scoped** `.claude/settings.json` (NOT user-global). Without it, every Bash / Edit / Agent call from a background agent prompts indefinitely and fan-outs stall silently.

Real failure mode you'd see: `/kingdom:update` dispatches specialists, then nothing ever completes — sentinels never appear because each sub-agent is stuck on a permission prompt that no one sees.

```bash
WS_SETTINGS="$PWD/.claude/settings.json"

# 1. File exists?
if [ ! -f "$WS_SETTINGS" ]; then
  echo "missing — kingdom workspace needs $WS_SETTINGS"
  STATE=missing
elif [ ! -s "$WS_SETTINGS" ] || ! jq empty "$WS_SETTINGS" 2>/dev/null; then
  echo "empty or invalid JSON — needs the permissions block"
  STATE=invalid
else
  # 2. permissions.allow includes the kingdom-essential tools + path-scoped reads/writes
  REQUIRED='["Bash","Read","Write","Edit","Grep","Glob","Agent","Read(.kingdom/**)","Write(.kingdom/**)","Edit(.kingdom/**)","Read(.worktrees/**)","Write(.worktrees/**)","Edit(.worktrees/**)"]'
  HAS_ALL=$(jq --argjson req "$REQUIRED" '
    if .permissions.allow then ($req - .permissions.allow | length == 0) else false end
  ' "$WS_SETTINGS")
  if [ "$HAS_ALL" = "true" ]; then
    STATE=ok
    echo "✅ permissions.allow contains all kingdom-required entries (tools + .kingdom/** + .worktrees/** path scopes)"
  else
    STATE=incomplete
    echo "⚠️  permissions.allow missing required entries — see proposed patch below"
  fi
fi
```

- ✅ if `STATE=ok`.
- ⚠️ if `STATE=missing` / `invalid` / `incomplete` — show this proposed file content + diff + ask before writing:

  ```json
  {
    "enabledPlugins": {},
    "permissions": {
      "allow": [
        "Bash",
        "Read",
        "Write",
        "Edit",
        "Grep",
        "Glob",
        "Agent",
        "Read(.kingdom/**)",
        "Write(.kingdom/**)",
        "Edit(.kingdom/**)",
        "Read(.worktrees/**)",
        "Write(.worktrees/**)",
        "Edit(.worktrees/**)"
      ]
    }
  }
  ```

  Print exactly:
  ```
  Proposed change to .claude/settings.json (workspace-scoped):

  + permissions.allow = [
      Bash, Read, Write, Edit, Grep, Glob, Agent,
      Read(.kingdom/**), Write(.kingdom/**), Edit(.kingdom/**),
      Read(.worktrees/**), Write(.worktrees/**), Edit(.worktrees/**)
    ]

  Apply? [y/N]
  ```

  > **Why path-scoped reads/writes?** Without them, Claude Code prompts every time a lane reads task files at `.kingdom/<project>/tasks/` or worktree files at `.worktrees/<lane>/`. The prompt blocks the lane until you click into its workspace to approve. Pre-allowing `.kingdom/**` and `.worktrees/**` eliminates the most common prompt source. Watchman's blocked-lane scan (see `watchmans.md`) catches any other prompts that still fire.

  On `y`: merge the permissions into the existing JSON (or write fresh if missing/invalid). Use `jq` to preserve any other keys:

  ```bash
  tmp=$(mktemp)
  [ -f "$WS_SETTINGS" ] || echo '{}' > "$WS_SETTINGS"
  jq '.permissions.allow = (((.permissions.allow // []) + [
    "Bash","Read","Write","Edit","Grep","Glob","Agent",
    "Read(.kingdom/**)","Write(.kingdom/**)","Edit(.kingdom/**)",
    "Read(.worktrees/**)","Write(.worktrees/**)","Edit(.worktrees/**)"
  ]) | unique)' \
    "$WS_SETTINGS" > "$tmp" && mv "$tmp" "$WS_SETTINGS"
  ```

  Then report ✅ applied. On `N`: ⚠️ skipped — warn the user that `/kingdom:update` and `/kingdom:start` will stall on background sub-agent prompts.

**Important scope:** this is the **workspace-local** `.claude/settings.json` (`$PWD/.claude/settings.json`), NOT the user-global `~/.claude/settings.json` (which Check 6 handles). The two are independent — both must be correct.

---

## Final Summary

After all 10 checks (including any patch outcomes for Check 6 + Check 10), print a single summary block.

Count results:
- ✅ = green (met or patched)
- ⚠️ = yellow (optional/skipped)
- ❌ = red (missing critical dependency)

Then print ONE of:

**All green:**
```
Kingdom is ready. Run /kingdom:start to launch your first session.
```

The 3 outcomes are wrapped in the [`doctor-report`](../.kingdom/.setting/cards/doctor-report.md) card (variant-aware):

```bash
CHECK_RESULTS_LIST=$(printf '%s\n' \
  "${CMUX_RESULT}" "${TMUX_RESULT}" "${JQ_RESULT}" "${GH_RESULT}" "${GIT_RESULT}" \
  "${USER_SETTINGS_RESULT}" "${WORKSPACE_SETTINGS_RESULT}" "${TASKS_WRITABLE_RESULT}" \
  "${ORPHAN_AUDIT_RESULT}" "${GIT_STATE_RESULT}")

N_FAILED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^✗')
N_PATCHED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^⚙')

export OS_VERSION SHELL CMUX_VERSION TMUX_VERSION JQ_VERSION GH_VERSION GIT_VERSION \
  N_PROJECTS CHECK_RESULTS_LIST N_FAILED N_PATCHED PATCHED_LIST ACTION_LIST \
  PLURAL=$([ "$N_FAILED" = "1" ] && echo "" || echo "s")

if   [ "$N_FAILED" -eq 0 ] && [ "$N_PATCHED" -eq 0 ]; then
  render_card "doctor-report/all-pass"
elif [ "$N_FAILED" -eq 0 ]; then
  render_card "doctor-report/partial-pass"
else
  render_card "doctor-report/failed"
fi
```

See [`cards/doctor-report.md`](../.kingdom/.setting/cards/doctor-report.md) for the 3 variants + variable list.

After the card, always print the detected mode line:

- If cmux.app found AND `$CMUX_CLAUDE_PID` set:
  ```
  MODE: PRIMARY (manaflow/cmux + git worktree) — full features available
  ```
- If cmux.app NOT found AND tmux found:
  ```
  MODE: FALLBACK (tmux + git worktree) — works but no native notifications / sidebar
  ```
- If neither cmux.app nor tmux found:
  ```
  MODE: HEADLESS (claude -p + git worktree) — no panes, no live UX
  ```

---

## Conventions

- **Idempotent.** Re-running reports ✅ for everything already satisfied. No side effects unless the user confirms a patch.
- **Never auto-install.** Do NOT run `brew install`, `curl | sh`, or any package manager command automatically. Print the command for the user to copy-paste.
- **DO auto-patch `~/.claude/settings.json`** — but only after per-field user confirmation.
- Use plain `bash` + `jq` + `which` / `command -v` for all checks. No external tooling beyond what is being checked.
- Ask each settings.json field confirmation separately so the user can apply one and skip the other.
