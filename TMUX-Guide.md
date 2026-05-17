# TMUX-Guide.md — Tmux 101 for Bonfire

> Pure tmux fundamentals. For git-worktree isolation per agent, see
> [`CMUX-Guide.md`](CMUX-Guide.md). For workspace orchestration (King +
> 4-lane model), see [`.kingdom/.setting/index.md`](.kingdom/.setting/index.md).

Tmux keeps work alive across terminal disconnects and lets you watch
multiple processes in split panes. In Bonfire it's the outer multiplexer
for the kingdom (King + 4 lane panes).

---

## Core concepts

| Term    | What it is                                                       |
| ------- | ---------------------------------------------------------------- |
| Session | A named workspace that persists even after you close the terminal |
| Window  | A full-screen tab inside a session                                |
| Pane    | A split section inside a window                                   |

Bonfire convention: `pane-base-index 1` — panes count from `1.1`, never `1.0`.

---

## Sessions

```bash
tmux new-session -s work               # create, attach immediately
tmux new-session -d -s work            # create detached (in background)
tmux attach -t work                    # attach to existing
tmux ls                                # list all sessions
tmux kill-session -t work              # kill one session
tmux kill-server                       # kill all sessions
```

Detach (session keeps running): `Ctrl-b  d`

---

## Panes

```text
Ctrl-b  %          split horizontally (left | right)
Ctrl-b  "          split vertically (top / bottom)
Ctrl-b  arrow      move between panes
Ctrl-b  z          zoom current pane (toggle fullscreen)
Ctrl-b  x          close current pane
Ctrl-b  [          enter scroll/copy mode (arrows to navigate, q to exit)
```

Programmatic pane management:

```bash
SESSION=work; WIN=1
tmux split-window -t $SESSION:$WIN.1 -h -c "$DIR"     # split horizontal
tmux split-window -t $SESSION:$WIN.2 -v -c "$DIR"     # split vertical
tmux select-layout -t $SESSION:$WIN main-vertical     # one big pane + stack
tmux kill-pane    -t $SESSION:$WIN.3                  # close pane 3
```

---

## Sending text into a pane (`send-keys`)

The way one Claude session (or shell) tells another pane what to do.

```bash
# ALWAYS use -l for prompt body — without it, tmux interprets words like
# "Page" / "Down" as key names and emits "not in a mode" errors.
tmux send-keys -t work:1.2 -l "your prompt body here"
tmux send-keys -t work:1.2 Enter                     # Enter as a separate key event

# Special keys are sent without -l:
tmux send-keys -t work:1.2 C-l                       # Ctrl-L (clear/redraw)
tmux send-keys -t work:1.2 "/compact" Enter          # send a slash command
```

---

## Reading from a pane (`capture-pane`)

```bash
tmux capture-pane -t work:1.2 -p                     # current visible content
tmux capture-pane -t work:1.2 -p -S -300             # last 300 lines of scrollback
```

`-p` prints to stdout. Use this for visual peeking; for completion signals prefer file-based sentinels (see .kingdom/.setting/kings.md → "Pattern A — done-sentinel file").

---

## Pane titles (visible header per pane)

```bash
tmux set -t work -g pane-border-status top
tmux select-pane -t work:1.1 -T "King"
tmux select-pane -t work:1.2 -T "Lane working-1"
```

---

## Common gotchas

| Symptom                                | Fix                                                              |
| -------------------------------------- | ---------------------------------------------------------------- |
| Pane shows only separator line         | TUI didn't redraw — `tmux send-keys -t <pane> C-l`               |
| `not in a mode` errors on send-keys    | Forgot `-l` flag on the prompt body                              |
| `can't find pane: 0`                   | Use `1.1`/`1.2`/… — pane-base-index is 1                         |
| `Window too small`                     | Pane has <10 rows; re-run `select-layout` + shrink main pane     |
| Pane treats your input as a new prompt | You sent characters into an idle pane; only send when intended    |

---

## Essential shortcut card

| Action                          | Keys                                 |
| ------------------------------- | ------------------------------------ |
| Detach from session             | `Ctrl-b  d`                          |
| List sessions                   | `tmux ls`                            |
| Attach                          | `tmux attach -t <name>`              |
| New window                      | `Ctrl-b  c`                          |
| Switch window                   | `Ctrl-b  n` / `p`                    |
| Split left/right                | `Ctrl-b  %`                          |
| Split top/bottom                | `Ctrl-b  "`                          |
| Move between panes              | `Ctrl-b  arrow`                      |
| Zoom (fullscreen toggle)        | `Ctrl-b  z`                          |
| Scroll mode                     | `Ctrl-b  [`  (q to exit)             |
