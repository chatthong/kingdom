# cmux.md — How the kingdom uses manaflow/cmux.app

> **Canonical cmux reference for every role.** King, Workers, Co-workers, Watchmen, and Sub-agents all read this when they need to know how to spawn, dispatch, notify, or close something in cmux.app. If you're looking up a cmux command, look here first.

This is the kingdom's slice of cmux's API — only the commands the roles actually use, with the exact invocations + when each applies. For the full cmux command surface, see `cmux --help` or `cmux docs api`.

Target version: **manaflow/cmux ≥ 0.64.6**. Not to be confused with `craigsc/cmux` (a different worktree-CLI tool — kingdom does NOT use it).

---

## Three-tier hierarchy

```text
🪟 Window (cmux.app window — typically just 1 per kingdom)
└── 🏢 Workspace per master    ← role-level container, sidebar entry
    ├── 📑 Tab                  ← visible sub-agent spawn (auto-close on sentinel)
    │   └── 📑 Tab              ← more sub-agents if needed
    └── 🪟 Split                ← predefined dual-view (watchman top/bottom)
```

| Tier | Who uses it | Lifetime | Purpose |
|---|---|---|---|
| 🏢 Workspace | 👑 King + every 👷 Worker + 🧑‍💼 Co-worker + 🕵️ Watchman | Long-lived — persists across sessions | One Claude session per role |
| 📑 Tab | 🐱 visible sub-agents inside a master's workspace | Short-lived — auto-close on sentinel flag | Watchable execution; debugging |
| 🪟 Split | Watchman's dual monitoring view; optional paired-coworker editor | Same as workspace | Two views in one workspace |

**Default sub-agent spawn mode = `Agent(...)` (headless, no UI).** Tabs are opt-in for visibility.

---

## Command index — quick lookup

