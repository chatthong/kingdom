---
description: Prerequisite checks for the kingdom — cmux/tmux/jq/gh/git, settings.json patches. Run once after install or upgrade. (Renamed from /kingdom:doctor in v0.29.0.)
argument-hint:
---

You are running the kingdom's prerequisite checks. Run 8 checks in order. Report a checkmark, warning, or fail marker for each. At the end, render the `doctor-report` card (3 variants: all-pass / partial-pass / failed) and print the detected operating mode.

Idempotent — re-running reports checkmark for everything already satisfied. No side effects unless the user confirms a patch.

**Never auto-install.** Do NOT run `brew install`, `curl | sh`, or any package manager command automatically. Print the command for the user to copy-paste.

---

## Check 1 — manaflow/cmux app + required commands

Run:

```bash
ls -d /Applications/cmux.app 2>/dev/null && echo found || echo missing
echo "${CMUX_CLAUDE_PID:-unset}"
```

If cmux.app is found, verify the specific commands kingdom uses:

```bash
for CMD in new-workspace new-split tab-action send notify rename-tab identify tree \
           list-panes workspace-action close-workspace; do
  if cmux "$CMD" --help >/dev/null 2>&1; then
    echo "  cmux $CMD OK"
  else
    echo "  cmux $CMD MISSING"
  fi
done
```

Results:

- All commands present AND `$CMUX_CLAUDE_PID` set AND cmux.app found → MODE: PRIMARY. Print:
  ```
  manaflow/cmux.app detected + $CMUX_CLAUDE_PID set + required commands present → MODE: PRIMARY
  ```
- cmux.app found but `$CMUX_CLAUDE_PID` unset → print:
  ```
  manaflow/cmux.app is installed but $CMUX_CLAUDE_PID is not set.
  Launch kingdom sessions from inside cmux.app to activate PRIMARY mode.
  ```
- Any command MISSING → print:
  ```
  Your cmux is too old for kingdom v0.13+. Required commands missing.
  Upgrade: brew upgrade --cask cmux
  Minimum version: 0.64.6 (manaflow/cmux).
  ```
- cmux.app not found → print:
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

Behaviour depends on Check 1:

- If cmux.app was found (PRIMARY or warning above):
  - tmux present → informational: "tmux available (cmux.app's tmux-compat layer handles tmux-protocol calls)"
  - tmux absent → informational: "tmux not found, but cmux.app's tmux-compat layer covers the primary path. Install if needed: `brew install tmux`"
- If cmux.app was NOT found (FALLBACK path):
  - tmux present → print:
    ```
    tmux found → MODE: FALLBACK (tmux + git worktree)
    ```
  - tmux absent → print:
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

- Path returned → pass.
- Not found → print:
  ```
  jq is REQUIRED by /kingdom:work to read kingdom.json. Install:
    brew install jq
  ```

---

## Check 4 — `gh` CLI installed and authenticated

Run:

```bash
which gh
gh auth status
```

- `which gh` returns a path AND `gh auth status` exits 0 → pass.
- Otherwise → print:
  ```
  gh CLI is missing or not authenticated. It is required by /kingdom:work
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

- Version is 2.5 or higher → print:
  ```
  git <version> found — git worktree supported
  ```
- git missing or version < 2.5 → print:
  ```
  git >= 2.5 is REQUIRED for git worktree (kingdom lane management). Install or upgrade:
    brew install git
  ```

---

## Check 6 — `~/.claude/settings.json` has the right keys

Read the file:

```bash
cat ~/.claude/settings.json
```

Check two fields independently.

### Field A — `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

```bash
jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' ~/.claude/settings.json
```

- Value equals `"1"` → pass.
- Missing or wrong → show the diff and ask for confirmation before applying:
  ```
  Proposed change to ~/.claude/settings.json:

  + "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }

  Apply? [y/N]
  ```
  On `y`:
  ```bash
  tmp=$(mktemp)
  [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
  jq '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' ~/.claude/settings.json \
    > "$tmp" && mv "$tmp" ~/.claude/settings.json
  ```
  On `N` → warning: skipped.

### Field B — `teammateMode`

```bash
jq -r '.teammateMode // empty' ~/.claude/settings.json
```

