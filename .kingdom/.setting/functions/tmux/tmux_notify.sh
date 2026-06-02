#!/usr/bin/env bash
# kingdom function: tmux_notify  (FALLBACK mirror of cmux_notify)
# tmux has no desktop notification, so: (1) flash a transient display-message, (2) glyph the
# SOURCE lane with ⚠ in the sidebar, and (3) ALWAYS write a durable king-inbox fallback file —
# an alert is never only a transient flash (the cmux dead-notify lesson).
#   tmux_notify <ws-ref> <title> <subtitle> <body>
tmux_notify () {
  local ws="$1" title="$2" sub="$3" body="$4"
  tmux display-message "${title}: ${sub} — ${body}" 2>/dev/null
  case "$ws" in *king*|*King*) : ;; *) tmux_set_state "$ws" "⚠" 2>/dev/null ;; esac
  if [ -n "${LOGS:-}" ]; then
    mkdir -p "$LOGS/king-inbox" 2>/dev/null
    printf '# %s\n- %s\n- %s\n' "$title" "$sub" "$body" \
      > "$LOGS/king-inbox/NOTIFY_$(date -u +%Y-%m-%dT%H%M%SZ).md" 2>/dev/null
  fi
}
