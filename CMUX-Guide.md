# CMUX-Guide.md — manaflow-ai/cmux for the kingdom

> This guide is about [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux), the
> macOS terminal app that is the kingdom's primary outer host. For raw tmux (the
> fallback path), see TMUX-Guide.md. For per-lane git worktrees, see
> .kingdom/.setting/git.md — the kingdom uses plain `git worktree` directly.

## What is manaflow/cmux?

manaflow-ai/cmux is a Swift/AppKit native macOS terminal app built on libghostty,
designed specifically for parallel AI coding sessions. It provides workspaces, panes,
tabs, desktop notifications, a scriptable CLI/socket API, and an in-app browser —
all as first-class features rather than afterthoughts bolted onto a general-purpose
terminal.

The key design goal is letting an orchestrating agent (King) control multiple Claude
Code teammate sessions — spawning them, sending keystrokes, reading their output,
and receiving alerts — through a clean CLI surface. Inside cmux.app, Claude Code's
`teammateMode: "tmux"` is intercepted by a `__tmux-compat` translation layer that
produces native cmux splits rather than real tmux panes.

---

## Install

```bash
brew tap manaflow-ai/cmux && brew install --cask cmux
# or download the DMG from https://github.com/manaflow-ai/cmux/releases
```

---

## Key features the kingdom uses

| Feature | CLI | Used by |
|---|---|---|
| Spawn Claude Code teammates as native splits | `cmux claude-teams` | /kingdom-start (PRIMARY mode) |
| Send keystrokes to a pane | `cmux send --pane <handle> "<text>"` | King dispatching tasks to lanes |
| Send a single key | `cmux send-key --pane <handle> Enter` | King confirming permission prompts |
| Push a notification | `cmux notify --workspace <id> "<message>"` | Lanes/Watchman alerting King/Ter |
| Set sidebar status pill | `cmux set-status --pane <handle> "<text>"` | Watchman + lane masters reporting state |
| Read terminal text | `cmux read-screen --pane <handle>` | King peeking at lane state |
| Capture pane scrollback | `cmux capture-pane --pane <handle> -S -200` | Tmux-compat alias; same as above |
| List panes (discover handles) | `cmux list-panes --workspace <id> --json` | King resolving lane to pane handle |
| Print workspace tree | `cmux tree --json` | King discovering the layout |

---

## How the kingdom uses cmux.app

- King launches via `cd <workspace> && claude` inside cmux.app (auto-memory loads at
  workspace root).
- King's slash command `/kingdom-start` runs `cmux claude-teams` to spawn Claude Code
  teammates as native cmux splits.
- King then runs `cmux list-panes` to discover handles, `cmux rename-tab` to label
  each pane (worker-1, worker-2, …), and `cmux send` to inject task briefs into each.
- Lanes signal completion via `cmux notify` (sidebar badge lights up). King polls
  sentinel flag files in `.kingdom/<project>/logs/done/`.
- Watchman uses `cmux set-status` to keep develop / open-PR health visible in the
  sidebar at a glance.

---

## Prerequisites

The setting `"teammateMode": "tmux"` in `~/.claude/settings.json` is required. Inside
cmux.app, this routes Claude Code's teammate-spawn commands through cmux's
`__tmux-compat` layer — Claude Code thinks it is talking to tmux, but cmux.app
intercepts and produces native cmux splits. No real tmux process is started.

If you are NOT inside cmux.app, the same setting causes Claude Code to spawn teammates
as actual tmux panes (fallback path) — see TMUX-Guide.md.

---

## Common patterns

### Dispatch a task brief to a lane

```bash
# Discover what panes exist after /kingdom-start
cmux tree --json | jq '.panes[] | {handle, label}'

# Send a multi-line task brief (write to file first to avoid paste fragmentation)
cat > /tmp/brief-lane1.txt << 'EOF'
Your task: audit bfg-swt/apps/account-center/src for missing auth guards.
Write findings to .kingdom/bfg-swt/logs/T42.md and drop a done flag at
.kingdom/bfg-swt/logs/done/T42__sonnet-audit.flag when complete.
EOF
cmux send --pane lane-1 "cat /tmp/brief-lane1.txt"
cmux send-key --pane lane-1 Enter
```

### Confirm a permission prompt

```bash
cmux send-key --pane lane-2 y
cmux send-key --pane lane-2 Enter
```

### Alert Ter when work is done (from a lane)

```bash
cmux notify --workspace "$CMUX_WORKSPACE_ID" "Lane 1 done: T42 audit complete"
```

### Poll for completion (from King)

```bash
until [ -f ".kingdom/bfg-swt/logs/done/T42__sonnet-audit.flag" ]; do
  sleep 5
done
cmux notify --workspace "$CMUX_WORKSPACE_ID" "All lanes finished — ready for review"
```

### Discovery after layout changes

```bash
cmux list-panes --workspace "$CMUX_WORKSPACE_ID" --json | jq '.[].handle'
```

---

## Gotchas

- `cmux send` returns no error but pane is unchanged: the `--pane` handle is wrong.
  Run `cmux tree --json` to inspect the current layout and get the correct handle.
- Pane discovery after `cmux claude-teams` may need a manual `cmux list-panes` first;
  the layout depends on what claude-teams produced and how many teammates were spawned.
- `__tmux-compat` is a translation layer, not full tmux semantics. Complex tmux scripts
  (window splitting flags, socket paths, `-t session:window.pane` addressing) may not
  map perfectly. Use cmux's native commands when possible.
- `cmux notify` requires the workspace ID, not the pane handle. Stash
  `$CMUX_WORKSPACE_ID` at session start so lanes can reference it without a tree lookup.
- Sidebar status pills set via `cmux set-status` persist until overwritten; always
  update them to a terminal state ("done", "blocked", "idle") so stale pills don't
  mislead at a glance.

---

## See also

- TMUX-Guide.md — raw tmux 101 (the fallback path when not inside cmux.app)
- .kingdom/.setting/git.md — git worktree usage (plain `git worktree`, no external tool)
- .kingdom/.setting/kings.md — King's spawn checklist (uses everything above)
- .kingdom/.setting/index.md — workspace rules, priority chain, three-tier logging,
  worker dispatch, 4-step closer template, archivist merge
