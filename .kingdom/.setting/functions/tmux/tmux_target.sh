#!/usr/bin/env bash
# kingdom function: tmux_target  (shared resolver for the tmux FALLBACK backend)
# A "workspace ref" in tmux mode is a bare lane slug ("worker-1") or "<session>:<slug>".
# tmux_session → the kingdom session name. Default "kingdom", but commands/work.md exports
#   KINGDOM_TMUX_SESSION="kingdom-<project>" so two tmux kingdoms (e.g. 2 Ghostty windows on
#   different projects) never share one session. One King per project per workspace.
# tmux_target  → resolve a ref to a full tmux target (slug gets the session prefix; "sess:slug" passes through).
tmux_session () { echo "${KINGDOM_TMUX_SESSION:-kingdom}"; }
tmux_target  () { case "$1" in *:*) printf '%s' "$1" ;; *) printf '%s:%s' "$(tmux_session)" "$1" ;; esac; }
