---
description: Create .kingdom/<project>/kingdom.json from the template (optional args: workers=N co-workers=M watchman=K base=<branch>)
argument-hint: <project> [workers=N] [co-workers=M] [watchman=K] [base=<branch>]
---

You are creating a `kingdom.json` for a specific project. Parse `$ARGUMENTS`, then follow every step in order. Show planned changes and ask for confirmation before any file write or overwrite.

## Step 0 — Parse arguments

From `$ARGUMENTS`, extract:

- `project` — the first positional argument (required). If missing, tell the user "Usage: /kingdom-new <project> [workers=N] [co-workers=M] [watchman=K] [base=<branch>]" and stop.
- `workers` — value from `workers=N` (default: `3`)
- `co-workers` — value from `co-workers=M` (default: `1`)
- `watchman` — value from `watchman=K` (default: `1`)
- `base` — value from `base=<branch>` (default: `develop`)

Example: `/kingdom-new td-rep workers=4 base=main` → project=`td-rep`, workers=`4`, co-workers=`1`, watchman=`1`, base=`main`.

## Step 1 — Verify kingdom-init has been run

Run:
```bash
ls "$PWD/.kingdom/.setting/" 2>/dev/null && echo "SETTING_EXISTS" || echo "SETTING_MISSING"
```

If `SETTING_MISSING`, tell the user:

> `.kingdom/.setting/` not found. Run `/kingdom-init` first to scaffold the role docs, then retry.

Stop. Do not continue.

## Step 2 — Check for existing kingdom.json

Run:
```bash
ls "$PWD/.kingdom/${project}/kingdom.json" 2>/dev/null && echo "JSON_EXISTS" || echo "JSON_MISSING"
```

If `JSON_EXISTS`, show the existing content:
```bash
cat "$PWD/.kingdom/${project}/kingdom.json"
```

Then ask the user:

> `.kingdom/<project>/kingdom.json` already exists (shown above). Overwrite with the new values? (yes/no)

Wait for confirmation before continuing. If `JSON_MISSING`, continue without asking.

## Step 3 — Read the template

Run:
```bash
cat "${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"
```

Read and hold the template content in memory.

## Step 4 — Substitute values and build the output JSON

Use `jq` to substitute the parsed argument values into the template. Run:

```bash
jq \
  --argjson workers    "${workers}" \
  --argjson coworkers  "${co-workers}" \
  --argjson watchman   "${watchman}" \
  --arg     base       "${base}" \
  '
    .shape.workers    = $workers   |
    .shape["co-workers"] = $coworkers |
    .shape.watchman   = $watchman  |
    .base             = $base
  ' \
  "${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"
```

Show the resulting JSON to the user before writing anything.

## Step 5 — Show diff / planned write and confirm

Tell the user what will be written:

> Will write the JSON above to `.kingdom/<project>/kingdom.json`. Proceed? (yes/no)

Wait for confirmation.

## Step 6 — Write the file

Create the project directory if needed, then write the file and ensure sibling directories exist:

```bash
mkdir -p "$PWD/.kingdom/${project}"
jq \
  --argjson workers    "${workers}" \
  --argjson coworkers  "${co-workers}" \
  --argjson watchman   "${watchman}" \
  --arg     base       "${base}" \
  '
    .shape.workers    = $workers   |
    .shape["co-workers"] = $coworkers |
    .shape.watchman   = $watchman  |
    .base             = $base
  ' \
  "${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template" \
  > "$PWD/.kingdom/${project}/kingdom.json"

mkdir -p "$PWD/.kingdom/${project}/tasks"
mkdir -p "$PWD/.kingdom/${project}/logs"
```

## Step 7 — Print the written file for review

Run:
```bash
cat "$PWD/.kingdom/${project}/kingdom.json"
```

Print the output so the user can verify.

## Step 8 — Suggest the next step

Tell the user:

> Done. Next: edit `.kingdom/<project>/kingdom.json` to set per-worker `focus` + `ownsPaths` and the `gate.*` command lists for your project's stack. Then run `/kingdom-start <project>` to spawn the kingdom. Lane masters will create task files in `.kingdom/<project>/tasks/` as work is assigned.
