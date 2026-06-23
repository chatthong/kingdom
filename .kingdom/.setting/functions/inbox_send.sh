#!/usr/bin/env bash
# kingdom function: inbox_send
# Broker inbox (R55). Post a message into the single shared feed and best-effort
# doorbell the addressed actor.
#   inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>
#     <to>          king | worker-N | co-worker-N | senior-N | watchman-N | all
#     <type>        question | flag | info | memory-request | docs-update
#     <task_id>     the task this concerns (or "-" if none)
#     <needs_reply> yes | no
#     <message...>  free-text body (remaining args)
# Directory: $WS/.kingdom/<project>/inbox/   (ONE flat feed, NOT per-recipient)
# Filename:  <UTC>__<from>__<to>__<type>.md
# Everyone may READ the whole feed. Only the addressed actor (to==me or to==all) OWNS
# the action + consume. A non-addressed reader NEVER consumes someone else's message.
inbox_send () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally; auto-reverts on return
  local to="$1" type="$2" task="$3" needs="$4"; shift 4 2>/dev/null
  local body="$*"
  if [ -z "$to" ] || [ -z "$type" ]; then
    printf 'inbox_send: usage: inbox_send <to> <type> <task_id> <needs_reply yes|no> <message...>\n' >&2
    return 1
  fi
  # `from` = this actor. Lanes export $LANE; the King session doesn't, so default king.
  local from="${LANE:-${KINGDOM_ROLE:-king}}"
  local proj="${PROJECT:-}"
  [ -n "$proj" ] || { printf 'inbox_send: $PROJECT unset — cannot locate .kingdom/<project>/inbox\n' >&2; return 1; }
  # $WS = workspace root; the King session runs from it, so default to $PWD.
  local ws_root="${WS:-$PWD}"
  local utc; utc=$(date -u +%Y-%m-%dT%H%MZ)
  local inboxdir="$ws_root/.kingdom/$proj/inbox"
  mkdir -p "$inboxdir" || { printf 'inbox_send: cannot create %s\n' "$inboxdir" >&2; return 1; }
  # Filename encodes both from AND to so the whole feed is readable without opening files.
  local msgfile="$inboxdir/${utc}__${from}__${to}__${type}.md"

  {
    printf -- '---\n'
    printf 'from: %s\n' "$from"
    printf 'to: %s\n' "$to"
    printf 'type: %s\n' "$type"
    printf 'task: %s\n' "${task:--}"
    printf 'needs-reply: %s\n' "${needs:-no}"
    printf -- '---\n'
    printf '%s\n' "$body"
  } > "$msgfile" || { printf 'inbox_send: write failed (%s)\n' "$msgfile" >&2; return 1; }

  printf '📨 inbox: %s → %s (%s%s) → %s\n' "$from" "$to" "$type" "${task:+, $task}" "$(basename "$msgfile")"

  # Best-effort doorbell: resolve the addressed actor's workspace ref from
  # workspace-refs.env and fire cmux_notify. Failure is non-fatal (file is source of truth).
  # Resolution order:
  #   1. Exact lowercase key:   ^<to>_WS=   (e.g. worker-1_WS=, watchman-1_WS=)
  #   2. Uppercase key:         ^KING_WS=   style via tr 'a-z-' 'A-Z_'
  #      (e.g. 'king' → KING_WS=, 'senior-1' → SENIOR_1_WS=)
  # 'all' broadcasts: iterate every *_WS= line in the env file.
  local refs="$ws_root/.kingdom/$proj/logs/workspace-refs.env"
  if [ -f "$refs" ] && command -v cmux_notify >/dev/null 2>&1; then
    local ref
    if [ "$to" = "all" ]; then
      # Broadcast: notify every workspace listed, skip empty values.
      while IFS='=' read -r _key _val; do
        case "$_key" in *_WS)
          [ -n "$_val" ] && cmux_notify "$_val" "📨 inbox" "$type from $from (all)" "$body" 2>/dev/null || true
        esac
      done < "$refs"
    else
      # Addressed: try lowercase key first, then uppercase fallback.
      ref=$(grep -m1 "^${to}_WS=" "$refs" 2>/dev/null | cut -d= -f2-)
      if [ -z "$ref" ]; then
        local ukey; ukey=$(printf '%s' "$to" | tr 'a-z-' 'A-Z_')
        ref=$(grep -m1 "^${ukey}_WS=" "$refs" 2>/dev/null | cut -d= -f2-)
      fi
      [ -n "$ref" ] && cmux_notify "$ref" "📨 inbox" "$type from $from" "$body" 2>/dev/null || true
    fi
  fi
  return 0
}
