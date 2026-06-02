#!/usr/bin/env bash
# kingdom function: tmux_tree  (FALLBACK mirror of cmux_tree)
# cmux_tree dumps the window→pane topology (the King uses it for the R31 lane-readiness check).
# tmux: list the kingdom session's windows (the lanes) + pane counts + state glyph.
tmux_tree () {
  tmux list-windows -t "$(tmux_session)" -F '#{window_name} (#{window_panes}p) @state=#{@state}' 2>/dev/null
}