- Value equals `"tmux"` → pass.
- Missing or wrong → show the diff and ask:
  ```
  Proposed change to ~/.claude/settings.json:

  + "teammateMode": "tmux"

  Apply? [y/N]
  ```
  On `y`:
  ```bash
  tmp=$(mktemp)
  [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
  jq '.teammateMode = "tmux"' ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
  ```

**Important:** every `jq` write must pass through the full existing document. Never overwrite unrelated keys. Use `jq '.<key> = <value>'` (not `--null-input`) so all other content is preserved.

Ask each field confirmation separately so the user can apply one and skip the other.

---

## Check 7 — `<workspace>/.kingdom/<project>/tasks/` writable

For each project that has a `.kingdom/<project>/kingdom.json`, verify `tasks/` exists or can be created:

```bash
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  PROJ=$(basename "$(dirname "$KJSON")")
  mkdir -p "$PWD/.kingdom/$PROJ/tasks" 2>/dev/null && echo "OK $PROJ" || echo "FAIL $PROJ"
done
```

- All projects print `OK` → pass.
- Any project prints `FAIL` → filesystem permissions prevent creation. Report the affected project path. Do not auto-fix.

If no `.kingdom/*/kingdom.json` files exist yet, mark this check as not applicable:

```
No kingdom.json found — tasks/ check skipped (run /kingdom:init first).
```

---

## Check 8 — Orphan audit artifacts (informational)

For each project with a `.kingdom/<project>/kingdom.json`, look for raw artifacts that have no corresponding curated digest (a sign that a lane closer was interrupted):

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
    BASE="${BASE%.md}"; BASE="${BASE%.txt}"
    # Strip known shard suffixes
    STRIPPED=$(echo "$BASE" | sed -E 's/__(kimi-p[0-9]+|shard-[0-9]+|pane[0-9]+(-[a-z0-9-]+)?)$//')
    [ -f "$CURATED_DIR/$STRIPPED.md" ] && continue
    # Fallback: UTC prefix match
    UTC=$(echo "$BASE" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{4}Z' | head -1)
    [ -n "$UTC" ] && ls "$CURATED_DIR/${UTC}__"*.md >/dev/null 2>&1 && continue
    ORPHANS=$((ORPHANS + 1))
  done
  echo "$PROJ: $ORPHANS orphan(s)"
done
```

- Every project reports `0 orphan(s)` → pass.
- Any project has orphans → print:
  ```
  Found orphan raw artifacts in <project>. Run /kingdom:work <project>
  (the audit step will backfill curated digests + master_agent.log lines).
  ```

If no `.kingdom/*/kingdom.json` files exist yet, mark this check as not applicable.

---

## Final summary

After all 8 checks (including any patch outcomes for Check 6), collect results. Use these result symbols:
- `OK` = passed or patched
- `WARN` = optional / informational / skipped by user
- `FAIL` = missing critical dependency

```bash
CHECK_RESULTS_LIST=$(printf '%s\n' \
  "${CMUX_RESULT}" "${TMUX_RESULT}" "${JQ_RESULT}" "${GH_RESULT}" "${GIT_RESULT}" \
  "${USER_SETTINGS_RESULT}" "${TASKS_WRITABLE_RESULT}" "${ORPHAN_AUDIT_RESULT}")

N_FAILED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^FAIL')
N_PATCHED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^PATCHED')

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

- cmux.app found AND `$CMUX_CLAUDE_PID` set:
  ```
  MODE: PRIMARY (manaflow/cmux + git worktree) — full features available
  ```
- cmux.app NOT found AND tmux found:
  ```
  MODE: FALLBACK (tmux + git worktree) — works but no native notifications / sidebar
  ```
- Neither cmux.app nor tmux found:
  ```
  MODE: HEADLESS (claude -p + git worktree) — no panes, no live UX
  ```

After the mode line, always print:

```
Next: run /kingdom:work <project> to start the day.
```

---

## Conventions

- **Idempotent.** Re-running reports pass for everything already satisfied. No side effects unless the user confirms a patch.
- **Never auto-install.** Print commands for the user to copy-paste. Auto-patching is allowed ONLY for `~/.claude/settings.json` fields, after per-field confirmation.
- **Ask each settings.json field confirmation separately** so the user can apply one and skip the other.
- **Use plain bash + jq + which / command -v for all checks.** No external tooling beyond what is being checked.
- **Renamed from `/kingdom:doctor` in v0.29.0.** The old command name is retired; this file is the canonical health check.
