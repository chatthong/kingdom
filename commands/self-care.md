---
description: Prerequisite checks for the kingdom — cmux/tmux/jq/gh/git, settings.json patches. Run once after install or upgrade. (Renamed from /kingdom:doctor in v0.29.0.)
argument-hint:
---

You are running the kingdom's prerequisite checks. Run 9 checks in order. Report a checkmark, warning, or fail marker for each. At the end, render the `doctor-report` card (3 variants: all-pass / partial-pass / failed) and print the detected operating mode.

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
# H4: zsh aborts the whole block if the glob matches nothing (no project yet). Disable nomatch so
# the loop simply runs zero times instead of erroring.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
shopt -s nullglob 2>/dev/null  # bash: same effect — unmatched glob expands to nothing, not the literal
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  [ -f "$KJSON" ] || continue
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
# H4: disable nomatch so the empty *.md / *.txt globs (and the no-project case) run zero times,
# not abort the whole Check-8 block. nullglob covers bash the same way.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
shopt -s nullglob 2>/dev/null
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  [ -f "$KJSON" ] || continue
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

## Check 9 — Workspace `.kingdom/.setting/` is in sync with plugin source (v0.30.0+)

`/kingdom:init` copies role docs, helpers, cards, and `reference/skill-routing.md` from the plugin's `.kingdom/.setting/` into the workspace. Subsequent plugin upgrades add new files (cards/ in v0.22, `reference/skill-routing.md` in v0.23, parallel_edit_fanout body in v0.30, …) that DO NOT propagate without re-running init. This check is the canary.

```bash
SRC="${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting"
DEST="$PWD/.kingdom/.setting"

# Skip if workspace was never initialised (init handles greenfield setup)
if [ ! -d "$DEST" ]; then
  STALE_RESULT="WARN  workspace .kingdom/.setting/ absent — run /kingdom:init"
  STALE_FILES=""
else
  # Build the expected file list from plugin source (relative paths)
  EXPECTED=$(cd "$SRC" && find . -type f \( -name '*.md' \) | sed 's|^\./||' | sort)

  MISSING=""
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    [ -f "$DEST/$rel" ] || MISSING="$MISSING $rel"
  done <<< "$EXPECTED"

  if [ -z "$MISSING" ]; then
    STALE_RESULT="OK    workspace .kingdom/.setting/ in sync ($(echo "$EXPECTED" | wc -l | tr -d ' ') files)"
    STALE_FILES=""
  else
    N_STALE=$(echo $MISSING | wc -w | tr -d ' ')
    STALE_RESULT="PATCHED  ${N_STALE} stale workspace file(s) — see Patched"
    STALE_FILES="$MISSING"
  fi
fi
```

If `STALE_FILES` is non-empty, prompt the user before importing (per § Conventions — auto-patching is allowed only after confirmation):

```
${N_STALE} file(s) in the plugin's .kingdom/.setting/ are missing from this workspace:
  ${STALE_FILES}

These usually accumulate after a plugin upgrade. Import them now? [y/N]
```

On `y`:

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $STALE_FILES in the loop below (else 1 iteration over the whole blob); auto-reverts
mkdir -p "$DEST"
for rel in $STALE_FILES; do
  mkdir -p "$DEST/$(dirname "$rel")"
  cp "$SRC/$rel" "$DEST/$rel"
  PATCHED_LIST="${PATCHED_LIST}
  ✓ imported $rel"
