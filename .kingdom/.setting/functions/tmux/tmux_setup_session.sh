#!/usr/bin/env bash
# kingdom function: tmux_setup_session
# One-time: create the kingdom tmux session + the cmux-like sidebar styling (the status-bar
# window list, one colored entry per lane). Window 0 = king. Idempotent.
#   tmux_setup_session <proj> <cwd>
tmux_setup_session () {
  local proj="${1:-project}" cwd="${2:-$PWD}" S; S="$(tmux_session)"
  tmux has-session -t "$S" 2>/dev/null && return 0
  tmux new-session -d -s "$S" -n king -c "$cwd"
  tmux set -t "$S" -g base-index 0
  tmux set -t "$S" -g status on
  tmux set -t "$S" -g status-position bottom
  tmux set -t "$S" -g status-style 'bg=colour236,fg=colour250'
  tmux set -t "$S" -g status-left "#[bg=colour214,fg=black,bold] 👑 kingdom·$proj #[default] "
  tmux set -t "$S" -g status-left-length 30
  tmux set -t "$S" -g status-right '#[fg=colour108]develop:#{@develop}#[default] PRs:#{@prs} '
  tmux set -t "$S" -g window-status-separator ''
  tmux set -t "$S" -g window-status-format         '#[fg=#{@rolecolor}] #{@emoji} #{window_name} #{@state} #[default]'
  tmux set -t "$S" -g window-status-current-format '#[fg=#{@rolecolor},bold,reverse] #{@emoji} #{window_name} #{@state} #[default]'
  tmux set -t "$S" -g @develop green; tmux set -t "$S" -g @prs 0
  tmux set-window-option -t "$S:king" @rolecolor colour214
  tmux set-window-option -t "$S:king" @emoji 👑
  tmux set-window-option -t "$S:king" @state 🐾
}
