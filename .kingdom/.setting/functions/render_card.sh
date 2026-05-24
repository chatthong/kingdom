#!/usr/bin/env bash
# kingdom function: render_card

render_card () {
  local card="$1"           # "welcome", or a variant like "welcome/morning", "doctor-report/all-pass", "scaffold-success/workspace-only"
  # A "/<variant>" suffix selects a section WITHIN the card; the file is always the part before the "/".
  local base="${card%%/*}"
  local variant=""; [ "$card" != "$base" ] && variant="${card#*/}"
  local card_file="$WS/.kingdom/.setting/cards/${base}.md"
  [ -f "$card_file" ] || { echo "❌ Card not found: $card_file" >&2; return 1; }

  # Extract the appropriate `## Template` block (when $variant is set, pick that variant's
  # section), substitute ${VARS}, then print. See commands/work.md Step 3 for invocation.
  envsubst < "$card_file"
}
