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
| Rename a **workspace** (sidebar label) | `cmux workspace-action --action rename --workspace <ref> --title "…"` | [§ Rename](#rename) |
| Rename a **surface** (tab inside a workspace) | `cmux tab-action --action rename --surface <ref> --title "…"` | [§ Rename](#rename) |
| Set workspace color / description | `cmux workspace-action --action set-color\|set-description …` | [§ Set workspace color + description](#set-workspace-color--description) |
| Close own tab (5-step closer Step 5) | `cmux tab-action --action close --surface "$CMUX_SURFACE_ID"` | [§ Close tab](#close-own-tab) |
| Send notification | `cmux notify --workspace <ref> --title --body` | [§ Notify](#notify) |
| Identify current context | `cmux identify --json` | [§ Identify](#identify) |
| List/inspect topology | `cmux tree --all` or `cmux list-panes --workspace <ref> --json` | [§ Inspect](#inspect-topology) |
| Pin a workspace at top of sidebar | `cmux workspace-action --action pin --workspace <ref>` | [§ Pin](#pin-a-workspace) |

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

**Two distinct commands** — pick the one that matches what you want renamed:

| Command | What it renames | Use case |
|---|---|---|
| `cmux workspace-action --action rename --workspace <ws> --title "…"` | **Workspace itself** (sidebar label) | Setting the role-level identity: `👑 King · bfg-swt`, `👷 worker-1` |
| `cmux tab-action --action rename --surface <ref> --title "…"` | **Inner surface** (tab label inside a workspace) | Setting per-tab labels when a workspace has multiple tabs (e.g., `🐱 sub · Sonnet · code`) |
| `cmux rename-tab --surface <ref> -- "…"` | Same as `tab-action --action rename` (alias) | Convenience |

```bash
# Workspace-level rename (sidebar label)
cmux workspace-action --action rename --workspace "$WORKER_WS_1" --title "👷 worker-1 (BE-AUTH-3)"

# Surface-level rename (tab label inside the workspace)
cmux tab-action --action rename --surface "$SURFACE_REF" --title "🐱 sub · Sonnet · code"
```

**Common mistake:** using `tab-action --action rename --workspace <ws>` to rename the workspace itself — that actually renames the focused tab in workspace context, not the workspace's name. Always use `workspace-action` for sidebar identity.

Useful for showing live task progress: as the worker moves through layers, rename the workspace to reflect (`workspace-action ... --title "👷 worker-1 (BE-AUTH-3 · L3/4)"`). Reverts to plain `"👷 worker-1"` at task completion via the closer.

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

## Notification system

cmux.app has a rich notification UX. Three visible surfaces:

| Visual | Triggered by | What user sees |
|---|---|---|
| 🔵 **Blue ring on a pane / tab lights up** | `cmux notify --surface <ref>` | Pane border ring + tab title highlights. Best for "this pane needs attention now." |
| 🔔 **Sidebar badge on workspace entry** | `cmux notify --workspace <ref>` | Workspace card shows numbered badge in the sidebar + dot indicator. Best for "this lane has news." |
| 📋 **Notification panel (bell icon)** | Both above | Click the bell at the top of the sidebar — shows scrollable list of all unread notifications across workspaces. Jump to most-recent with one click. |

**Most events use BOTH `--surface` AND `--workspace`** so the originating pane shows a ring AND the destination (typically the King's workspace) gets a sidebar badge. Two calls, two visual cues, one event.

```bash
cmux notify \
  --workspace "$KING_WS" \
  --title "🕵️ watchman-1" \
  --subtitle "develop RED" \
  --body "Smoke broke on origin/develop a1b2c3d4. Lanes paused pending King review."
```

| Flag | Effect |
|---|---|
| `--workspace <ref>` | Sidebar badge on this workspace + bell-panel entry. |
| `--surface <ref>` | Blue ring on this pane + tab light. (Targets a specific surface within a workspace.) |
| `--title` | Bold header. **Always prefix with role emoji** (👑/👷/🧑‍💼/🕵️/🐱). |
| `--subtitle` | Secondary line. Use for event class ("done", "develop RED", "CI failed", "push?"). |
| `--body` | Main text — one short paragraph or sentence. |

### Kingdom notification schema (canonical events)

| Who | When | `--surface` | `--workspace` | Title | Subtitle |
|---|---|---|---|---|---|
| 👷 Worker / 🧑‍💼 Co-worker | 4-step closer Step 4 (sentinel just written) | own (`$CMUX_SURFACE_ID`) | `$KING_WS` | `👷 worker-N done` / `🧑‍💼 co-worker-N done` | `<sub-task-id>` |
| 🐱 Tab sub-agent | 5-step closer Step 4 (before Step 5 self-close) | own | parent master ws | `🐱 sub · <model> · <slug>` | `<sub-task-id>` |
| 🕵️ Watchman | develop RED detected | (skip) | `$KING_WS` | `🕵️ watchman-N` | `develop RED` |
| 🕵️ Watchman | CI fail on a kingdom PR | (skip) | `$KING_WS` | `🕵️ watchman-N` | `CI failed · PR #N` |
| 🕵️ Watchman | PR mergeable + green + approved + idle 30m | (skip) | `$KING_WS` | `🕵️ watchman-N` | `Ready to merge · PR #N` |
| 👑 King | Pre-commit gate FAIL | (skip) | originating master ws | `👑 King · gate FAIL` | `<lane> · <sub-task-id>` |
| 👑 King | Pre-commit gate PASS, asking "push?" | (skip) | `$KING_WS` | `👑 King · gate pass · push?` | `<lane> · <sub-task-id>` |
| 👑 King → `/kingdom:exit` | Session ending, 5s heads-up per lane | (skip) | each lane ws | `👑 kingdom:exit` | `Session ending` |

The schema keeps notifications scan-able in the bell panel: role emoji always in title, subtitle is the event class, body has the specific context.

### Targeting cheat-sheet

```bash
# This pane needs attention NOW (blue ring on the sender's own pane)
cmux notify --surface "$CMUX_SURFACE_ID" --title "👷 worker-1 done" --subtitle "BE-AUTH-3" --body "12 files, gates green"

# That workspace has news (sidebar badge — most common for cross-workspace alerts)
cmux notify --workspace "$KING_WS" --title "🕵️ watchman-1" --subtitle "develop RED" --body "Smoke broke on a1b2c3d4"

# Both — ring on me + badge on the King's sidebar
cmux notify --surface "$CMUX_SURFACE_ID" --workspace "$KING_WS" --title "👷 worker-1 done" --subtitle "BE-AUTH-3" --body "12 files"
```

### Notification panel

The bell icon at the top of cmux.app's sidebar shows the count of unread notifications across all workspaces. Click it to see the rolling list, click any entry to jump to the originating workspace/pane. Kingdom relies on this panel as the "what needs my attention" dashboard — no separate `/kingdom:status` UI needed (though that's coming in v0.16 for a CLI summary).

### What NOT to notify

Don't fire `cmux notify` for low-value events:

- ❌ Every `Bash` call a lane runs — too noisy
- ❌ Every git fetch — happens constantly
- ❌ Every sub-agent spawn — Agent(...) headless ones are silent by design; only tab-spawned ones notify on closer
- ❌ Periodic heartbeats from watchman — write to log only, no notify
- ❌ Mid-task progress per Layer — the closer event is the only checkpoint that notifies

Reserve notifications for events that change what Ter or the King would do next.

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

## Read pane contents (blocked-lane detection)

cmux exposes two ways to read what a surface is showing:

```bash
# Capture-pane — last N lines (and scrollback if requested)
cmux capture-pane --workspace "$WORKER_WS_1" --lines 30
cmux capture-pane --workspace "$WORKER_WS_1" --lines 100 --scrollback

# Read-screen — current screen (visible viewport only)
cmux read-screen --workspace "$WORKER_WS_1"
```

Watchman uses `capture-pane` every `/loop` tick to detect lanes blocked on interactive permission prompts. Pattern match `Do you want to proceed\?`, `Esc to cancel`, `\[y/N\]`, `allow .* during this session`, `Press Enter` → fire `cmux notify` so the user knows which lane needs attention (otherwise the lane silently stalls while cmux.app still reports it as "Running"). Full detail in [`watchmans.md`](watchmans.md) → § "Blocked-lane scan".

For pre-emption (preferred over detection), expand the workspace `.claude/settings.json` `permissions.allow` to include path-scoped entries for `.kingdom/**` and `.worktrees/**` so lanes can read/write within those without prompting. `/kingdom:doctor` Check 10 + `/kingdom:init` Step 4.5 both apply this expansion automatically.

---

## Pin a workspace

Pin = workspace stays at the top of the cmux.app sidebar. Kingdom pins the King's workspace by default (controlled by `kingdom.json.cmux.pinKingWorkspace`).

```bash
cmux workspace-action --action pin --workspace "$KING_WS"

# Unpin
cmux workspace-action --action unpin --workspace "$KING_WS"
```

> **Note:** `cmux tab-action --action pin --workspace <ws>` also works (cmux accepts either; tab-action falls through to workspace-action when the target is a workspace), but `workspace-action` is the canonical name for workspace-level ops.

## Set workspace color + description

Colors are visible per-workspace in cmux.app's sidebar (left-edge color bar). Use to distinguish roles at a glance.

```bash
# Color (named — case-insensitive)
cmux workspace-action --action set-color --workspace "$WORKER_WS_1" --color violet
cmux workspace-action --action set-color --workspace "$KING_WS"     --color amber

# Description (the smaller text under the workspace name in the sidebar)
cmux workspace-action --action set-description --workspace "$WORKER_WS_1" --description "BE-AUTH-3 · layer 3/4"

# Clear them
cmux workspace-action --action clear-color       --workspace "$WORKER_WS_1"
cmux workspace-action --action clear-description --workspace "$WORKER_WS_1"
```

Available named colors: **Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy, Indigo, Purple, Magenta, Rose, Brown, Charcoal**. Or pass a `#RRGGBB` hex.

Kingdom's default mapping (in `kingdom.json.cmux.workspaceColors`):

| Role | Color |
|---|---|
| 👑 King | `amber` |
| 👷 Worker | `violet` (alias `Purple`) |
| 🧑‍💼 Co-worker | `blue` |
| 🕵️ Watchman | `rose` |

The `new-workspace` command **does not accept `--color`** — set it via a second `workspace-action --action set-color` call right after creation.

## Dynamic workspace descriptions (live status line)

`set-description` is **idempotent and live** — the King + masters update their own workspace descriptions on every state transition, giving the sidebar a real-time activity line you can scan without clicking.

### State-emoji vocabulary (kingdom convention)

| Glyph | Meaning |
|---|---|
| `▶` | Running / active work in progress |
| `⏸` | Paused / waiting on dependency |
| `⚠` | Needs attention (gate fail, push prompt, blocked) |
| `✅` | Done / passed |
| `❌` | Failed |
| `🐾` | Idle / dormant / awaiting dispatch |
| `▰▰▰▱` | Progress bar (filled / empty squares for 4-layer multi-layer plan) |

### Description schema per role

```text
👑 King — state line:
   ▶ Gating worker-2 · BE-AUTH-3       (running pre-commit gate)
   ⚠ Push? · worker-2 · BE-AUTH-3      (gate passed, awaiting Ter)
   ✅ Pushed feature/auth-refactor 04Z  (after push complete)
   🐾 Idle · 3 lanes active             (no active King work)

👷 Worker — state line (long-lived, mirrors task file status):
   🐾 Awaiting dispatch                 (no claim)
   ▶ BE-AUTH-3 · ▰▱▱▱ L1 Discovery     (layer 1 of 4)
   ▶ BE-AUTH-3 · ▰▰▱▱ L2 Strategy
   ▶ BE-AUTH-3 · ▰▰▰▱ L3 Execution
   ▶ BE-AUTH-3 · ▰▰▰▰ L4 Verify
   ✅ BE-AUTH-3 done · sentinel written (between closer + next claim)
   ⚠ Blocked · permission prompt        (set by watchman blocked-lane scan)

🧑‍💼 Co-worker — state line:
   🐾 Dormant · activate with "pair on co-worker-1"
   ▶ UI-CHK-12 · Ter paired             (when Ter is actively pairing)
   ✅ UI-CHK-12 done · sentinel written
   ⚠ Blocked · permission prompt

🕵️ Watchman — state line (updates every /loop tick):
   ▶ develop green · 2 PRs open · last tick 02:30Z
   ⚠ develop RED · 1 PR blocked · 1 lane stuck
   ✅ All quiet · 0 PRs · last tick 02:30Z
```

### Update sites — when each role rewrites its description

| Role | Trigger | New description |
|---|---|---|
| 👑 King | Spawn / resume | `🐾 Idle · N lanes active` (or `Your conversation · pinned · <UTC>`) |
| 👑 King | Start pre-commit gate | `▶ Gating <lane> · <sub-task-id>` |
| 👑 King | Gate pass | `⚠ Push? · <lane> · <sub-task-id>` |
| 👑 King | Gate fail | `❌ Gate FAIL · <lane> · <sub-task-id>` |
| 👑 King | Pushed | `✅ Pushed feature/<topic> · <UTC>` (held for ~5 min then reverts to Idle) |
| 👷 Worker | Task claimed (Step 0 of task file) | `▶ <sub-task-id> · ▱▱▱▱ initialising` |
| 👷 Worker | Layer transition | `▶ <sub-task-id> · ▰▰▰▱ L<N> <name>` |
| 👷 Worker | Closer Step 4 (sentinel written) | `✅ <sub-task-id> done · sentinel written` |
| 👷 Worker | Next claim or 5-min idle | `🐾 Awaiting dispatch` |
| 🧑‍💼 Co-worker | Activated by Ter | `▶ <sub-task-id> · Ter paired` |
| 🧑‍💼 Co-worker | Deactivated | `🐾 Dormant · activate with "pair on co-worker-1"` |
| 🕵️ Watchman | Every `/loop` tick | `▶|⚠|✅ develop <state> · <N> PRs · last tick <UTC>` |
| Watchman (when scanning a blocked lane) | Sees blocked-lane pattern | Sets the *target lane's* description to `⚠ Blocked · permission prompt` |

### Bash helper for set-state

A common helper that lives in every role's prompt:

```bash
cmux_set_state () {
  local ws="$1" emoji="$2" text="$3"
  cmux workspace-action --action set-description \
    --workspace "$ws" \
    --description "$emoji $text" 2>/dev/null
  # Failures are silent — description is cosmetic; missing it doesn't block work.
}

# Usage examples:
cmux_set_state "$CMUX_WORKSPACE_ID" "▶" "BE-AUTH-3 · ▰▰▰▱ L3 Execution"
cmux_set_state "$KING_WS"           "⚠" "Push? · worker-2 · BE-AUTH-3"
cmux_set_state "$CMUX_WORKSPACE_ID" "🐾" "Awaiting dispatch"
```

### Why this matters

The cmux.app sidebar is the King's dashboard. With dynamic descriptions, Ter can glance at the sidebar and read a sentence per lane describing exactly what it's doing — without clicking any workspace. Combined with workspace colors (role) + native notifications (events) + workspace names (identity), the sidebar becomes a complete status surface.

### Description update is OPTIONAL but recommended

Description updates are nice-to-have, not load-bearing. If a role fails to update (cmux unreachable, transient error), work continues — the audit trail in `master_agent.log` + task files remains the source of truth. Description is the **visual surface** for the audit trail, not the audit trail itself.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Workspace renamed but sidebar still shows old name | Used `tab-action --action rename --workspace <ws>` — that renames the focused **surface** within workspace context, NOT the workspace's sidebar label | Use `workspace-action --action rename --workspace <ws> --title "…"` (the dedicated workspace-level command) |
| `cmux claude-teams` errors with prompt required | `claude-teams` is a thin pass-through to `claude --print`, which needs input. Kingdom doesn't use it. | Use `cmux new-workspace --command "claude"` per lane instead. |
| `Tab not found` from `cmux tab-action` | Missing `--surface` or `--tab` flag when `$CMUX_SURFACE_ID` isn't set | Pass `--surface "$CMUX_SURFACE_ID"` explicitly, or use `--workspace <ref>` if targeting a whole workspace |
| Workspace ref drifts after restart | Workspace refs are NOT stable across cmux.app restarts | Kingdom persists refs to `<LOGS>/workspace-refs.env` and re-reads on `/kingdom:start` resume — but if cmux.app was force-quit, refs may need rebuilding. Doctor Check 1 flags this. |
| Sub-agent tab doesn't close | The sub-agent's process didn't run Step 5 (`cmux tab-action --action close --surface "$CMUX_SURFACE_ID"`) | Verify `$CMUX_SURFACE_ID` was set when the sub-agent launched — if not, the spawn went through `Agent(...)` not `cmux tab-action`, and there's no tab to close |
| `cmux send` doesn't trigger Enter | You sent the prompt with `--` separator but forgot the second `cmux send … Enter` call | Always two calls: text, then Enter |
| `new-workspace` ignores `--color` | `cmux new-workspace` does NOT support `--color` — only `--name`, `--description`, `--cwd`, `--command`, `--layout`, `--window`, `--focus` | Set color in a separate call: `cmux workspace-action --action set-color --workspace <ref> --color violet` |

---

## Reference

- Full cmux CLI contract: `curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md`
- cmux skill (for AI agents): `curl -fsSL https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills/cmux/SKILL.md`
- Web docs: <https://cmux.com/docs/api>

This file is the kingdom's curated subset — narrower than the full cmux API, but covers everything the King + masters + sub-agents actually use.
