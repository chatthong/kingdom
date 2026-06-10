---
description: Scaffold the kingdom — workspace role docs (always), workspace .claude/settings.json permissions (if missing/incomplete), and optionally a per-project kingdom.json
argument-hint: [project]
---

You are scaffolding the kingdom. **One command, two modes:**

- `/kingdom:init` (no args) → workspace-only scaffold: `.kingdom/.setting/` role docs + `.claude/settings.json` permissions.
- `/kingdom:init <project>` → workspace scaffold (if missing) PLUS project scaffold: `.kingdom/<project>/kingdom.json` + `tasks/` + `logs/`.

Idempotent in both modes — re-running is safe. If both layers already exist, prints status and stops.

Follow every step in order. Show planned changes and ask for confirmation before any file write or overwrite.

## Step 0 — Parse arguments

From `$ARGUMENTS`, extract:

- `project` — the first positional argument (optional). If present, run BOTH workspace scaffold AND project scaffold. If absent, run workspace scaffold only.

**`init` takes no shape flags (v0.33.0).** It only scaffolds: it does not read the task-ledger, decide work, or spawn anything. The project's `kingdom.json` is written from the template with its **defaults** (workers=3, co-worker=1, watchman=1, senior=1, base=develop). Tune the shape per-session at `/kingdom:work` time (`worker=N`, `lane=N`, `senior=N`, …) or by editing `kingdom.json` once. `git.base` lives in the file (default `develop`); edit that one line if your repo differs.

Examples:
- `/kingdom:init` → workspace only
- `/kingdom:init bfg-swt` → workspace (if needed) + project `bfg-swt` scaffolded with defaults

## Step 1 — Verify this is a workspace root (not a git repo)

```bash
ls "$PWD/.git" 2>/dev/null && echo "GIT_FOUND" || echo "GIT_NOT_FOUND"
```

If `GIT_FOUND`, warn:

> Warning: `$PWD/.git/` exists. Kingdom workspaces are NOT git repos — their sub-projects have their own `.git/`. This looks like a project directory, not a workspace root. Proceed anyway? (yes/no)

Wait for the user to confirm. If `GIT_NOT_FOUND`, continue without asking.

## Step 2 — Workspace scaffold: `.kingdom/.setting/` role docs

```bash
ls "$PWD/.kingdom/.setting/" 2>/dev/null && echo "SETTING_EXISTS" || echo "SETTING_MISSING"
```

If `SETTING_EXISTS`, list what's there:

```bash
ls -1 "$PWD/.kingdom/.setting/"
```

Then ask:

> `.kingdom/.setting/` already exists with the files listed above. Overwrite? (yes/no)

Wait for confirmation. On `no`, skip to Step 3 (do NOT re-copy).

On `yes` OR if `SETTING_MISSING`, run:

```bash
# H4: zsh aborts the whole block on an unmatched glob (the cp "$SRC/roles/"*.md lines below).
# Disable nomatch so a missing/empty source dir fails the explicit guard, not the glob.
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null
SRC="${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting"
DST="$PWD/.kingdom/.setting"

# Fail closed if the plugin source tree is absent — better an explicit error than a half-copied kit.
[ -d "$SRC" ] || { echo "❌ plugin source $SRC missing — cannot scaffold (is CLAUDE_PLUGIN_ROOT set?)"; return 1 2>/dev/null || exit 1; }

# K9 (v0.37.0): clean-replace, NOT overlay. An older flat layout (kings.md,
# workers.md, cmux.md, …) left beside the new roles/ + reference/ dirs becomes a
# dead trap — index.md points at the new paths, so the stale flat files just
# mislead. Back up any existing tree by renaming it, then install fresh; this
# guarantees no removed-upstream file survives the migration.
if [ -d "$DST" ]; then
  BAK="$DST.bak-$(date -u +%Y%m%d-%H%M%S)"
  mv "$DST" "$BAK"
  echo "Backed up existing .setting/ -> $(basename "$BAK") (clean-replace, no stale files carried over)"
fi
# Copy as an all-or-nothing unit: if any cp fails (missing source dir, permissions), restore the
# backup so the workspace is never stranded with a half-written .setting/. Mirrors update.md 5a.
if ! (
  set -e
  mkdir -p "$DST/roles" "$DST/reference" "$DST/rules" "$DST/functions" "$DST/cards"
  # top-level files (index + the two back-compat pointers + the feature manifest)
  cp "$SRC/index.md"        "$DST/index.md"
  cp "$SRC/manifest.json"   "$DST/manifest.json"     # v0.35.0: feature registry for load_feature
  cp "$SRC/rules.md"        "$DST/rules.md"           # pointer -> rules/index.md
  cp "$SRC/_primitives.md"  "$DST/_primitives.md"     # pointer -> functions/index.md
  # the one-file-each directories (copy whole dirs so every role/reference/rule .md + *.sh come along)
  cp "$SRC/roles/"*.md      "$DST/roles/"             # king/worker/co-worker/watchman/senior (one file per role, v0.40.0)
  cp "$SRC/reference/"*.md  "$DST/reference/"         # cmux / git / skill-routing / role-bootstrap
  cp "$SRC/rules/"*.md      "$DST/rules/"             # R01..R53 + index.md
  cp -R "$SRC/functions/."  "$DST/functions/"         # flat *.sh + index.md + _load.sh + cmux/ + tmux/ backends. -R so subfolders come along (plain cp skips directories).
  cp "$SRC/cards/"*.md      "$DST/cards/"
  # Stamp the kit version (v0.38.0+) so /kingdom:update can detect drift later.
  jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" > "$DST/.kingdom-version"
); then
  echo "❌ kit copy failed — restoring backup, workspace left unchanged" >&2
  [ -d "$BAK" ] && { rm -rf "$DST"; mv "$BAK" "$DST"; }
  return 1 2>/dev/null || exit 1
fi

echo "Scaffolded .setting/: $(find "$DST" -name '*.md' -o -name '*.sh' -o -name '*.json' | wc -l | tr -d ' ') files"
ls -1 "$DST"
```

