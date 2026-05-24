#!/usr/bin/env bash
# kingdom function: cmux_attention_override

cmux_attention_override () {
  local ws="$1" emoji="$2" subtitle="$3" body="$4" target_ws="${5:-$KING_WS}"

  # Layer 1: badge dot
  cmux workspace-action --action mark-unread --workspace "$ws" 2>/dev/null

  # Layer 2: description override
  cmux workspace-action --action set-description \
    --workspace "$ws" --description "$emoji $subtitle" 2>/dev/null

  # Layer 3: dual notify (own surface + King's workspace)
  cmux notify --surface "$ws" \
    --title "$emoji" --subtitle "$subtitle" --body "$body" 2>/dev/null
  cmux notify --workspace "$target_ws" \
    --title "$emoji" --subtitle "$subtitle" --body "$body" 2>/dev/null
}
