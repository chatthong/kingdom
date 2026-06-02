---
description: Migrate a kingdom workspace to the freshly-updated plugin — re-sync the kit (.setting/), additively merge each project's kingdom.json, preserve ALL runtime (tasks/logs/state) and memory. Use after updating the kingdom plugin from Claude.
argument-hint: "[project]   # omit = migrate the whole workspace (all projects)"
---

You are migrating an EXISTING kingdom workspace to the version of the plugin currently installed (e.g. after Claude updated the `kingdom` plugin from the marketplace). This is **not** `/kingdom:init` — `init` scaffolds a fresh workspace; `update` upgrades a live one **without losing session state or memory.**

The whole safety model is three categories, treated completely differently:

| Category | What | Action |
|---|---|---|
| **Shape** (the kit) | `.kingdom/.setting/` — rules / roles / functions (incl. `cmux/`) / reference / cards / `index.md` / `manifest.json` | **clean-replace** from the plugin (backup → fresh install). Removes files deleted upstream; your local hand-patches survive in the timestamped `.bak`. |
| **Config** (per project) | `.kingdom/<project>/kingdom.json` | **additive merge** — new schema keys are added; **every existing value wins** (your tuned shape, per-lane models, gate commands are kept). Backed up first. |
| **Runtime** (sacred) | `<project>/tasks/`, `<project>/logs/` (incl. `master_agent.log`, `done/`, `raw/`, `watch/`, `king-inbox/`), `state.json`, `watchman_state.json` | **never touched.** |
| **Memory** | `~/.claude/projects/<…>/memory/` (`MEMORY.md` + the per-fact files) | lives OUTSIDE the workspace → **structurally impossible to touch here.** Stated in the report for reassurance. |

Follow every step in order. **Preview the full delta and get one explicit `update` confirmation before any write.** Every write makes a timestamped backup first.

## Step 0 — Preflight + version detection

```bash
SRC="${CLAUDE_PLUGIN_ROOT}/.kingdom/.setting"
DST="$PWD/.kingdom/.setting"
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/.kingdom/templates/kingdom.json.template"

# Must be an existing kingdom workspace.
[ -d "$DST" ] || { echo "❌ No .kingdom/.setting/ here. This is for upgrading an EXISTING workspace — run /kingdom:init first."; exit 0; }

NEW_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
CUR_VERSION=$(cat "$DST/.kingdom-version" 2>/dev/null || echo "unknown (pre-0.38.0 — no stamp)")
echo "Kingdom workspace update:  $CUR_VERSION  →  $NEW_VERSION"
```

If `CUR_VERSION` == `NEW_VERSION`, tell the user the kit is already current and ask whether to re-sync anyway (e.g. to discard local edits to `.setting/`). On `no`, stop. Otherwise continue.

Parse the optional `project` arg and compute the config-migration scope ONCE — Steps 2, 3, and 5b all reuse `$SCOPE_PROJECTS`. If a `project` is given, only that project's `kingdom.json` is migrated; otherwise every `.kingdom/<p>/kingdom.json`. The shape re-sync (Step 1/5a) is workspace-wide regardless.

```bash
if [ -n "$project" ]; then
  SCOPE_PROJECTS="$PWD/.kingdom/$project/kingdom.json"     # one project
  [ -f "$SCOPE_PROJECTS" ] || { echo "❌ no .kingdom/$project/kingdom.json — nothing to migrate for that project"; SCOPE_PROJECTS=""; }
else
  SCOPE_PROJECTS=$(find "$PWD/.kingdom" -maxdepth 2 -name kingdom.json 2>/dev/null)   # all projects
fi
```

## Step 1 — Preview the shape delta (the kit)

