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
  # C8a: cmux_new_split takes a DIRECTION WORD (right|left|up|down); tmux split-window wants a
  # FLAG (-h|-v) and treats a bare word as a shell command to run in the new pane. Map it.
  cmux_new_split()       {
    local dir="$1" ws="$2" flag
    case "$dir" in right|left) flag=-h ;; up|down) flag=-v ;; *) flag=-v ;; esac
    tmux_new_split "$ws" "$flag"
  }
  cmux_identify()        { tmux_identify "$@"; }
  cmux_first_surface()   { printf '%s' "$(tmux_target "$1")"; }   # tmux has no surface indirection
  # The previously-UN-routed cmux_* the roles actually call — without these a tmux King silently
  # shelled out to a missing `cmux` (R31 gate via cmux_tree, every R38 sub-agent tab spawn, the
  # closer's tab self-close, the watchman orphan-tab sweep). Route or safely no-op each:
  cmux_tab_action()        { tmux_tab_action "$@"; }              # new-terminal-right → split pane; close → kill-pane
  cmux_tree()              { tmux_tree "$@"; }                    # R31 lane-readiness topology
  cmux_workspace_action()  { tmux_workspace_action "$@"; }        # set-color/-description map; rename/pin → no-op

  # C8c: JSON parity — callers parse cmux_list_panes / cmux_list_pane_surfaces with jq, so the
  # tmux routes MUST emit JSON, not raw `tmux list-panes` text.
  cmux_list_panes()        {
    # cmux_list_panes <ws> → {"panes":[{"id":"%N","title":"…","active":bool}, …]}
    local t; t="$(tmux_target "${1:-$(tmux_session)}")"
    tmux list-panes -t "$t" -F '{"id":"#{pane_id}","title":"#{pane_title}","active":#{?pane_active,true,false}}' 2>/dev/null \
      | jq -s '{panes: .}' 2>/dev/null
  }
  cmux_list_pane_surfaces(){
    # Honors --workspace <ref> (target that window); emits {"surfaces":[{"ref":"%N","title":"…"}]}.
    local ws=""
    while [ $# -gt 0 ]; do case "$1" in --workspace) ws="$2"; shift 2 ;; *) shift ;; esac; done
    local t; t="$(tmux_target "${ws:-$(tmux_session)}")"
    tmux list-panes -t "$t" -F '{"ref":"#{pane_id}","title":"#{pane_title}"}' 2>/dev/null \
      | jq -s '{surfaces: .}' 2>/dev/null
  }

  cmux_rpc()               { :; }                                 # no cmux RPC under tmux — safe no-op
  cmux_new_window()        { :; }                                 # cmux multi-window — n/a under tmux
  cmux_close_window()      { :; }

  # C8d: route ALL meaningful args of cmux_close_surface / _attention_override / _attention_clear.
  cmux_close_surface()     {
    # Prefer $TMUX_PANE when the passed ref is empty or surface:*-shaped (a cmux ref that means
    # nothing to tmux — the caller is the closer self-closing its OWN pane).
    local p="$1"
    case "$p" in ""|surface:*) p="${TMUX_PANE:-$p}" ;; esac
    [ -n "$p" ] && tmux kill-pane -t "$p" 2>/dev/null
  }
  # cmux_attention_override <lane_ws> <king_ws> <desc> <n_title> <n_sub> <n_body> [lane_surface]
  # H9: the old stub dropped 5 of 7 args including the King notification — blocked lanes went
  # unnoticed on tmux. Route all meaningful args: glyph the lane ⚠, set its description to the
  # truth, and tmux_notify the King (which also writes a durable inbox flag).
  cmux_attention_override(){
    local lane_ws="$1" king_ws="$2" desc="$3" n_title="$4" n_sub="$5" n_body="$6"
    [ -n "$lane_ws" ] && tmux_set_state "$lane_ws" "⚠" 2>/dev/null
    [ -n "$lane_ws" ] && [ -n "$desc" ] && tmux_workspace_action "$lane_ws" set-description --description "$desc"
    tmux_notify "$king_ws" "$n_title" "$n_sub" "$n_body"
  }
  # cmux_attention_clear <lane_ws> <next_state_desc> — clear glyph AND restore the description.
  cmux_attention_clear()   {
    local lane_ws="$1" next_desc="${2:-▶ active}"
    [ -n "$lane_ws" ] && tmux_set_state "$lane_ws" "▶" 2>/dev/null
    [ -n "$lane_ws" ] && tmux_workspace_action "$lane_ws" set-description --description "$next_desc"
  }

  # spawn_master_workspace(label, path, color) → a tmux window. Derive slug + emoji from the
  # label's tokens (e.g. "👷 worker-1" → emoji "👷", slug "worker-1"); boot claude in the window.
  spawn_master_workspace() {
    local label="$1" proj="$2" color="$3" slug emoji ref   # `proj` not `path`: zsh ties `path`→$PATH
    slug="${label##* }"; emoji="${label%% *}"
    ref="$(tmux_new_workspace "$slug" "$proj" "$emoji" "${color:-colour141}")"
    tmux send-keys -t "$ref" -l "claude"; tmux send-keys -t "$ref" Enter   # boot the REPL
    printf '%s' "$ref"
  }
  spawn_loop() { tmux_send "$1" "$2"; }   # $2 = the /loop brief

  # C8b: the sub-agent pool is a no-op under tmux. The cmux pool pre-warms idle `claude -p`
  # surfaces and tracks them by surface:N ids; tmux pane ids are %N and never match the
  # surface:[0-9]+ greps, so the whole pool/visible-sub-agent system silently does nothing.
  # Under tmux we DON'T pre-warm (no cheap surface registry to track, and a window full of idle
  # panes is noise) — every sub-agent is spawned on demand as a real pane via spawn_subagent_tab.
  spawn_pool_slot()          { :; }   # no pre-warming under tmux (no surface registry to track)
  init_subagent_pool()       { :; }   # no pool to initialise under tmux
  spawn_subagent_from_pool() { spawn_subagent_tab "$@"; }   # pool empty by design → always on-demand
  # spawn_subagent_tab <model> <brief>: split a pane in the caller's window, capture its %N id,
  # boot claude with the model, bounded-wait for the REPL, then send the brief.
  spawn_subagent_tab() {
    local model="${1:-sonnet}" brief="$2" pane i
    # Split the caller's CURRENT window (no -t → tmux uses the active window/pane).
    pane="$(tmux split-window -h -P -F '#{pane_id}' 2>/dev/null)"
    [ -z "$pane" ] && { printf '⚠️ spawn_subagent_tab: could not split a pane\n' >&2; return 1; }
    tmux send-keys -t "$pane" -l "claude --model ${model}"; tmux send-keys -t "$pane" Enter
    # Bounded-wait for Claude to boot: poll the pane for a prompt marker, up to ~6 tries.
    for i in 1 2 3 4 5 6; do
      sleep 1
      tmux capture-pane -t "$pane" -p 2>/dev/null | grep -qiE '│ >|Welcome to Claude|for shortcuts' && break
    done
    # Send the brief (literal, then Enter).
    tmux send-keys -t "$pane" -l "$brief"; tmux send-keys -t "$pane" Enter
    printf '%s' "$pane"
  }
}

# Auto-activate when the session is already in tmux FALLBACK mode (this file is sourced last
# in the tmux feature, so all tmux_* wrappers are defined by now).
[ "${KINGDOM_BACKEND:-}" = "tmux" ] && kingdom_use_tmux_backend
