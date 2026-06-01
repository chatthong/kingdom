#!/usr/bin/env bash
# kingdom function: spawn_master_workspace

spawn_master_workspace () {
  local label="$1" path="$2" color="$3"

  # v0.27.0+: respect kingdom.json.cmux.spawnWindow for multi-window users
  # Default = "current": no --window flag → sticks to caller's process window
  # Other valid values: "new" (open fresh window), "window:N" / "window:<uuid>" (explicit ref)
  local spawn_window=$(jq -r '.cmux.spawnWindow // "current"' "$KJSON" 2>/dev/null)
  local window_flag=""
  case "$spawn_window" in
    current|"") window_flag="" ;;
    new)
      # Lazy-create the kingdom window once; cache UUID in workspace-refs.env
      if ! grep -q '^KING_WINDOW=' "$LOGS/workspace-refs.env" 2>/dev/null; then
        local king_win=$(cmux_new_window)
        [ -n "$king_win" ] && echo "KING_WINDOW=$king_win" >> "$LOGS/workspace-refs.env"
      fi
      local cached_win=$(grep '^KING_WINDOW=' "$LOGS/workspace-refs.env" | cut -d= -f2)
      [ -n "$cached_win" ] && window_flag="--window $cached_win"
      ;;
    *)
      # Explicit ref/index passed through
      window_flag="--window $spawn_window"
      ;;
  esac

  # Step 1: create the workspace (capture ref via grep -oE — awk pipelines break in some shells).
  #
  # v0.31.1: dropped `--command "claude"`. Consumer-tested 2026-05-21: the flag
  # was unreliable across cmux versions — workspaces frequently came up at a
  # bash prompt and King's subsequent `cmux send -- "<brief>"` landed in the
  # shell. Explicit post-spawn `claude\n` (Step 1b below) replaces it; the
  # `spawn_loop` helper already proved this pattern works.
  local desc="Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)"
  local ref=$(cmux_new_workspace "$label" "$path" "$desc" "$window_flag")
  [ -z "$ref" ] && { echo "❌ spawn failed for $label (cmux_new_workspace returned no ref)" >&2; return 1; }

  # Step 1b (v0.31.1): explicitly launch claude in the workspace's surface.
  # Without this, the workspace sits at a bash prompt and dispatch briefs
  # sent later via `cmux send` land in the shell — silent failure mode.
  # v0.37.0 (K2/K6): surface resolution moved to cmux_first_surface, which is
  # robust to the wrapped {workspaces:[…]} schema. Plus a LOUD post-launch
  # verify — read the screen and confirm Claude actually booted instead of
  # assuming a fixed sleep was enough.
  local surface=$(cmux_first_surface "$ref")
  if [ -n "$surface" ]; then
    cmux_rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"claude\n\"}"
    local tries=0 booted=""
    while [ "$tries" -lt 6 ]; do          # up to ~9s
      sleep 1.5
      if cmux_read_screen "$ref" 2>/dev/null | grep -qiE 'Claude Code|esc to interrupt|❯ '; then
        booted=1; break
      fi
      tries=$((tries + 1))
    done
    [ -z "$booted" ] && echo "⚠️ $label: claude REPL not confirmed after ~9s; dispatch may land in shell. Check the lane." >&2
  else
    echo "⚠️ $label: no surface found post-spawn (cmux_first_surface empty); claude REPL not launched. Dispatch will land in shell." >&2
  fi

  # Step 2: FORCE sidebar name (override "✳ Claude Code" auto-title)
  cmux_workspace_action "$ref" rename --title "$label"

  # Step 3: set color (new-workspace doesn't accept --color)
  [ -n "$color" ] && cmux_workspace_action "$ref" set-color --color "$color"

  # Step 4: force-set description (auto-title can clobber what new-workspace --description set)
  cmux_workspace_action "$ref" set-description --description "$desc"

  echo "$ref"
}