```bash
echo "=== .setting/ changes (workspace → plugin v$NEW_VERSION) ==="
diff -rq "$DST" "$SRC" 2>/dev/null \
  | grep -v '/\.kingdom-version' \
  | sed "s#$DST#workspace#g; s#$SRC#plugin#g"
echo
echo "changed:        $(diff -rq "$DST" "$SRC" 2>/dev/null | grep -c '^Files')"
echo "new upstream:   $(diff -rq "$DST" "$SRC" 2>/dev/null | grep -c "Only in $SRC")"
echo "only here:      $(diff -rq "$DST" "$SRC" 2>/dev/null | grep -c "Only in $DST")  (removed-upstream OR your local patches — preserved in the .bak)"
```

Read this back to the user in plain English: how many kit files will be refreshed, how many are new in this version, and how many exist only in their workspace (either deleted upstream or local hand-edits — both are preserved in the backup, but the live tree will match the plugin after update). If any "only here" file looks like a deliberate local patch (e.g. a hand-edited `roles/*.md`), name it so the user knows it'll be replaced by the plugin's version (their copy stays in the `.bak`).

## Step 2 — Preview the config migration (per project)

For each in-scope `kingdom.json`, show exactly which keys the additive merge would ADD (nothing is removed or overwritten):

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $SCOPE_PROJECTS (all-projects scope is newline-separated from find → else 1 iteration over the whole blob); auto-reverts
for KJSON in $SCOPE_PROJECTS; do                          # scope from Step 0 (one project or all)
  proj=$(basename "$(dirname "$KJSON")")
  echo "=== $proj: keys the merge would ADD (existing values untouched) ==="
  comm -13 \
    <(jq -r 'paths(scalars) | join(".")' "$KJSON"        | sort -u) \
    <(jq -r 'paths(scalars) | join(".")' "$TEMPLATE"     | sort -u) \
    | grep -v '_comment\|_unitComment\|_spawnWindowComment\|_subAgentSpawnFallbackComment' \
    || echo "  (none — config already has every current schema key)"
done
```

Report per project: the list of keys to be added (e.g. `integration.*`, `shape.seniors`, `subAgents.*`). Make clear NO existing value changes — this is purely additive (`jq -s '.[0] * .[1]'`, template as base, the project's own values win on every overlap).

## Step 3 — State + memory preservation manifest

Show the user, explicitly, what is **NOT** touched:

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $SCOPE_PROJECTS (else 1 iteration over the whole blob); auto-reverts
for KJSON in $SCOPE_PROJECTS; do
  proj=$(basename "$(dirname "$KJSON")")
  d="$PWD/.kingdom/$proj"
  echo "PRESERVED · $proj: tasks=$(ls "$d/tasks" 2>/dev/null | wc -l | tr -d ' ') file(s), logs=$(ls "$d/logs" 2>/dev/null | wc -l | tr -d ' ') file(s), state.json=$([ -f "$d/state.json" ] && echo present || echo none)"
done
echo "PRESERVED · memory: ~/.claude/projects/<…>/memory/ is outside this workspace — never read or written by /kingdom:update."
```

## Step 4 — Confirm

Present the full preview as one block — shape delta, per-project keys-to-add, preserved runtime, "memory untouched" — then ask:

> Apply this update? Type `update` to proceed. (Every change is backed up first: `.setting/` → `.setting.bak-<ts>`, each `kingdom.json` → `kingdom.json.bak-<ts>`. Your `tasks/`, `logs/`, `state.json`, and memory are not touched.)

Wait for the literal `update`. Anything else → stop, change nothing.

## Step 5 — Apply

### 5a — Re-sync the kit (clean-replace, K9)

