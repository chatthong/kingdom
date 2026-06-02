# TMUX-Guide — the kingdom's FALLBACK backend

When **cmux.app is unavailable** (Linux, or macOS without cmux — e.g. running in Ghostty), the kingdom runs in **FALLBACK mode** on plain `tmux`. This guide is the cmux→tmux mapping that makes tmux feel as close to the cmux.app sidebar as a terminal multiplexer can. All commands below were verified live on **tmux 3.6 under Ghostty**.

> Primary path is cmux.app (see [`.kingdom/.setting/reference/cmux.md`](.kingdom/.setting/reference/cmux.md)). FALLBACK is functionally equivalent for dispatch/read/state/teardown; the one thing tmux can't do is a *vertical* sidebar — tmux's status bar is horizontal, so the "colored workspace list" becomes the **status-bar window list**, one colored entry per lane.

## The model

| cmux.app | tmux (FALLBACK) |
|---|---|
| Workspace (one per lane, colored sidebar entry) | **window** (one per lane), colored in the status-bar window list |
| The vertical sidebar | the **status bar** (bottom) — `👑 kingdom·<proj>` on the left, the lane windows in the middle, `develop:green PRs:N` on the right |
| Workspace color (King=Amber, worker=Purple, …) | per-window `@rolecolor` option, rendered in `window-status-format` |
| Live description / state glyph | per-window `@state` option (▶ ⏸ ✅ ⚠ 🐾) — **set without renaming**, so the target handle stays stable |
| Tab / split | `tmux split-window` (pane) |
| Desktop notification | `tmux display-message` (transient) + `@state ⚠` glyph + a durable **king-inbox fallback file** (so an alert survives even with no one attached) |
| Surface ref | not needed — `send-keys` targets the window directly |

**Window naming:** the window NAME is the bare lane slug (`king`, `worker-1`, `senior-1`) — stable, used as the target handle. The emoji, color, and state glyph are window OPTIONS rendered in the status format, so changing a lane's state never renames its window (and never breaks an in-flight `send-keys` target). This is the key design point.

## Activate it

```bash
source .kingdom/.setting/functions/_load.sh
load_feature tmux             # sources functions/tmux/
export KINGDOM_BACKEND=tmux    # → redefines cmux_* / spawn_* to route to tmux (kingdom_use_tmux_backend)
```

After that, **every existing role/command call site works unchanged** — `cmux_send`, `cmux_set_state`, `cmux_notify`, `spawn_master_workspace`, `spawn_loop`, … all dispatch to tmux. `/kingdom:self-care` detects a missing cmux + present tmux and reports FALLBACK; `/kingdom:work` sets `KINGDOM_BACKEND=tmux` and spawns lanes as tmux windows.

## The backend wrappers (the `functions/tmux/` wrappers)

| Wrapper | tmux it runs | Mirrors |
|---|---|---|
| `tmux_setup_session <proj> <cwd>` | `new-session` + sidebar styling (status bar, per-role `window-status-format`) | the cmux window/sidebar setup |
| `tmux_new_workspace <slug> <cwd> <emoji> <color>` | `new-window` + `@emoji`/`@rolecolor`/`@state` | `cmux_new_workspace` |
| `spawn_master_workspace <label> <path> <color>` | `tmux_new_workspace` + boots `claude` in the window | same name, FALLBACK impl |
| `tmux_send <ws> <text>` | `send-keys -l "<text>"` then `send-keys Enter` | `cmux_send` |
| `tmux_send_key <ws> <key>` | `send-keys <key>` | `cmux_send_key` |
| `tmux_set_state <ws> <glyph> [text]` | `set-window-option @state` (no rename) | `cmux_set_state` |
| `tmux_notify <ws> <title> <sub> <body>` | `display-message` + `@state ⚠` + king-inbox fallback file | `cmux_notify` |
| `tmux_read_screen <ws>` | `capture-pane -p` (visible) | `cmux_read_screen` |
| `tmux_capture_pane <ws> [N]` | `capture-pane -p -S -N` | `cmux_capture_pane` |
| `tmux_list_workspaces` | `list-windows -F` | `cmux_list_workspaces` |
| `tmux_close_workspace <ws>` | `kill-window` | `cmux_close_workspace` |
| `tmux_new_split <ws> <-h\|-v>` | `split-window` | `cmux_new_split` |
| `tmux_identify` | `display-message -p '#{session_name}:#{window_index}.#{pane_index}'` | `cmux_identify` |

A "workspace ref" is a bare slug (`worker-1`) or `<session>:<slug>`; wrappers resolve either. Session name defaults to `kingdom` (`$KINGDOM_TMUX_SESSION`).

## See it

```bash
tmux attach -t kingdom        # the colored sidebar (status-bar window list); Ctrl-b w = window picker
tmux capture-pane -t kingdom:worker-1 -p   # read a lane non-interactively (what the King does)
```

## tmux gotchas (the ones that bite)

- **Always `send-keys -l` for the brief text**, then a separate `send-keys Enter`. Without `-l`, tmux interprets words like `Page`, `Up`, `Down`, `Space` as key names. (`tmux_send` does this for you.)
- **Don't encode state in the window name.** Renaming to show ▶→✅ would invalidate name-based targets mid-dispatch. State lives in `@state` (an option), rendered by the status format.
- **`base-index 0`** is set on the kingdom session so `king` is window 0; lanes follow.
- **No desktop notifications.** `tmux_notify` flashes `display-message` and glyphs the lane, but the *durable* signal is the king-inbox file — the King reads that, exactly like it reads `WATCH_*`/cmux badges. An alert is never only a transient flash.
- **Ghostty + tmux**: `TERM=xterm-ghostty`; truecolor + emoji render fine. Nothing special required.
