#!/usr/bin/env bash
# kingdom function: kingdom_backend_init
# Detect the host terminal, export KINGDOM_BACKEND, and ACTIVATE that backend. Call this ONCE
# at session start (index.md mode detection / commands/work.md Step 0) BEFORE any spawn or cmux_*
# call. Both backends are already loaded (`core` deps cmux + tmux — wherever cmux loads, tmux loads
# too), so this just selects which one the cmux_* names route to:
#   cmux       → cmux_* call the cmux.app CLI (default; no override needed)
#   tmux       → kingdom_use_tmux_backend redefines cmux_*/spawn_* to drive a tmux session
#   standalone → warn; no lane workspaces (Agent() sub-agents only)
# Echoes the chosen backend (so callers can branch).
kingdom_backend_init () {
  local b; b="$(kingdom_detect_backend)"
  export KINGDOM_BACKEND="$b"
  case "$b" in
    cmux)
      echo "👑 kingdom backend: cmux.app (PRIMARY) — lanes are cmux workspaces" >&2 ;;
    tmux)
      command -v kingdom_use_tmux_backend >/dev/null 2>&1 && kingdom_use_tmux_backend
      echo "🕵 kingdom backend: tmux (FALLBACK, not cmux.app) — lanes are tmux windows; status bar = the sidebar." >&2 ;;
    standalone)
      echo "⚠️ kingdom backend: STANDALONE — no cmux.app and no tmux. No lane workspaces; the master uses in-process Agent() sub-agents only." >&2 ;;
  esac
  echo "$b"
}