```bash
BAK="$DST.bak-$(date -u +%Y%m%d-%H%M%S)"
mv "$DST" "$BAK"
echo "Backed up old kit → $(basename "$BAK")"
# Copy as an all-or-nothing unit: if ANY step fails, restore the backup so the
# live workspace is never stranded with a half-written (or absent) .setting/.
if ! (
  set -e
  mkdir -p "$DST/roles" "$DST/reference" "$DST/rules" "$DST/functions" "$DST/cards"
  cp "$SRC/index.md"       "$DST/index.md"
  cp "$SRC/manifest.json"  "$DST/manifest.json"
  cp "$SRC/rules.md"       "$DST/rules.md"
  cp "$SRC/_primitives.md" "$DST/_primitives.md"
  cp "$SRC/roles/"*.md     "$DST/roles/"
  cp "$SRC/reference/"*.md "$DST/reference/"
  cp "$SRC/rules/"*.md     "$DST/rules/"
  cp -R "$SRC/functions/." "$DST/functions/"     # -R carries the cmux/ backend subfolder
  cp "$SRC/cards/"*.md     "$DST/cards/"
  echo "$NEW_VERSION" > "$DST/.kingdom-version"  # stamp so future updates detect drift
); then
  echo "❌ kit copy failed — restoring backup, workspace left unchanged" >&2
  rm -rf "$DST"; mv "$BAK" "$DST"
  exit 1
fi
echo "Kit re-synced to v$NEW_VERSION ($(find "$DST" -type f | wc -l | tr -d ' ') files)"
```

### 5b — Additively merge each project's kingdom.json (K8)

```bash
[ -n "${ZSH_VERSION:-}" ] && emulate -L sh 2>/dev/null  # zsh: word-split $SCOPE_PROJECTS (else 1 iteration over the whole blob); auto-reverts
# $SCOPE_PROJECTS was set in Step 0 (one project if a `project` arg was given, else all).
for KJSON in $SCOPE_PROJECTS; do
  proj=$(basename "$(dirname "$KJSON")")
  cp "$KJSON" "$KJSON.bak-$(date -u +%Y%m%d-%H%M%S)"
  tmp=$(mktemp)
  jq -s '.[0] * .[1]' "$TEMPLATE" "$KJSON" > "$tmp" && mv "$tmp" "$KJSON"   # template base, existing wins
  echo "Merged new schema keys into $proj/kingdom.json (existing values preserved; .bak written)"
done
```

### 5c — Re-sync `.claude/settings.json` permissions (same additive merge as `/kingdom:init` Step 3)

Run the identical `permissions.allow` merge from [`init.md`](init.md) Step 3 — additive + `unique`, so a newly-required permission entry for this version is added without disturbing the user's existing allow list. Skip if already complete.

> Do NOT touch `~/.claude/settings.json` hooks here — a malformed hook is the user's environment (see the K5 note in the v0.37.0 CHANGELOG), not a plugin concern.

## Step 6 — Report (`cards/update-report.md`)

```bash
export CUR_VERSION NEW_VERSION
export N_KIT_FILES=$(find "$DST" -type f | wc -l | tr -d ' ')
export N_PROJECTS=$(echo "$SCOPE_PROJECTS" | grep -c kingdom.json)
export KIT_BAK=$(basename "$BAK")
render_card "update-report"
```

Then suggest: run `/kingdom:self-care` to verify the migrated kit — its **Check 13** also flags any project-memory note that snapshots kingdom mechanics or names an older version (a v0.36-era memory describing now-fixed bugs would otherwise mislead the King post-migration, per R34). It's read-only; you review and nuke. Then resume normally with `/kingdom:work <project>` — in-flight tasks, the resume queue (R33), and all audit history are exactly as they were.

## What this command never does

- Never deletes or edits anything under `<project>/tasks/`, `<project>/logs/`, `state.json`, `watchman_state.json`, or `king-inbox/`.
- Never reads or writes `~/.claude/projects/<…>/memory/` (it's outside the workspace).
- Never commits, pushes, or runs gates (R1 — pushing is always the human's explicit word, and only inside `/kingdom:work`).
- Never overwrites a `kingdom.json` value the user set — only adds missing keys. (To reset a project to defaults instead, use `/kingdom:init <project>` and choose `overwrite`.)