Print the file list with line counts.

## Step 3 — Workspace scaffold: `.claude/settings.json` permissions

Background sub-agents (the parallel fan-out in `/kingdom:work`'s audit, worker dispatches, etc.) need an explicit `permissions.allow` list in the workspace-scoped `.claude/settings.json` or they stall on permission prompts that nobody sees.

```bash
WS_SETTINGS="$PWD/.claude/settings.json"
mkdir -p "$PWD/.claude"
[ -f "$WS_SETTINGS" ] || echo '{}' > "$WS_SETTINGS"

REQUIRED='["Bash","Read","Write","Edit","Grep","Glob","Agent","Read(.kingdom/**)","Write(.kingdom/**)","Edit(.kingdom/**)","Read(.worktrees/**)","Write(.worktrees/**)","Edit(.worktrees/**)"]'
HAS_ALL=$(jq --argjson req "$REQUIRED" '
  if .permissions.allow then ($req - .permissions.allow | length == 0) else false end
' "$WS_SETTINGS")
```

If `HAS_ALL` is `true`, report: "`.claude/settings.json` permissions OK — skipping."

If `HAS_ALL` is `false`, show the diff and ask:

```
Proposed change to .claude/settings.json (workspace-scoped):

+ permissions.allow ← merge in [
    Bash, Read, Write, Edit, Grep, Glob, Agent,
    Read(.kingdom/**), Write(.kingdom/**), Edit(.kingdom/**),
    Read(.worktrees/**), Write(.worktrees/**), Edit(.worktrees/**)
  ]

Apply? [y/N]
```

> The path-scoped entries eliminate the most common interactive permission prompts: lanes reading task files at `.kingdom/<project>/tasks/` or worktree files at `.worktrees/<lane>/`. Without them, Claude Code blocks the lane on each unfamiliar path until you approve. Watchman's blocked-lane scan (see `.kingdom/.setting/roles/watchman.md`) catches any prompts that still fire.

On `y`, merge with `jq` (preserves any existing keys + dedupes):

```bash
tmp=$(mktemp)
jq '.permissions.allow = (((.permissions.allow // []) + [
  "Bash","Read","Write","Edit","Grep","Glob","Agent",
  "Read(.kingdom/**)","Write(.kingdom/**)","Edit(.kingdom/**)",
  "Read(.worktrees/**)","Write(.worktrees/**)","Edit(.worktrees/**)"
]) | unique)' \
  "$WS_SETTINGS" > "$tmp" && mv "$tmp" "$WS_SETTINGS"
jq '.permissions' "$WS_SETTINGS"
```

On `N`, warn:

> Skipped. `/kingdom:work` background sub-agents will stall on permission prompts. Re-run `/kingdom:init` or `/kingdom:self-care` to apply later.

## Step 4 — Project scaffold (only when `project` arg is given)

If no `project` was passed in Step 0, **skip to Step 5** and report workspace-only completion.

Otherwise, scaffold the project layer:

### Step 4.1 — Check for existing kingdom.json

```bash
ls "$PWD/.kingdom/${project}/kingdom.json" 2>/dev/null && echo "JSON_EXISTS" || echo "JSON_MISSING"
```

If `JSON_EXISTS`, show the existing content:

```bash
cat "$PWD/.kingdom/${project}/kingdom.json"
```

Then ask (K8 — never blind-overwrite a hand-tuned config):

> `.kingdom/<project>/kingdom.json` already exists (shown above). Choose:
> - `merge` (recommended) — add any NEW schema keys this template version introduces; keep ALL your existing values (shape, per-lane models, gate commands, integration settings, …)
> - `overwrite` — replace with template defaults (loses your tuning; a timestamped `.bak` is written first)
> - `keep` — leave it untouched, skip to Step 5

Record the answer as `json_action` (`merge` / `overwrite` / `keep`) for Step 4.3. On `keep`, skip Step 4.2 + 4.3 and go to Step 5. If `JSON_MISSING`, treat as a fresh write (`json_action=fresh`, template verbatim) without asking.

### Step 4.2 — Preview what will be written

Show the user the exact result for their chosen `json_action`. For `fresh`/`overwrite` it's the template defaults; for `merge` it's the template-plus-existing result (existing values win):

```bash
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"
TARGET="$PWD/.kingdom/${project}/kingdom.json"
case "${json_action:-fresh}" in
  keep)   echo "Keeping existing $TARGET unchanged — nothing to preview." ;;
  merge)  jq -s '.[0] * .[1]' "$TEMPLATE" "$TARGET" ;;   # template base, existing wins
  *)      jq '.' "$TEMPLATE" ;;                            # fresh / overwrite = template
esac
```

Then ask:

> Will write the `kingdom.json` above to `.kingdom/<project>/kingdom.json`. Proceed? (yes/no)

Wait for confirmation.

### Step 4.3 — Write project files + ensure dirs

```bash
mkdir -p "$PWD/.kingdom/${project}/tasks"
mkdir -p "$PWD/.kingdom/${project}/logs"

TEMPLATE="${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"
TARGET="$PWD/.kingdom/${project}/kingdom.json"

# K8 (v0.37.0): never blind-overwrite a hand-tuned config.
#   merge     → template is the base, existing values WIN on every overlapping key
#               (jq `*` deep-merge: right operand wins) → new schema keys added, tuning kept
#   overwrite → back up first, then template verbatim
#   fresh     → template verbatim (no existing file)
case "${json_action:-fresh}" in
  keep)
    echo "Keeping existing $TARGET unchanged (json_action=keep)."
    ;;
  merge)
    cp "$TARGET" "$TARGET.bak-$(date -u +%Y%m%d-%H%M%S)"
    tmp=$(mktemp); jq -s '.[0] * .[1]' "$TEMPLATE" "$TARGET" > "$tmp" && mv "$tmp" "$TARGET"
    ;;
  overwrite)
    cp "$TARGET" "$TARGET.bak-$(date -u +%Y%m%d-%H%M%S)"
    jq '.' "$TEMPLATE" > "$TARGET"
    ;;
  *)  # fresh (no existing file)
    jq '.' "$TEMPLATE" > "$TARGET"
    ;;
esac
```

Print the written file for review:

```bash
cat "$PWD/.kingdom/${project}/kingdom.json"
```

## Step 5 — Report + suggest next step (renders `cards/scaffold-success.md`)

Print the [`scaffold-success`](../.kingdom/.setting/cards/scaffold-success.md) card. Variant depends on whether `project` was passed:

```bash
# C9: source the helper loader so render_card resolves. Prefer the freshly-scaffolded workspace
# copy; fall back to the plugin's own copy if the workspace one isn't present yet.
if [ -f "$PWD/.kingdom/.setting/functions/_load.sh" ]; then
  source "$PWD/.kingdom/.setting/functions/_load.sh" && load_feature core
elif [ -f "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/functions/_load.sh" ]; then
  source "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/functions/_load.sh" && load_feature core
fi

# init.md line ~237 / task-5: count ALL kit .md docs (the v0.40 modular split moved role docs into
# roles/, rules/, reference/ subdirs — a top-level *.md glob counts only 3 pointer/index files).
N_ROLE_DOCS=$(find "$PWD/.kingdom/.setting" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

if [ -n "$project" ]; then
  # Project mode
  export PROJECT="$project" N_ROLE_DOCS
  render_card "scaffold-success"
else
  # Workspace-only mode — uses the slimmer variant in cards/scaffold-success.md
  export N_ROLE_DOCS
  render_card "scaffold-success/workspace-only"
fi
```

The card output replaces the prior plain-text "Kingdom ready for `<project>`" block. See [`cards/scaffold-success.md`](../.kingdom/.setting/cards/scaffold-success.md) for the full template + both variants.

If the user opted out of the `.claude/settings.json` patch (Step 3 answered `N`), the card appends a warning line: `Skipped settings.json patch — sub-agents may stall on permission prompts.`

Next: run `/kingdom:self-care` to verify environment, then `/kingdom:work` to start.
