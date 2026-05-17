---
description: Scaffold .kingdom/.setting/ in the current workspace with the kingdom role docs
---

You are scaffolding the kingdom role docs into the current workspace. Follow every step in order. Show planned changes and ask for confirmation before any file write or overwrite.

## Step 1 — Verify this is a workspace root

Run:
```bash
ls "$PWD/.git" 2>/dev/null && echo "GIT_FOUND" || echo "GIT_NOT_FOUND"
```

If the output is `GIT_FOUND`, warn the user:

> Warning: `$PWD/.git/` exists. Kingdom workspaces are NOT git repos — their sub-projects have their own `.git/`. This looks like a project directory, not a workspace root. Proceed anyway? (yes/no)

Wait for the user to confirm before continuing. If `GIT_NOT_FOUND`, continue without asking.

## Step 2 — Check for existing installation

Run:
```bash
ls "$PWD/.kingdom/.setting/" 2>/dev/null && echo "SETTING_EXISTS" || echo "SETTING_MISSING"
```

If `SETTING_EXISTS`, list what is there:
```bash
ls -1 "$PWD/.kingdom/.setting/"
```

Then ask the user:

> `.kingdom/.setting/` already exists with the files listed above. Overwrite? (yes/no)

Wait for confirmation before continuing. If `SETTING_MISSING`, continue without asking.

## Step 3 — Create the directory

Run:
```bash
mkdir -p "$PWD/.kingdom/.setting/"
```

## Step 4 — Copy the 6 role docs from the plugin

Run:
```bash
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/index.md"      "$PWD/.kingdom/.setting/index.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/kings.md"      "$PWD/.kingdom/.setting/kings.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/workers.md"    "$PWD/.kingdom/.setting/workers.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/co-workers.md" "$PWD/.kingdom/.setting/co-workers.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/watchmans.md"  "$PWD/.kingdom/.setting/watchmans.md"
cp "${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting/git.md"        "$PWD/.kingdom/.setting/git.md"
```

## Step 5 — Report what was created

For each file, print its path and line count:
```bash
wc -l \
  "$PWD/.kingdom/.setting/index.md" \
  "$PWD/.kingdom/.setting/kings.md" \
  "$PWD/.kingdom/.setting/workers.md" \
  "$PWD/.kingdom/.setting/co-workers.md" \
  "$PWD/.kingdom/.setting/watchmans.md" \
  "$PWD/.kingdom/.setting/git.md"
```

Report the results in a plain list, for example:

```
Created:
  .kingdom/.setting/index.md       (42 lines)
  .kingdom/.setting/kings.md       (38 lines)
  .kingdom/.setting/workers.md     (61 lines)
  .kingdom/.setting/co-workers.md  (29 lines)
  .kingdom/.setting/watchmans.md   (33 lines)
  .kingdom/.setting/git.md         (55 lines)
```

## Step 6 — Suggest the next step

Tell the user:

> Done. Next: run `/kingdom-new <project-name>` to create a `kingdom.json` for a specific project, then `/kingdom-doctor` to verify your machine is set up correctly.
