#!/usr/bin/env bash
# kingdom function: inbox_send
# Two-way inbox (U4, Shared spec 1). Post a message into a recipient's inbox and
# best-effort nudge their workspace.
#   inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>
#     <to>          king | worker-N | co-worker-N | senior-N | watchman-N
#     <type>        question | flag | info | memory-request | docs-update
#     <task_id>     the task this concerns (or "-" if none)
#     <needs_reply> yes | no
#     <message...>  free-text body (remaining args)
# Directory: $WS/.kingdom/<project>/inbox/<to>/ ; file <UTC>__<from>__<type>.md
inbox_send () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally; auto-reverts on return
  local to="$1" type="$2" task="$3" needs="$4"; shift 4 2>/dev/null
  local body="$*"
  if [ -z "$to" ] || [ -z "$type" ]; then
    echo "❌ inbox_send: usage: inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>" >&2
    return 1
  fi
  # `from` = this actor. Lanes export $LANE; the King session doesn't, so default king.
  local from="${LANE:-${KINGDOM_ROLE:-king}}"
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { echo "❌ inbox_send: \$PROJECT unset — cannot locate .kingdom/<project>/inbox" >&2; return 1; }
  # $WS = workspace root; the King session runs from it, so default to $PWD (C9 lesson:
  # never assume $WS is exported).
  local ws_root="${WS:-$PWD}"
  local utc=$(date -u +%Y-%m-%dT%H%MZ)
  local dir="$ws_root/.kingdom/$proj/inbox/$to"
  mkdir -p "$dir" || { echo "❌ inbox_send: cannot create $dir" >&2; return 1; }
  local file="$dir/${utc}__${from}__${type}.md"

  {
    printf -- '---\n'
    printf 'from: %s\n' "$from"
    printf 'to: %s\n' "$to"
    printf 'type: %s\n' "$type"
    printf 'task: %s\n' "${task:--}"
    printf 'needs-reply: %s\n' "${needs:-no}"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$file" || { echo "❌ inbox_send: write failed ($file)" >&2; return 1; }

  echo "📨 inbox: $from → $to ($type${task:+, $task}) → $(basename "$file")"

  # Best-effort nudge: resolve the recipient's workspace ref from workspace-refs.env
  # and fire a cmux notification. Failure is non-fatal (file is the source of truth).
  local refs="$ws_root/.kingdom/$proj/logs/workspace-refs.env"
  if [ -f "$refs" ]; then
    # work.md writes entries as `<lane>_WS=workspace:N` (lowercase lane, e.g.
    # worker-1_WS=workspace:3). Match that exact key first; fall back to an
    # uppercased variant for any older/alternate writer.
    local ref=$(grep -m1 "^${to}_WS=" "$refs" 2>/dev/null | cut -d= -f2)
    [ -z "$ref" ] && ref=$(grep -m1 "^$(printf '%s' "$to" | tr 'a-z-' 'A-Z_')_WS=" "$refs" 2>/dev/null | cut -d= -f2)
    if [ -n "$ref" ] && command -v cmux_notify >/dev/null 2>&1; then
      cmux_notify "$ref" "📨 inbox" "$type from $from" "$body" 2>/dev/null || true
    fi
  fi
  return 0
}
