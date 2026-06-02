#!/usr/bin/env bash
# kingdom function: kingdom_use_tmux_backend  (FALLBACK backend activator)
# Redefine the cmux_* / spawn_* names the rest of the kingdom calls so they route to the tmux
# wrappers (tmux_send, tmux_set_state, …). After this, `cmux_send` IS `tmux_send`, etc., so every
# existing role/command call site works in FALLBACK mode with no edits.
#
# Usage (FALLBACK detection in index.md / commands/work.md):
#   load_feature tmux            # sources all the tmux_* wrappers + this activator
#   export KINGDOM_BACKEND=tmux  # the line at the bottom of this file then auto-activates
# (or call kingdom_use_tmux_backend explicitly).
#
# Requires the tmux_* wrappers to be loaded (they are, via `load_feature tmux`); the redefined
# functions only need them to exist at CALL time.
kingdom_use_tmux_backend () {
  cmux_send()            { tmux_send "$@"; }
  cmux_send_key()        { tmux_send_key "$@"; }
  cmux_set_state()       { tmux_set_state "$@"; }
  cmux_notify()          { tmux_notify "$@"; }
  cmux_read_screen()     { tmux_read_screen "$@"; }
  cmux_capture_pane()    { tmux_capture_pane "$@"; }
  cmux_list_workspaces() { tmux_list_workspaces "$@"; }
  cmux_close_workspace() { tmux_close_workspace "$@"; }
  cmux_new_split()       { tmux_new_split "$2" "$1"; }            # cmux(dir, ws, type) → tmux(ws, dir)
  cmux_identify()        { tmux_identify "$@"; }
  cmux_first_surface()   { printf '%s' "$(tmux_target "$1")"; }   # tmux has no surface indirection
  # The previously-UN-routed cmux_* the roles actually call — without these a tmux King silently
  # shelled out to a missing `cmux` (R31 gate via cmux_tree, every R38 sub-agent tab spawn, the
  # closer's tab self-close, the watchman orphan-tab sweep). Route or safely no-op each:
  cmux_tab_action()        { tmux_tab_action "$@"; }              # new-terminal-right → split pane; close → kill-pane
  cmux_tree()              { tmux_tree "$@"; }                    # R31 lane-readiness topology
  cmux_workspace_action()  { tmux_workspace_action "$@"; }        # set-color/-description map; rename/pin → no-op
  cmux_close_surface()     { tmux kill-pane -t "$1" 2>/dev/null; } # sub-agent tab self-close (closer Step 5)
  cmux_list_panes()        { tmux list-panes -t "$(tmux_target "${1:-$(tmux_session)}")" 2>/dev/null; }
  cmux_list_pane_surfaces(){ tmux list-panes -F '#{pane_id}' 2>/dev/null; }
  cmux_rpc()               { :; }                                 # no cmux RPC under tmux — safe no-op
  cmux_new_window()        { :; }                                 # cmux multi-window — n/a under tmux
  cmux_close_window()      { :; }
  cmux_attention_override(){ tmux_set_state "$1" "⚠" 2>/dev/null; } # attention = ⚠ glyph
  cmux_attention_clear()   { tmux_set_state "$1" "▶" 2>/dev/null; }
  # spawn_master_workspace(label, path, color) → a tmux window. Derive slug + emoji from the
  # label's tokens (e.g. "👷 worker-1" → emoji "👷", slug "worker-1"); boot claude in the window.
  spawn_master_workspace() {
    local label="$1" path="$2" color="$3" slug emoji ref
    slug="${label##* }"; emoji="${label%% *}"
    ref="$(tmux_new_workspace "$slug" "$path" "$emoji" "${color:-colour141}")"
    tmux send-keys -t "$ref" -l "claude"; tmux send-keys -t "$ref" Enter   # boot the REPL
    printf '%s' "$ref"
  }
  spawn_loop() { tmux_send "$1" "$2"; }   # $2 = the /loop brief
}

# Auto-activate when the session is already in tmux FALLBACK mode (this file is sourced last
# in the tmux feature, so all tmux_* wrappers are defined by now).
[ "${KINGDOM_BACKEND:-}" = "tmux" ] && kingdom_use_tmux_backend