| Need to | Command | Section |
|---|---|---|
| Spawn a master workspace | `cmux new-workspace --name … --cwd … --command "claude"` | [§ Spawn workspace](#spawn-a-workspace) |
| Spawn a visible sub-agent tab | `cmux tab-action --action new-terminal-right --workspace <master-ws>` | [§ Spawn tab](#spawn-a-tab) |
| Spawn a split inside a workspace | `cmux new-split <left\|right\|up\|down>` OR `--layout` at workspace creation | [§ Spawn split](#spawn-a-split) |
| Send a prompt/command to a target | `cmux send --workspace <ref>` or `--surface <ref> --` `<text>` + `Enter` | [§ Send](#send-a-prompt-or-command) |
| Rename a tab/workspace | `cmux rename-tab --surface <ref> -- "<title>"` | [§ Rename](#rename) |
| Close own tab (5-step closer Step 5) | `cmux tab-action --action close --surface "$CMUX_SURFACE_ID"` | [§ Close tab](#close-own-tab) |
| Send notification | `cmux notify --workspace <ref> --title --body` | [§ Notify](#notify) |
| Identify current context | `cmux identify --json` | [§ Identify](#identify) |
| List/inspect topology | `cmux tree --all` or `cmux list-panes --workspace <ref> --json` | [§ Inspect](#inspect-topology) |
| Pin King's workspace at top of sidebar | `cmux tab-action --action pin --workspace <ref>` | [§ Pin](#pin-a-workspace) |

---

## Environment variables (auto-set inside cmux terminals)

Every Claude Code session spawned by cmux has these set automatically:

| Variable | What it holds | Used by |
|---|---|---|
| `CMUX_WORKSPACE_ID` | This session's workspace ref (e.g., `workspace:7`) | Default `--workspace` for every `cmux` subcommand |
| `CMUX_TAB_ID` / `CMUX_SURFACE_ID` | This session's tab/surface ref (e.g., `surface:12`) | Default `--surface`; required for `cmux tab-action --action close` (the auto-close in sub-agent Step 5) |
| `CMUX_CLAUDE_PID` | Process ID of this Claude session | `/kingdom:doctor` Check 1 (confirms PRIMARY mode) |
| `CMUX_SOCKET_PATH` | Optional override for the cmux Unix socket | Rarely needed |

When you need to address THIS session, `$CMUX_WORKSPACE_ID` and `$CMUX_SURFACE_ID` are the canonical refs.

---

## Spawn a workspace

The kingdom's primary spawn primitive — one workspace per master.

```bash
cmux new-workspace \
  --name "👷 worker-1" \
  --description "Kingdom lane · worker-1 · 2026-05-18T02:00Z" \
  --cwd "$PROJ/.worktrees/worker-1" \
  --command "claude" \
  --focus false
# Returns: "OK workspace:N" — capture with `| awk '/workspace:/ {print $2}'`
```

| Flag | Effect |
|---|---|
| `--name` | Workspace title — set with the role emoji prefix (👑 / 👷 / 🧑‍💼 / 🕵️). Shows in sidebar. |
| `--description` | Optional secondary text. Set to current task ID for at-a-glance progress (e.g., "BE-AUTH-3 · layer 3/4"). |
| `--cwd` | Working directory. **Always the worktree path** for the lane. |
| `--command` | Text + Enter sent after workspace creation. `"claude"` auto-launches Claude in the new workspace. |
| `--focus false` | Don't steal focus from King's workspace (default). Set `true` for the King's own context (rare). |
| `--layout '<json>'` | Inline layout JSON for predefined splits — see [§ Spawn split](#spawn-a-split). Conflicts with `--command` (layout defines its own commands). |

### Capture the returned ref

```bash
WORKER_WS_1=$(cmux new-workspace \
  --name "👷 worker-1" \
  --cwd "$PROJ/.worktrees/worker-1" \
  --command "claude" \
  --focus false \
  | awk '/workspace:/ {print $2}')
# WORKER_WS_1 is now something like "workspace:7"
```

Persist captured refs to `<LOGS>/workspace-refs.env` so the King + watchman can address lanes by stable refs across session restarts.

---

## Spawn a tab

Visible sub-agent spawn inside a master's workspace. Default for sub-agents is `Agent(...)` (headless); spawn a tab only when visibility matters.

```bash
RESULT=$(cmux tab-action \
  --action new-terminal-right \
  --workspace "$CMUX_WORKSPACE_ID" \
  --surface "$CMUX_SURFACE_ID" \
  --focus false)
# RESULT like: "OK action=new_terminal_right tab=tab:N workspace=workspace:M created=tab:14"
TAB_REF=$(echo "$RESULT" | grep -oE 'created=[a-z]+:[0-9]+' | cut -d= -f2)
SURFACE="surface:${TAB_REF##*:}"

cmux rename-tab --surface "$SURFACE" -- "🐱 sub · Sonnet · code"

cmux send --surface "$SURFACE" -- "cd $PROJ/.worktrees/worker-1 && claude --model sonnet -p \"\$(cat /tmp/brief.txt)\""
cmux send --surface "$SURFACE" Enter
```

The sub-agent's 4-step closer is extended to **5 steps** (the 5th closes its own tab — see [§ Close own tab](#close-own-tab)). Master doesn't need to clean up.

---

## Spawn a split

Two ways to get a split inside a workspace:

### At workspace creation (predefined layout — recommended for Watchman)

```bash
cmux new-workspace \
  --name "🕵️ watchman-1" \
  --cwd "$PROJ/.worktrees/watchman-1" \
  --layout '{
    "direction": "vertical",
    "split": 0.6,
    "children": [
      { "pane": { "surfaces": [{ "type": "terminal", "command": "claude" }] } },
      { "pane": { "surfaces": [{ "type": "terminal", "command": "gh pr list --watch --interval 30" }] } }
    ]
  }' \
  --focus false
```

Top pane runs Claude (the /loop session); bottom pane runs a live PR-state monitor. Both spawn together; the workspace owns both panes.

### Post-creation split (optional — for paired co-worker editor)

```bash
cmux new-split right \
  --workspace "$COWORKER_WS_1" \
  --focus false
```

Adds a pane to the existing workspace. Useful when user says "pair on co-worker-1 with my editor visible" — but not part of kingdom's default flow.

### Split directions

- `cmux new-split left`  — pane to the left
- `cmux new-split right` — pane to the right
- `cmux new-split up`    — pane above
- `cmux new-split down`  — pane below

---

## Send a prompt or command

Address by workspace ref (most common) or surface ref (more precise).

```bash
# Send to a workspace (auto-targets its focused/active surface)
cmux send --workspace "$WORKER_WS_1" -- "<task brief text>"
cmux send --workspace "$WORKER_WS_1" Enter

# Send to a specific surface (multi-tab workspaces — needed for tab-spawned sub-agents)
cmux send --surface "$SURFACE_REF" -- "<text>"
cmux send --surface "$SURFACE_REF" Enter
```

**Always two calls** — one for the literal text (`--` separator avoids shell-arg confusion), one for the Enter keystroke. This matches manaflow's API; collapsing them into one call doesn't work.

Special keys: `Enter`, `C-l` (Ctrl-L, clear), `C-c` (Ctrl-C), etc. — sent positionally without `--`.

---

## Rename

```bash
# Rename a tab/workspace by surface ref
cmux rename-tab --surface "$SURFACE_REF" -- "👷 worker-1 (BE-AUTH-3)"

# Rename a workspace by workspace ref
cmux tab-action --action rename --workspace "$WORKER_WS_1" --title "👷 worker-1 (BE-AUTH-3)"
```

Useful for showing live task progress: as the worker moves through layers, rename to reflect (`"👷 worker-1 (BE-AUTH-3 · L3/4)"`). Reverts to plain `"👷 worker-1"` at task completion via the closer.

---

## Close own tab

Mandatory 5-step closer step for tab-spawned sub-agents. **Only run inside a tab-spawned context** — `$CMUX_SURFACE_ID` is auto-set there.

```bash
# Step 5 of the 5-step closer (workers.md → "5-step closer for tab-spawned sub-agents")
cmux tab-action --action close --surface "$CMUX_SURFACE_ID"
```

For Agent-spawned sub-agents (the default — headless), there's no tab to close; `$CMUX_SURFACE_ID` won't be set in the Agent process context. Step 5 becomes a no-op.

To close a workspace entirely (rare — kingdom teardown):

```bash
cmux tab-action --action move-to-new-workspace --workspace "$STALE_WS"  # move it out
# Then in the new isolated workspace, close-others
cmux tab-action --action close-others --workspace <isolated>
```

Or manually right-click the workspace in cmux.app sidebar → "Close Workspace".

---

## Notify

Native cmux.app notifications. Kingdom uses this for cross-workspace alerts (Watchman → King; King → Ter on push-ready, gate-pass).

```bash
cmux notify \
  --workspace "$KING_WS" \
  --title "🕵️ watchman-1" \
  --subtitle "develop RED" \
  --body "Smoke broke on origin/develop a1b2c3d4. Lanes paused pending King review."
```

| Flag | Effect |
|---|---|
| `--workspace` | Where the notification appears (typically `$KING_WS` so Ter sees it). |
| `--title` | Bold header (prefix with role emoji). |
| `--subtitle` | Secondary line (use for the type of event). |
| `--body` | Main text (one short paragraph). |

Watchman uses `cmux notify --workspace "$KING_WS"` for develop-RED, CI-fail, PR-mergeable alerts. King uses `cmux notify --workspace "$KING_WS"` to surface "push?" prompts when in a different workspace context.

---

## Identify

Find out what context you're running in:

```bash
cmux identify --json
# Returns:
# {
#   "caller": { "workspace_ref": "workspace:7", "surface_ref": "surface:12", ... },
#   "focused": { ... },
#   "socket_path": "/Users/ter/Library/Application Support/cmux/cmux.sock"
# }
```

Useful when scripts need to introspect their own context (which workspace/surface they're in) without relying on env vars.

---

## Inspect topology

```bash
cmux tree --all                              # full tree of windows, workspaces, panes, surfaces
cmux list-panes --workspace workspace:7 --json
cmux list-panes --workspace workspace:7 --json | jq '[.panes[] | {ref, surface_refs, focused}]'
```

The kingdom uses `cmux tree --all` in `/kingdom:doctor` and on resume to verify the expected workspaces are still alive.

---

## Pin a workspace

Pin = workspace stays at the top of the cmux.app sidebar. Kingdom pins the King's workspace by default (controlled by `kingdom.json.cmux.pinKingWorkspace`).

```bash
cmux tab-action --action pin --workspace "$KING_WS"

# Unpin
cmux tab-action --action unpin --workspace "$KING_WS"
```

---

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `cmux claude-teams` errors with prompt required | `claude-teams` is a thin pass-through to `claude --print`, which needs input. Kingdom doesn't use it. | Use `cmux new-workspace --command "claude"` per lane instead. |
| `Tab not found` from `cmux tab-action` | Missing `--surface` or `--tab` flag when `$CMUX_SURFACE_ID` isn't set | Pass `--surface "$CMUX_SURFACE_ID"` explicitly, or use `--workspace <ref>` if targeting a whole workspace |
| Workspace ref drifts after restart | Workspace refs are NOT stable across cmux.app restarts | Kingdom persists refs to `<LOGS>/workspace-refs.env` and re-reads on `/kingdom:start` resume — but if cmux.app was force-quit, refs may need rebuilding. Doctor Check 1 flags this. |
| Sub-agent tab doesn't close | The sub-agent's process didn't run Step 5 (`cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`) | Verify `$CMUX_SURFACE_ID` was set when the sub-agent launched — if not, the spawn went through `Agent(...)` not `cmux tab-action`, and there's no tab to close |
| `cmux send` doesn't trigger Enter | You sent the prompt with `--` separator but forgot the second `cmux send … Enter` call | Always two calls: text, then Enter |

---

## Reference

- Full cmux CLI contract: `curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md`
- cmux skill (for AI agents): `curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills/cmux/SKILL.md`
- Web docs: <https://cmux.com/docs/api>

This file is the kingdom's curated subset — narrower than the full cmux API, but covers everything the King + masters + sub-agents actually use.
