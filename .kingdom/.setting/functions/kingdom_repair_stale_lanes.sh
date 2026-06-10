#!/usr/bin/env bash
# kingdom function: kingdom_repair_stale_lanes
# Detect (default) or repair (--repair) the workspace↔worktree disconnect that a
# rebase/merge leaves behind (U11): a lane whose worktree dir is gone, whose lane
# branch was deleted, or whose refs.env workspace died.
#
#   kingdom_repair_stale_lanes            # detect-and-report only (empty = healthy)
#   kingdom_repair_stale_lanes --repair   # actually rebuild broken lanes
#
# Env: $PROJ (project repo), $REFS_FILE (workspace-refs.env), $BASE (base branch),
#      $WS/$PROJECT (for self-<role> grounding). Reads lanes from refs.env keys.
kingdom_repair_stale_lanes () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally; auto-reverts on return
  local repair=0; [ "$1" = "--repair" ] && repair=1
  local proj="${PROJ:?kingdom_repair_stale_lanes: \$PROJ unset}"
  local refs="${REFS_FILE:?kingdom_repair_stale_lanes: \$REFS_FILE unset}"
  local base="${BASE:-develop}"
  [ -f "$refs" ] || { [ "$repair" = 1 ] && echo "⚠️ kingdom_repair_stale_lanes: no refs file ($refs)" >&2; return 0; }

  local lane ref wt branch_ok wt_ok line broke
  # Enumerate lanes from refs.env keys: lines like `worker-1_WS=workspace:3`.
  while IFS= read -r line; do
    case "$line" in
      worker-*_WS=*|co-worker-*_WS=*|watchman-*_WS=*|senior-*_WS=*) : ;;
      *) continue ;;
    esac
    lane="${line%%_WS=*}"
    ref="${line#*_WS=}"
    wt="$proj/.worktrees/$lane"

    wt_ok=1; branch_ok=1; broke=""
    [ -d "$wt" ] || { wt_ok=0; broke="${broke}worktree-dir-missing "; }
    git -C "$proj" rev-parse --verify "$lane" >/dev/null 2>&1 || { branch_ok=0; broke="${broke}branch-missing "; }

    # Reverse case: worktree present but no live workspace behind the refs entry.
    local ws_live=1
    if [ -n "$ref" ] && command -v cmux_tree >/dev/null 2>&1; then
      cmux_tree 2>/dev/null | grep -qF "$ref" || ws_live=0
    fi
    [ "$ws_live" = 0 ] && [ "$wt_ok" = 1 ] && broke="${broke}workspace-dead(${ref}) "

    [ -z "$broke" ] && continue   # this lane is healthy

    if [ "$repair" = 0 ]; then
      printf '  • %-14s broken: %s\n' "$lane" "$broke"
      continue
    fi

    # --- repair path ---
    echo "🔧 repairing $lane ($broke)" >&2
    # 1. Tear down the (possibly dead) workspace, best-effort.
    [ -n "$ref" ] && command -v cmux_close_workspace >/dev/null 2>&1 && cmux_close_workspace "$ref" 2>/dev/null || true
    # 2. Prune stale worktree admin entries.
    git -C "$proj" worktree prune 2>/dev/null || true
    # 3. Recreate worktree + lane branch from origin/$base via the shared helper.
    if [ "$wt_ok" = 0 ] || [ "$branch_ok" = 0 ]; then
      rm -rf "$wt" 2>/dev/null
      git -C "$proj" branch -D "$lane" 2>/dev/null || true
      ( cd "$proj" && attach_or_create_worktree "$lane" ".worktrees/$lane" "$base" ) \
        || { echo "❌ $lane: worktree recreate failed" >&2; continue; }
    fi
    # 4. Respawn the workspace + ground it (R52) — drop the stale refs entry first.
    local color emoji label new_ref
    case "$lane" in
      senior-*)    color="${SENIOR_COLOR:-Purple}";   emoji="🎓" ;;
      worker-*)    color="${WORKER_COLOR:-Blue}";     emoji="👷" ;;
      co-worker-*) color="${COWORKER_COLOR:-Teal}";   emoji="🧑‍💼" ;;
      watchman-*)  color="${WATCHMAN_COLOR:-Amber}";  emoji="🕵️" ;;
    esac
    label="$emoji $lane"
    new_ref=$(spawn_master_workspace "$label" "$proj/.worktrees/$lane" "$color")
    if [ -n "$new_ref" ]; then
      # rewrite the refs entry (remove old line, append new) — portable, no sed -i.
      grep -v "^${lane}_WS=" "$refs" > "${refs}.tmp" 2>/dev/null && mv "${refs}.tmp" "$refs"
      echo "${lane}_WS=$new_ref" >> "$refs"
      case "$lane" in
        senior-*)    cmux_send "$new_ref" "/kingdom:self-senior" ;;
        worker-*)    cmux_send "$new_ref" "/kingdom:self-worker" ;;
        co-worker-*) cmux_send "$new_ref" "/kingdom:self-co-worker" ;;
        watchman-*)  cmux_send "$new_ref" "/kingdom:self-watchman"; spawn_loop "$new_ref" "/loop" ;;
      esac
      echo "✅ $lane repaired → $new_ref" >&2
    else
      echo "❌ $lane: respawn failed (spawn_master_workspace returned no ref)" >&2
    fi
  done < "$refs"
}
