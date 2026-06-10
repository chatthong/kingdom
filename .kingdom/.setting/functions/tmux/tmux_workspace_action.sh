#!/usr/bin/env bash
# kingdom function: tmux_workspace_action  (FALLBACK mirror of cmux_workspace_action)
# Under tmux the sidebar entry is rendered from window OPTIONS, so map only the meaningful actions
# and no-op the rest — never shell out to a missing cmux. The window NAME is the stable target slug,
# so `rename` is intentionally a no-op (the display title comes from @emoji/@state, not the name).
#   set-color --color <c>          → @rolecolor
#   set-description --description <d> → @statetext
#   rename / pin / unpin / mark-* / clear-* → no-op
tmux_workspace_action () {
  local ws="$1" action="$2"; [ "$#" -ge 2 ] && shift 2
  local t; t="$(tmux_target "$ws")"
  case "$action" in
    set-color)
      local c=""; while [ $# -gt 0 ]; do case "$1" in --color) c="$2"; shift 2 ;; *) shift ;; esac; done
      [ -n "$c" ] && tmux set-window-option -t "$t" @rolecolor "$c" 2>/dev/null ;;
    set-description)
      local d=""; while [ $# -gt 0 ]; do case "$1" in --description) d="$2"; shift 2 ;; *) shift ;; esac; done
      [ -n "$d" ] && tmux set-window-option -t "$t" @statetext "$d" 2>/dev/null ;;
    *) : ;;   # rename / pin / unpin / mark-read / mark-unread / clear-* → no-op under tmux
  esac
  return 0
}
