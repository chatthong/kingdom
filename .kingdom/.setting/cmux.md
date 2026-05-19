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
| Close a whole **workspace** (kingdom teardown) | `cmux close-workspace --workspace <ref>` | [§ Teardown / close commands](#teardown--close-commands) |
| Close a **surface** (single tab/pane) | `cmux close-surface --surface <ref>` | [§ Teardown / close commands](#teardown--close-commands) |
| Close an entire **window** | `cmux close-window --window <ref>` | [§ Teardown / close commands](#teardown--close-commands) |
| Send notification | `cmux notify --workspace <ref> --title --body` | [§ Notification system](#notification-system) |
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

To close a workspace entirely (kingdom teardown — `/kingdom:exit`), use the canonical `close-workspace` command — NOT `tab-action --action close` (which targets a single surface, not the workspace):

```bash
cmux close-workspace --workspace "$STALE_WS"
```

See [§ Teardown / close commands](#teardown--close-commands) below for the full close-* family.

---

## Multi-window cmux.app (v0.27.0+)

Confirmed working in 8-window setups. Key facts:

| Fact | Implication |
|---|---|
| `cmux identify --json` returns `window_ref` for caller | King knows which window it's anchored to |
| `cmux current-window` returns UUID of **focused** window (≠ caller's process window) | "Focused" and "caller's" diverge when user clicks around |
| `cmux new-workspace` without `--window` → lands in **caller's process window** (where the calling shell lives, via `$CMUX_WORKSPACE_ID`) | Default: lanes glued to King's session, not to user's UI focus. Safer. |
| `cmux new-workspace --window <id|ref|index>` | Explicit pin to a specific window |
| Workspace refs (`workspace:N`) are **globally unique** | `cmux send` / `notify` / `workspace-action` / `tab-action` / `close-workspace` all work cross-window with no `--window` flag |
| `cmux tree --all` enumerates ALL windows | R31 lane-readiness check works globally |
| `cmux list-windows` lists window UUIDs + selected workspace per window | Useful for the kingdom's `KING_WINDOW` capture |
| `cmux move-workspace-to-window --workspace <ref> --window <id|ref>` | Reparent a lane (rarely needed; spawn-time pinning is enough) |

**Config in `kingdom.json.cmux.spawnWindow`:**

| Value | Behaviour |
|---|---|
| `"current"` (default) | No `--window` flag; lanes go in caller's process window (King's window). Same as pre-0.27.0. |
| `"new"` | Kingdom calls `cmux new-window` once at session start, caches the new UUID in `<LOGS>/workspace-refs.env` as `KING_WINDOW`, then passes `--window $KING_WINDOW` on every lane spawn. Lanes get a fresh dedicated window. |
| `"window:N"` or `"<uuid>"` | Explicit pin to a known window. Power-user override. |

**Testing notes (2026-05-19, 8-window setup):**

- Spawned 3 test workspaces (workspace:41/42/43) with the kingdom's `spawn_master_workspace` helper.
- All landed in `window:1` (where the bash session lives) even though `window:7` was the user's focused window.
- Confirms: default behaviour follows caller's process, not UI focus.
- Cleanup via parallel `cmux close-workspace --workspace <ref> &; wait` worked fine; all 3 closed in <1s.

## Teardown / close commands

cmux has three distinct close commands. Picking the wrong one wastes a `/kingdom:exit` cycle on cryptic `Unknown tab action` errors — King has trial-and-errored this before. **Canonical mapping:**

| Target | Command | When |
|---|---|---|
| **Workspace** (lane teardown, `/kingdom:exit`) | `cmux close-workspace --workspace <ref>` | Closing a full lane workspace at kingdom teardown |
| **Surface** (single tab inside a workspace) | `cmux close-surface --surface <ref>` OR `cmux tab-action --action close --surface <ref>` | Sub-agent self-close (5-step closer Step 5) |
| **Window** (top-level cmux.app window) | `cmux close-window --window <ref>` | Rare — closes an entire native window |

**What NOT to use:**

- ❌ `cmux tab-action --action close-others --workspace <ws>` — only closes OTHER tabs in the workspace, leaves the workspace alive with one residual tab. Useless for teardown.
- ❌ `cmux tab-action --action close --workspace <ws>` — error: `Unknown tab action` when `--workspace` is passed without `--surface`. tab-action close targets a surface, not a workspace.
- ❌ `cmux workspace-action --action close ...` — there is no `close` workspace-action; only `rename`, `set-color`, `set-description`, `mark-read`, `mark-unread`, `pin`.

**Parallel teardown (correct pattern for `/kingdom:exit` Step 5):**

```bash
# Close N lane workspaces IN PARALLEL — each close is independent (rules.md R28)
for I in $(env | grep -E '^(WORKER|COWORKER|WATCHMAN)_WS_[0-9]+' | cut -d= -f1); do
  REF=$(eval echo "\$$I")
  cmux close-workspace --workspace "$REF" &
done
wait
```

Each `close-workspace` is a network call to cmux.app — serializing them makes teardown of 5 lanes take 5× longer for no reason.

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

Reserve notifications for events that change what the user or the King would do next.

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
| 👑 King | `Amber` |
| 👷 Worker | `Purple` |
| 🧑‍💼 Co-worker | `Blue` |
| 🕵️ Watchman | `Rose` |

> **Color name pitfall:** `violet` is NOT in cmux's named-color set — use `Purple` instead. Prior versions of the template used `"violet"` and required runtime substitution by the King. Fixed in v0.14.13.

The `new-workspace` command **does not accept `--color`** — set it via a second `workspace-action --action set-color` call right after creation.

## Spawn → name → color → describe (the 4-call pattern)

Real test confirms: `cmux new-workspace --name "X"` does NOT make the sidebar display "X" — cmux shows the active surface title (`"✳ Claude Code"` by default for Claude Code sessions) until the workspace name is explicitly enforced via `workspace-action --action rename`. The kingdom uses a **4-call pattern per lane** to guarantee the sidebar reflects intent:

```bash
spawn_lane () {
  local label="$1" path="$2" color="$3"

  # Step 1: create the workspace (capture ref robustly — awk pipeline
  #         broke in real test runs; grep -oE is more reliable)
  local result=$(cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --command "claude" \
    --focus false 2>&1)
  local ref=$(echo "$result" | grep -oE 'workspace:[0-9]+' | head -1)
  [ -z "$ref" ] && { echo "❌ spawn failed: $result" >&2; return 1; }

  # Step 2: FORCE the sidebar name (override auto-surface title "✳ Claude Code")
  cmux workspace-action --action rename --workspace "$ref" --title "$label" 2>/dev/null

  # Step 3: set color (new-workspace doesn't accept --color)
  [ -n "$color" ] && \
    cmux workspace-action --action set-color --workspace "$ref" --color "$color" 2>/dev/null

  # Step 4: force-set description (same reason as Step 2 — auto-title
  #         can clobber what was passed to new-workspace --description)
  cmux workspace-action --action set-description \
    --workspace "$ref" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" 2>/dev/null

  echo "$ref"
}
```

All four calls are silent-on-failure — descriptions, colors, and badges are cosmetic. The audit trail in `<LOGS>/` is the source of truth.

## Attention markers — mark-read / mark-unread

**The problem:** cmux.app auto-detects whether each workspace is "Running" / "Idle" / "Needs input" — but the detection is heuristic (stdin idle, output streaming, etc.) and not always accurate. A lane stuck on a permission prompt may still show as "Running"; a King with a pending "push?" question may show as "Idle". The kingdom can't directly override these auto-labels via CLI.

**The solution:** cmux exposes a **separate, manually controllable attention indicator** — `mark-read` / `mark-unread`. This is the badge dot shown on the workspace card in the sidebar. The kingdom uses it to override cmux's wrong auto-state when we KNOW better.

```bash
# Mark this workspace as needing attention (badge dot appears)
cmux workspace-action --action mark-unread --workspace "$WORKER_WS_1"

# Clear the attention (badge dot disappears)
cmux workspace-action --action mark-read --workspace "$WORKER_WS_1"
```

### Three-layer state override (when cmux's auto-detection is wrong)

When kingdom KNOWS a lane needs attention but cmux says "Running":

```bash
# 1. Mark the workspace unread (visible badge)
cmux workspace-action --action mark-unread --workspace "$LANE_WS"

# 2. Override the description with truth
cmux workspace-action --action set-description \
  --workspace "$LANE_WS" \
  --description "⚠ Blocked · permission prompt"

# 3. Fire a notification (bell panel + cross-workspace alert)
cmux notify --surface "$LANE_WS" --workspace "$KING_WS" \
  --title "👑 lane blocked" \
  --subtitle "$LANE_LABEL" \
  --body "Permission prompt — click to approve"
```

cmux's auto-state may still say "Running" but YOUR three signals tell the truth.

### State → markers convention

| Kingdom state | mark-read/unread | description prefix | notify? |
|---|---|---|---|
| 👷 Lane working normally | (no change) | `▶` | no |
| 👷 Lane blocked (permission prompt etc.) | `mark-unread` | `⚠ Blocked · ...` | yes (dual: lane surface + King workspace) |
| 👷 Lane closer just fired (done) | `mark-unread` (King's review pending) | `✅ <task> done · sentinel written` | yes (dual: lane + King) |
| 👑 King auto-gating | (no change) | `▶ Gating <lane>` | no |
| 👑 King has "push?" pending | `mark-unread` (King's own workspace) | `⚠ Push? · <lane> · <task>` | yes (King's workspace) |
| 👑 King gate FAIL | `mark-unread` (originating lane's workspace) | `❌ Gate FAIL · <lane>` | yes (lane's workspace) |
| 🕵️ Watchman develop RED | `mark-unread` (King's workspace) | (watchman's own description: `⚠ develop RED`) | yes (King's workspace) |
| 🕵️ Watchman PR mergeable | `mark-unread` (King's workspace) | (no King-workspace description change) | yes (King's workspace) |

When the attention state RESOLVES (the user approved push, lane unblocked, develop green again), the role responsible **clears the marker**:

```bash
cmux workspace-action --action mark-read --workspace "$LANE_WS"
# Description restored to active state
cmux workspace-action --action set-description --workspace "$LANE_WS" --description "▶ <next state>"
```

---

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
| 🧑‍💼 Co-worker | Activated by the user | `▶ <sub-task-id> · user paired` |
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

### Description update is OPTIONAL but recommended

Description updates are nice-to-have, not load-bearing. If a role fails to update (cmux unreachable, transient error), work continues — `master_agent.log` + task files remain the source of truth. Description is the visual surface for the audit trail, not the audit trail itself.

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
