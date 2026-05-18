---
description: Scaffold the kingdom — workspace role docs (always), workspace .claude/settings.json permissions (if missing/incomplete), and optionally a per-project kingdom.json
argument-hint: [project] [workers=N] [co-workers=M] [watchman=K] [base=<branch>]
---

You are scaffolding the kingdom. **One command, two modes:**

- `/kingdom:init` (no args) → workspace-only scaffold: `.kingdom/.setting/` role docs + `.claude/settings.json` permissions.
- `/kingdom:init <project>` → workspace scaffold (if missing) PLUS project scaffold: `.kingdom/<project>/kingdom.json` + `tasks/` + `logs/`.

Idempotent in both modes — re-running is safe. If both layers already exist, prints status and stops.

Follow every step in order. Show planned changes and ask for confirmation before any file write or overwrite.

## Step 0 — Parse arguments

From `$ARGUMENTS`, extract:

- `project` — the first positional argument (optional). If present, run BOTH workspace scaffold AND project scaffold. If absent, run workspace scaffold only.
- `workers` — value from `workers=N` (default: `3`) — only used when `project` is given
- `co-workers` — value from `co-workers=M` (default: `1`) — only used when `project` is given
- `watchman` — value from `watchman=K` (default: `1`) — only used when `project` is given
- `base` — value from `base=<branch>` (default: `develop`) — only used when `project` is given

Examples:
- `/kingdom:init` → workspace only
- `/kingdom:init bfg-swt` → workspace (if needed) + project `bfg-swt` with defaults
- `/kingdom:init bfg-swt workers=5 co-workers=2 watchman=1 base=main` → workspace + custom project shape

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
mkdir -p "$PWD/.kingdom/.setting/"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/index.md"      "$PWD/.kingdom/.setting/index.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/kings.md"      "$PWD/.kingdom/.setting/kings.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/workers.md"    "$PWD/.kingdom/.setting/workers.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/co-workers.md" "$PWD/.kingdom/.setting/co-workers.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/watchmans.md"  "$PWD/.kingdom/.setting/watchmans.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/git.md"        "$PWD/.kingdom/.setting/git.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/cmux.md"       "$PWD/.kingdom/.setting/cmux.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/_primitives.md" "$PWD/.kingdom/.setting/_primitives.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/rules.md"       "$PWD/.kingdom/.setting/rules.md"

# v0.22.0+: card library
mkdir -p "$PWD/.kingdom/.setting/cards"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/cards/"*.md "$PWD/.kingdom/.setting/cards/"

# v0.23.0+: per-task skill routing
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/skill-routing.md" "$PWD/.kingdom/.setting/skill-routing.md"

wc -l "$PWD/.kingdom/.setting/"*.md
```

Print the file list with line counts.

## Step 3 — Workspace scaffold: `.claude/settings.json` permissions

Background sub-agents (the parallel fan-out in `/kingdom:update`, worker dispatches, etc.) need an explicit `permissions.allow` list in the workspace-scoped `.claude/settings.json` or they stall on permission prompts that nobody sees.

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

> The path-scoped entries eliminate the most common interactive permission prompts: lanes reading task files at `.kingdom/<project>/tasks/` or worktree files at `.worktrees/<lane>/`. Without them, Claude Code blocks the lane on each unfamiliar path until you approve. Watchman's blocked-lane scan (see `.kingdom/.setting/watchmans.md`) catches any prompts that still fire.

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

> ⚠️ Skipped. `/kingdom:update` and `/kingdom:start` background sub-agents will stall on permission prompts. Re-run `/kingdom:init` or `/kingdom:doctor` to apply later.

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

Then ask:

> `.kingdom/<project>/kingdom.json` already exists (shown above). Overwrite with the new values? (yes/no)

Wait for confirmation before continuing. If `JSON_MISSING`, continue without asking.

### Step 4.2 — Build the project config from the template

Substitute the parsed argument values into the template:

```bash
jq \
  --argjson workers    "${workers}" \
  --argjson coworkers  "${co-workers}" \
  --argjson watchman   "${watchman}" \
  --arg     base       "${base}" \
  '
    .shape.workers       = $workers   |
    .shape["co-workers"] = $coworkers |
    .shape.watchman      = $watchman  |
    .git.base            = $base
  ' \
  "${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"
```

Show the resulting JSON to the user. Then ask:

> Will write the JSON above to `.kingdom/<project>/kingdom.json`. Proceed? (yes/no)

Wait for confirmation.

### Step 4.3 — Write project files + ensure dirs

```bash
mkdir -p "$PWD/.kingdom/${project}/tasks"
mkdir -p "$PWD/.kingdom/${project}/logs"

jq \
  --argjson workers    "${workers}" \
  --argjson coworkers  "${co-workers}" \
  --argjson watchman   "${watchman}" \
  --arg     base       "${base}" \
  '
    .shape.workers       = $workers   |
    .shape["co-workers"] = $coworkers |
    .shape.watchman      = $watchman  |
    .git.base            = $base
  ' \
  "${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template" \
  > "$PWD/.kingdom/${project}/kingdom.json"
```

Print the written file for review:

```bash
cat "$PWD/.kingdom/${project}/kingdom.json"
```

## Step 5 — Report + suggest next step (renders `cards/scaffold-success.md`)

Print the [`scaffold-success`](../.kingdom/.setting/cards/scaffold-success.md) card. Variant depends on whether `project` was passed:

```bash
N_ROLE_DOCS=$(ls -1 "$PWD/.kingdom/.setting/"*.md 2>/dev/null | wc -l | tr -d ' ')

if [ -n "$project" ]; then
  # Project mode
  export PROJECT="$project" N_ROLE_DOCS WORKERS COWORKERS WATCHMAN BASE
  render_card "scaffold-success"
else
  # Workspace-only mode — uses the slimmer variant in cards/scaffold-success.md
  export N_ROLE_DOCS
  render_card "scaffold-success/workspace-only"
fi
```

The card output replaces the prior plain-text "Kingdom ready for `<project>`" block. See [`cards/scaffold-success.md`](../.kingdom/.setting/cards/scaffold-success.md) for the full template + both variants.

If the user opted out of the `.claude/settings.json` patch (Step 3 answered `N`), the card appends a warning line: `⚠ Skipped settings.json patch — sub-agents may stall on permission prompts.`
