#!/usr/bin/env bash
# kingdom function: read_session_state

read_session_state () {
  local state_file="$WS/.kingdom/$PROJECT/state.json"
  [ -f "$state_file" ] || { echo '{"lanes":{},"ready_for_fresh_work":true}'; return 0; }

  # Schema version guard: warn on unknown schema_version
  local schema_version
  schema_version=$(jq -r '.schema_version // "unknown"' "$state_file" 2>/dev/null)
  case "$schema_version" in
    "1") : ;;  # current — proceed
    *)
      echo "⚠️ read_session_state: unknown schema_version=\"$schema_version\" in $state_file — continuing anyway" >&2
      ;;
  esac

  cat "$state_file"
}
