#!/usr/bin/env bash
# kingdom function: tmux_tab_action  (FALLBACK mirror of cmux_tab_action)
# cmux uses tab-action for: new-terminal-right (spawn a visible sub-agent tab) and close (--surface).
# tmux maps: new-terminal-right → a split PANE in the target window (echo its pane id, the "surface");
# close → kill that pane. Unknown actions → no-op (NEVER shell out to a missing cmux under FALLBACK).
#   tmux_tab_action new-terminal-right [--workspace <ws>]   → echoes the new pane id
#   tmux_tab_action close --surface <pane>                  → kills that pane
tmux_tab_action () {
  local action="$1"; shift
  case "$action" in
    new-terminal-right|new-terminal-down|new-terminal|new)
      local ws=""
      while [ $# -gt 0 ]; do case "$1" in --workspace) ws="$2"; shift 2 ;; *) shift ;; esac; done
      if [ -n "$ws" ]; then tmux split-window -h -t "$(tmux_target "$ws")" -P -F '#{pane_id}' 2>/dev/null
      else tmux split-window -h -P -F '#{pane_id}' 2>/dev/null; fi
      ;;
    close)
      local surf=""
      while [ $# -gt 0 ]; do case "$1" in --surface) surf="$2"; shift 2 ;; *) shift ;; esac; done
      [ -n "$surf" ] && tmux kill-pane -t "$surf" 2>/dev/null
      ;;
    *) : ;;
  esac
}
