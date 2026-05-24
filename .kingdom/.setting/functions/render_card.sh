#!/usr/bin/env bash
# kingdom function: render_card

render_card () {
  local card="$1"           # e.g. "welcome" or "welcome/morning" for variants
  local card_file
  case "$card" in
    welcome/morning|welcome/afternoon|welcome/evening|welcome/late)
      card_file="$WS/.kingdom/.setting/cards/welcome.md" ;;
    *)
      card_file="$WS/.kingdom/.setting/cards/${card}.md" ;;
  esac
  [ -f "$card_file" ] || { echo "❌ Card not found: $card_file" >&2; return 1; }

  # Extract the appropriate `## Template` block (variant-aware)
  # ... (full template-extract + envsubst logic; see commands/day.md for invocation example)
  envsubst < "$card_file"
}
