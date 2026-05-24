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
        local king_win=$(cmux new-window 2>&1 | grep -oE '[A-F0-9-]{36}' | head -1)
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
  # `spawn_watchman_loop` helper already proved this pattern works.
  local result=$(cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --focus false \
    $window_flag 2>&1)
  local ref=$(echo "$result" | grep -oE 'workspace:[0-9]+' | head -1)
  [ -z "$ref" ] && { echo "❌ spawn failed: $result" >&2; return 1; }

  # Step 1b (v0.31.1): explicitly launch claude in the workspace's surface.
  # Without this, the workspace sits at a bash prompt and dispatch briefs
  # sent later via `cmux send` land in the shell — silent failure mode.
  local surface=$(cmux rpc workspace.list 2>/dev/null \
    | jq -r ".[] | select(.ref == \"$ref\") | .surfaces[0].ref" 2>/dev/null)
  if [ -n "$surface" ] && [ "$surface" != "null" ]; then
    cmux rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"claude\n\"}" 2>/dev/null
    sleep 1.5   # claude boot — same budget proven by spawn_watchman_loop
  else
    echo "⚠️ $label: no surface found post-spawn; claude REPL not launched. Dispatch will land in shell." >&2
  fi

  # Step 2: FORCE sidebar name (override "✳ Claude Code" auto-title)
  cmux workspace-action --action rename --workspace "$ref" --title "$label" 2>/dev/null

  # Step 3: set color (new-workspace doesn't accept --color)
  [ -n "$color" ] && \
    cmux workspace-action --action set-color --workspace "$ref" --color "$color" 2>/dev/null

  # Step 4: force-set description (auto-title can clobber what new-workspace --description set)
  cmux workspace-action --action set-description \
    --workspace "$ref" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" 2>/dev/null

  echo "$ref"
}
