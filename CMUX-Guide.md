# CMUX-Guide — the kingdom's PRIMARY backend

> A reading guide for humans. It explains what [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) is and how the kingdom uses it as its primary host on macOS. For the exact command surface the roles call, see the shipped wrapper catalog [`.kingdom/.setting/reference/cmux.md`](.kingdom/.setting/reference/cmux.md). For the fallback path, see [`TMUX-Guide.md`](TMUX-Guide.md). For per-lane worktrees, see [`.kingdom/.setting/reference/git.md`](.kingdom/.setting/reference/git.md).

---

## What is manaflow/cmux?

manaflow-ai/cmux is a native macOS terminal app (built on libghostty) designed for parallel AI coding. Unlike a general-purpose terminal, it treats **workspaces**, **tabs**, **splits**, **desktop notifications**, a **colour-coded sidebar**, a scriptable **CLI**, and an in-app **browser** as first-class features.

That's exactly what an orchestrator needs. The kingdom's King runs in one cmux workspace and drives a fleet of lane workspaces — spawning each, sending it task briefs, reading its screen, setting its sidebar colour and live status, and receiving notifications back — all through cmux's CLI. The screenshot in the [README](README.md) is a live kingdom in cmux.app.

> **Target version: manaflow/cmux ≥ 0.64.6.** Not to be confused with `craigsc/cmux` (a different worktree CLI — the kingdom does not use it).

---

## Install

```bash
brew install --cask cmux
# or download the DMG from https://github.com/manaflow-ai/cmux/releases
```

Then run `/kingdom:self-care` in a Claude Code session inside cmux.app — it confirms cmux (plus `tmux`, `jq`, `gh`, `git`) is present and ready.

---

## How the kingdom uses cmux (the model)

The kingdom maps onto cmux's three-tier hierarchy:

| Tier | Who | Lifetime | Purpose |
|---|---|---|---|
| 🏢 **Workspace** | 👑 King + every 👷 Worker / 🧑‍💼 Co-worker / 🕵️ Watchman / 🎓 Senior | Long-lived (persists across sessions) | One Claude Code session per role — these are the colour-coded entries in the sidebar |
| 📑 **Tab** | 🐱 visible sub-agents inside a master's workspace | Short-lived (auto-closes on its sentinel flag) | Watchable sub-agent execution |
| 🪟 **Split** | Watchman's dual monitor view; optional paired-co-worker editor | Same as the workspace | Two panes in one workspace |

The flow, end to end:

1. **King boots** in its own workspace (`cd <workspace> && claude`); the project's auto-memory loads at the workspace root.
2. On `/kingdom:work`, the King renames its workspace to `👑 King · <project>` and **spawns one workspace per lane** with `cmux new-workspace --command "claude"` — *not* panes, *not* a teammate-spawn. Each lane's `--cwd` is its own `git worktree`. Captured workspace refs are persisted to `<LOGS>/workspace-refs.env` so lanes stay addressable across restarts.
3. The King **dispatches** each lane its task brief (text + a real Enter keypress).
4. Lanes work in parallel, each updating its **sidebar colour, status line, and attention badge** to mirror progress. On completion a lane fires a **notification** (sidebar badge + bell-panel entry) and drops a sentinel flag in `<LOGS>/done/`.
5. The King polls those sentinels, gates the work, overlays it for your review, and pushes only on your explicit approval.

### Everything goes through wrappers (since v0.36.0)

Roles never type raw `cmux …`. Every subcommand has a one-line wrapper in [`.kingdom/.setting/functions/cmux/`](.kingdom/.setting/functions/cmux/) — `cmux_send`, `cmux_notify`, `cmux_new_workspace`, `cmux_set_state`, `cmux_workspace_action`, `cmux_close_workspace`, and friends (plus `browser_*` for the in-app browser). One wrapper per subcommand means one place to fix if cmux's CLI shifts, and the tmux fallback mirrors the same names. The authoritative list, with the exact raw command each wrapper runs, is the shipped catalog:

➡️ **[`.kingdom/.setting/reference/cmux.md`](.kingdom/.setting/reference/cmux.md)** — read this for any specific invocation.

---

## Backend auto-detection (you don't flip a switch)

The kingdom detects its host at session start and routes every `cmux_*` call accordingly — there's no config toggle:

| Backend | When | What lanes are |
|---|---|---|
| **cmux** (PRIMARY) | `$CMUX_CLAUDE_PID` is set **and** the `cmux` CLI is present (you're inside cmux.app) | cmux workspaces in the colour-coded sidebar |
| **tmux** (FALLBACK) | any other terminal (Ghostty, iTerm2, Terminal.app, Linux) with `tmux` available | tmux windows; the status-bar window list stands in for the sidebar — see [`TMUX-Guide.md`](TMUX-Guide.md) |
| **standalone** | neither | no lane workspaces; the King uses in-process `Agent()` sub-agents only |

Requiring **both** the env var and the binary means a stray `CMUX_*` variable alone never mis-routes the King to a missing CLI — it falls cleanly to tmux.

---

## What you see in the sidebar

- **Colour-coded workspaces** — one entry per role, coloured by role (King amber, Senior teal, Worker purple, Co-worker blue, Watchman rose). You read the whole fleet at a glance.
- **Live status lines** — each workspace's description is a real-time activity line (`▶ working`, `⚠ Push?`, `✅ done`, `🐾 idle`), updated by the role on every state transition.
- **Notifications, three surfaces** — a blue ring on the sending pane, a numbered badge on the destination workspace card, and a rolling list under the bell icon. The kingdom reserves these for events that change what you'd do next (a lane finished, `develop` went red, the King needs a push decision) — never for routine churn.

---

## Gotchas

- **A brief lands in the lane but it never starts.** `cmux send <ref> Enter` types the literal word "Enter" — `send` only emits text. To submit you need a real keypress (`cmux send-key`). The `cmux_send` wrapper does both (text, then Enter), so calling the wrapper avoids this entirely.
- **Renamed a workspace but the sidebar still shows the old name.** Use the workspace-level rename (`workspace-action --action rename`), not the tab-level one — the latter renames the focused tab, not the sidebar label.
- **Workspace refs drift after a cmux.app restart.** They aren't stable across app restarts. The kingdom persists refs to `<LOGS>/workspace-refs.env` and rebuilds on resume; `/kingdom:self-care` flags a mismatch.
- **`new-workspace` ignores `--color`.** Set the colour in a separate `workspace-action --action set-color` call right after creation (the wrappers already do this).
- **Status lines and colours are cosmetic.** If cmux is briefly unreachable, work continues — `master_agent.log` and the task files are the source of truth, not the sidebar.

---

## See also

- [`.kingdom/.setting/reference/cmux.md`](.kingdom/.setting/reference/cmux.md) — the authoritative wrapper catalog (every `cmux_*` call + the raw command it runs)
- [`.kingdom/.setting/functions/index.md`](.kingdom/.setting/functions/index.md) — the function manifest (cmux + tmux + browser wrappers)
- [`TMUX-Guide.md`](TMUX-Guide.md) — the fallback backend, with the full cmux → tmux mapping
- [`.kingdom/.setting/reference/git.md`](.kingdom/.setting/reference/git.md) — per-lane worktrees (plain `git worktree`, no external tool)
- [`.kingdom/.setting/roles/king.md`](.kingdom/.setting/roles/king.md) — the King's spawn + dispatch + gate checklist
- [`.kingdom/.setting/index.md`](.kingdom/.setting/index.md) — workspace rules, backend detection, the priority chain
