---
description: Check kingdom prerequisites + auto-patch ~/.claude/settings.json (show diff, ask once per field)
---

Run 6 checks in order. Report ✅/⚠️/❌ for each. At the end, summarise green/yellow/red counts, overall readiness, and detected operating mode.

---

## Check 1 — manaflow/cmux app installed

Run:
```bash
ls -d /Applications/cmux.app 2>/dev/null && echo found || echo missing
```

Also check whether `$CMUX_CLAUDE_PID` is set:
```bash
echo "${CMUX_CLAUDE_PID:-unset}"
```

- ✅ PRIMARY if `found` is returned AND `$CMUX_CLAUDE_PID` is set — print exactly:
  ```
  manaflow/cmux.app detected + $CMUX_CLAUDE_PID set → MODE: PRIMARY
  ```
- ⚠️ if `found` is returned but `$CMUX_CLAUDE_PID` is unset — print exactly:
  ```
  manaflow/cmux.app is installed but $CMUX_CLAUDE_PID is not set.
  Launch kingdom sessions from inside cmux.app to activate PRIMARY mode.
  ```
- ❌ if not found — print exactly:
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
  jq is REQUIRED by /kingdom-start to read kingdom.json. Install:
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
  gh CLI is missing or not authenticated. It is required by /kingdom-start
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

Note: this is an informational check — the `tasks/` directory is auto-created by `/kingdom-new` and `/kingdom-start`. This check exists so the doctor can flag permission issues early, before lanes try to write task files.

If no `.kingdom/*/kingdom.json` files exist yet (kingdom not yet initialised), print:

```
No kingdom.json found — tasks/ check skipped (run /kingdom-new first).
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

For each project with a `.kingdom/<project>/kingdom.json`, look for raw artifacts that have no corresponding curated digest — a sign that a lane closer was interrupted or that `/kingdom-update` is due.

```bash
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  PROJ=$(basename "$(dirname "$KJSON")")
  RAW_DIR="$PWD/.kingdom/$PROJ/logs/raw"
  CURATED_DIR="$PWD/.kingdom/$PROJ/logs"
  [ -d "$RAW_DIR" ] || continue
  ORPHANS=0
  for RAW in "$RAW_DIR"/*.md; do
    [ -f "$RAW" ] || continue
    ID=$(basename "$RAW" | cut -d'_' -f1-2)   # adjust if your ID separator differs
    [ -f "$CURATED_DIR/$ID.md" ] || ORPHANS=$((ORPHANS + 1))
  done
  echo "$PROJ: $ORPHANS orphan(s)"
done
```

- ✅ if every project reports `0 orphan(s)`.
- ⚠️ if any project has orphans — print exactly:
  ```
  Found orphan raw artifacts in <project>. Run /kingdom-update <project>
  to backfill curated digests + master_agent.log lines.
  ```

If no `.kingdom/*/kingdom.json` files exist yet, mark this check ✅ (not applicable).

---

## Final Summary

After all 8 checks (including any patch outcomes for Check 6), print a single summary block.

Count results:
- ✅ = green (met or patched)
- ⚠️ = yellow (optional/skipped)
- ❌ = red (missing critical dependency)

Then print ONE of:

**All green:**
```
Kingdom is ready. Run /kingdom-start to launch your first session.
```

**Some yellow/red but no critical ❌:**
```
Kingdom partially ready — install the following to enable the full feature set:
  - <item> (<reason>)
```

**Any critical ❌ (manaflow/cmux app, jq, git < 2.5):**
```
Kingdom not ready — install the following before running /kingdom-start:
  - <item> (<reason>)
```

The MODE-status block above checks PRIMARY/FALLBACK/HEADLESS; the `tasks/` writability check (Check 7) confirms the audit-trail directory is ready.

Then, on the final line, always print the detected mode:

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
