#!/usr/bin/env bash
# kingdom function: tmux_notify  (FALLBACK mirror of cmux_notify)
# tmux has no desktop notification, so: (1) flash a transient display-message, (2) glyph the
# SOURCE lane with ⚠ in the sidebar, and (3) ALWAYS write a durable inbox message for the King —
# an alert is never only a transient flash (the cmux dead-notify lesson).
#   tmux_notify <ws-ref> <title> <subtitle> <body>
#
# R55: the durable fallback writes to the SHARED BROKER feed (one flat dir) at
#   <workspace>/.kingdom/<project>/inbox/<UTC>__<from>__king__flag.md
# (NOT a per-recipient inbox/king/ subdir — inbox_list/inbox_pending_count glob only inbox/*.md,
# so a subdir write would be invisible to the King's drain). The project dir is derived the same
# way the old king-inbox code did: $PROJECT if exported, else the dir just above logs/ in $LOGS.
tmux_notify () {
  local ws="$1" title="$2" sub="$3" body="$4"
  tmux display-message "${title}: ${sub} — ${body}" 2>/dev/null
  # Glyph the source lane ⚠ — but only when ws is non-empty (an empty ws would target the
  # invalid "kingdom:" handle). Never glyph the King's own window.
  if [ -n "$ws" ]; then
    # Test the SLUG, not the whole ref (the session name often contains "kingdom").
    case "${ws##*:}" in king|King) : ;; *) tmux_set_state "$ws" "⚠" 2>/dev/null ;; esac
  fi

  # Durable inbox write (R55 shared broker feed). Resolve the flat inbox dir.
  local inbox=""
  if [ -n "${PROJECT:-}" ]; then
    inbox="${PWD}/.kingdom/${PROJECT}/inbox"
  elif [ -n "${LOGS:-}" ]; then
    # $LOGS is .../.kingdom/<project>/logs → its parent is .../.kingdom/<project>.
    inbox="${LOGS%/logs}/inbox"
  fi
  [ -z "$inbox" ] && return 0   # no resolvable project dir; the transient flash already fired

  mkdir -p "$inbox" 2>/dev/null || return 0
  local utc from slug file
  utc="$(date -u +%Y-%m-%dT%H%MZ)"
  # "from" = the notifying lane slug if ws is a lane ref, else "system".
  # Strip the "<session>:" prefix FIRST (the session name often contains "kingdom", so a
  # whole-ref *king* test would mis-classify every lane as the King → "system").
  slug="${ws##*:}"
  case "$slug" in
    ""|king|King) from="system" ;;
    *)            from="$slug" ;;
  esac
  file="$inbox/${utc}__${from}__king__flag.md"
  {
    printf -- '---\n'
    printf 'from: %s\n' "$from"
    printf 'to: king\n'
    printf 'type: flag\n'
    printf 'task: -\n'
    printf 'needs-reply: no\n'
    printf -- '---\n'
    printf '# %s\n- %s\n- %s\n' "$title" "$sub" "$body"
  } > "$file" 2>/dev/null
  return 0
}