done
N_PATCHED=$((N_PATCHED + N_STALE))
```

On `N` → warning: stale files left in place. King may misbehave if it references a file that doesn't exist locally; flag this to the user.

**Why not auto-import without asking:** plugin upgrades may add files that the user has intentionally not configured (e.g. a card template they overrode). Per § Conventions, every disk write needs a confirmation, even one this benign.

---

## Check 10 — story-pod config present (v0.32.0+, informational)

If a project's `kingdom.json` predates v0.32.0 it will lack the `integration` block, `shape.seniors`, and the `seniors[]` array. Story pods stay off until those exist. This check is informational: report it and recommend `/kingdom:update` (the migration command — additively merges the new schema keys into every `kingdom.json`, preserving existing values + all runtime), or note the project keeps the classic per-worker flow.

```bash
# H4: disable nomatch so the no-project case runs zero iterations instead of aborting the block.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
shopt -s nullglob 2>/dev/null
for KJSON in "$PWD"/.kingdom/*/kingdom.json; do
  [ -f "$KJSON" ] || continue
  proj=$(basename "$(dirname "$KJSON")")
  has_integ=$(jq -r 'has("integration")' "$KJSON" 2>/dev/null)
  has_seniors=$(jq -r '.shape | has("seniors")' "$KJSON" 2>/dev/null)
  if [ "$has_integ" = "true" ] && [ "$has_seniors" = "true" ]; then
    echo "  ✓ $proj: story-pod config present (seniors=$(jq -r '.shape.seniors // 0' "$KJSON"), unit=$(jq -r '.integration.unit // "pod"' "$KJSON"))"
  else
    echo "  ⓘ $proj: pre-v0.32.0 config (no integration/seniors keys). Story pods OFF; classic per-worker flow active. Run /kingdom:update to add them (additive; keeps your values + runtime)."
  fi
done
```

This is never a hard fail: a project without the keys simply runs the classic flow. No auto-patch.

---

## Check 11 — modular structure lint (v0.35.0+, informational)

The kit is now many small files (`rules/`, `functions/` + backend subfolders like `functions/cmux/`, `roles/`, `reference/`). This lint keeps that structure from rotting as it grows: every function parses, every rule is registered, every manifest feature's functions resolve to a file, and every internal link resolves.

```bash
SET="${CLAUDE_PLUGIN_ROOT:-$PWD}/.kingdom/.setting"; bad=0
# Collect every function file once (flat + one level of backend subfolders), via find so an
# absent subfolder can't trip glob-nomatch. PRESENT = space-padded set of bare function names.
PRESENT=" $(find "$SET/functions" -maxdepth 2 -name '*.sh' ! -name '_load.sh' -exec basename {} .sh \; 2>/dev/null | tr '\n' ' ') "
# (a) every function .sh parses — flat AND backend subfolders (cmux/, future tmux/)
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || { echo "  ✗ syntax: ${f#$SET/}"; bad=1; }
done < <(find "$SET/functions" -maxdepth 2 -name '*.sh' ! -name '_load.sh' 2>/dev/null)
# (b) every rule file is listed in rules/index.md
for r in "$SET"/rules/R*.md; do id=$(basename "$r" | grep -oE '^R[0-9]+'); grep -q "\b$id\b" "$SET/rules/index.md" || { echo "  ✗ $id missing from rules/index.md"; bad=1; }; done
# (c) every function named in manifest.json resolves to a file (flat OR a backend subfolder).
#     Catches a partial scaffold — e.g. /kingdom:init failing to copy functions/cmux/ (the whole
#     cmux + browser backend), which silently breaks load_feature cmux/core at runtime.
if command -v jq >/dev/null 2>&1; then
  for fn in $(jq -r '.features[].functions[]?' "$SET/manifest.json" 2>/dev/null | sort -u); do
    case "$PRESENT" in *" $fn "*) : ;; *) echo "  ✗ manifest fn '$fn' has no .sh file (backend subfolder not scaffolded?)"; bad=1 ;; esac
  done
fi
# (d) every local .md link under .setting resolves
python3 - "$SET" <<'PY'
import io,os,re,sys
root=sys.argv[1]; lr=re.compile(r'\]\(([^)]+\.md)(#[^)]*)?\)')
for b,_,fs in os.walk(root):
  for f in fs:
    if not f.endswith(".md"): continue
    p=os.path.join(b,f); d=os.path.dirname(p)
    for m in lr.finditer(io.open(p,encoding="utf-8").read()):
      t=m.group(1)
      if t.startswith("http"): continue
      if not os.path.exists(os.path.normpath(os.path.join(d,t))): print(f"  ✗ broken link: {os.path.relpath(p,root)} -> {t}")
PY
[ "$bad" = 0 ] && echo "  ✓ structure lint clean" || echo "  ⚠ structure issues above (see lines)"
```

Informational (a consumer workspace may have customized files). Run it after a `/kingdom:init` re-sync or before shipping a plugin change so the modular tree can't silently break.

## Check 12 — kit version vs installed plugin (v0.38.0+, informational)

Detects whether the workspace's kit (`.kingdom/.setting/`) is behind the installed plugin — i.e. the user updated the `kingdom` plugin from Claude but hasn't run `/kingdom:update` yet.

```bash
STAMP="$PWD/.kingdom/.setting/.kingdom-version"
CUR=$(cat "$STAMP" 2>/dev/null || echo "")
NEW=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)
if [ ! -d "$PWD/.kingdom/.setting" ]; then
  echo "  ⓘ no .kingdom/.setting/ here — not a kingdom workspace (run /kingdom:init)."
elif [ -z "$CUR" ]; then
  echo "  ⚠ kit has no version stamp (pre-0.38.0). Run /kingdom:update to stamp + migrate to v$NEW (preserves tasks/logs/state/memory)."
elif [ "$CUR" != "$NEW" ]; then
  echo "  ⚠ kit is v$CUR but the installed plugin is v$NEW → run /kingdom:update to migrate (additive; preserves tasks/logs/state/memory)."
else
  echo "  ✓ kit v$CUR matches the installed plugin."
fi
```

Informational — never auto-migrates. The actual migration (`/kingdom:update`) previews the full delta and asks for confirmation before any write.

## Check 13 — kingdom-mechanics drift in project memory (v0.38.1+, informational, READ-ONLY)

Memory drifts. A memory note that snapshots kingdom workflow mechanics (kingdom-branch handling, overlay, gate flow, dispatch, spawn helpers, cmux quirks) silently fights the versioned plugin — per **R34** the plugin rules win, and a stale snapshot just misleads (the exact failure that cost a full session: a memory said "spawn helpers are broken, hand-roll cmux_send" long after the bug was fixed). This check **FLAGS — never edits** — such memory so you can review/nuke it. The plugin NEVER writes to your memory (see the consumer-side no-blind-memory-writes rule).

```bash
# Claude Code keys per-project memory by the launch path (/ → -).
MEM="$HOME/.claude/projects/$(echo "$PWD" | sed 's#/#-#g')/memory"
NEW=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)
if [ ! -d "$MEM" ]; then
  echo "  ⓘ no project-memory dir for this workspace — nothing to scan."
else
  flagged=0
  # (a) mechanics snapshots — memory restating kingdom IMPLEMENTATION. Match
  #     function/command-level tokens only (cmux_send, spawn_*, workspace.list,
  #     _load.sh, …), NOT generic words like "overlay"/"dispatch" which appear in
  #     legitimate governance/convention notes — those are facts, not mechanics.
  while IFS= read -r f; do
    grep -qiE 'cmux_send|cmux_rpc|cmux_read_screen|workspace\.list|spawn_(master|loop|subagent|pool)|kingdom_overlay|git apply --3way|_load\.sh|load_feature|send-key' "$f" 2>/dev/null && {
      echo "  ⚠ mechanics snapshot: $(basename "$f") — restates kingdom implementation; that lives in .kingdom/.setting/ (R34: rules override memory). Review; nuke if it's a workflow snapshot."
      flagged=$((flagged+1))
    }
  done < <(find "$MEM" -maxdepth 1 -name '*.md' ! -name 'MEMORY.md' 2>/dev/null)
  # (b) version-stale — a kingdom-related note naming a version older than installed
  while IFS= read -r f; do
    grep -qi 'kingdom' "$f" 2>/dev/null || continue
    old=$(grep -oE 'v?0\.[0-9]+\.[0-9]+' "$f" 2>/dev/null | tr -d v | head -1)
    [ -n "$old" ] && [ -n "$NEW" ] && [ "$old" != "$NEW" ] && {
      echo "  ⚠ version-stale: $(basename "$f") names v$old (plugin is v$NEW) — may describe superseded behavior."
      flagged=$((flagged+1))
    }
  done < <(find "$MEM" -maxdepth 1 -name '*.md' ! -name 'MEMORY.md' 2>/dev/null)
  # (c) duplicate stores from path-casing (same workspace keyed twice)
  base=$(basename "$PWD")
  dupes=$(find "$HOME/.claude/projects" -maxdepth 1 -type d -iname "*-$base" 2>/dev/null | wc -l | tr -d ' ')
  [ "$dupes" -gt 1 ] && { echo "  ⚠ $dupes memory stores match this workspace name (path-casing dupes, e.g. Bonfire vs bonfire) — they diverge silently. Always open the workspace with ONE canonical path."; flagged=$((flagged+1)); }
  [ "$flagged" = 0 ] && echo "  ✓ no kingdom-mechanics / version-stale / duplicate-store memory detected." \
    || echo "  → $flagged flag(s). READ-ONLY: review each yourself; the plugin never edits memory."
fi
```

If a flagged file is genuinely a project FACT or governance note (not a workflow snapshot), keep it — the flag is advisory. The boundary: **plugin** (`.kingdom/.setting/`) owns mechanics; **project memory** owns project facts + governance the plugin is silent on; **user memory** owns personal preferences.

---

## Final summary

After all checks (including any patch outcomes for Check 6 + import outcomes for Check 9), collect results. Use these result symbols:
- `OK` = passed or patched
- `WARN` = optional / informational / skipped by user
- `FAIL` = missing critical dependency
- `PATCHED` = auto-fixed after user confirmation (Check 6 settings.json or Check 9 file import)

```bash
# C9: source the loader so render_card resolves in this final block.
[ -f "$PWD/.kingdom/.setting/functions/_load.sh" ] && source "$PWD/.kingdom/.setting/functions/_load.sh" && load_feature core

CHECK_RESULTS_LIST=$(printf '%s\n' \
  "${CMUX_RESULT}" "${TMUX_RESULT}" "${JQ_RESULT}" "${GH_RESULT}" "${GIT_RESULT}" \
  "${USER_SETTINGS_RESULT}" "${TASKS_WRITABLE_RESULT}" "${ORPHAN_AUDIT_RESULT}" \
  "${STALE_RESULT}")

N_FAILED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^FAIL')
N_PATCHED=$(echo "$CHECK_RESULTS_LIST" | grep -c '^PATCHED')

# task-4(a): bash state does NOT persist between markdown blocks, so the per-check version strings
# the doctor-report card prints (OS / cmux / tmux / jq / gh / git / N_PROJECTS) must be (re)derived
# HERE, in the same block that exports them — otherwise the card renders blank.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || uname -sr)
CMUX_VERSION=$(cmux --version 2>/dev/null | head -1 || echo "not found")
TMUX_VERSION=$(tmux -V 2>/dev/null || echo "not found")
JQ_VERSION=$(jq --version 2>/dev/null || echo "not found")
GH_VERSION=$(gh --version 2>/dev/null | head -1 || echo "not found")
GIT_VERSION=$(git --version 2>/dev/null || echo "not found")
N_PROJECTS=$(find "$PWD/.kingdom" -maxdepth 2 -name kingdom.json 2>/dev/null | wc -l | tr -d ' ')

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
