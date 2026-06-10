#!/usr/bin/env bash
# kingdom function: render_card

render_card () {
  local card="$1"           # "welcome", or a variant like "welcome/morning", "doctor-report/all-pass", "scaffold-success/workspace-only"
  # A "/<variant>" suffix selects a section WITHIN the card; the file is always the part before the "/".
  local base="${card%%/*}"
  local variant=""; [ "$card" != "$base" ] && variant="${card#*/}"

  # C9: resolve the cards/ root robustly. No command file sets $WS, so a bare
  # "$WS/.kingdom/.setting/cards/…" path resolved to "/.kingdom/…" → "Card not
  # found" on every render. Prefer $WS when set; otherwise derive from $_KFN_DIR
  # (set by _load.sh, points at functions/ — so its parent is .setting/).
  local card_file=""
  if [ -n "${WS:-}" ] && [ -f "$WS/.kingdom/.setting/cards/${base}.md" ]; then
    card_file="$WS/.kingdom/.setting/cards/${base}.md"
  elif [ -n "${_KFN_DIR:-}" ] && [ -f "$_KFN_DIR/../cards/${base}.md" ]; then
    card_file="$_KFN_DIR/../cards/${base}.md"
  fi
  if [ -z "$card_file" ] || [ ! -f "$card_file" ]; then
    echo "❌ Card not found: ${base}.md (looked under \$WS/.kingdom/.setting/cards and \$_KFN_DIR/../cards — is _load.sh sourced / \$WS set?)" >&2
    return 1
  fi

  # Variant extraction: cards group their renderable bodies under `### <Heading>`
  # sections. When a variant is requested, slice out only the matching section
  # (heading line up to the next `###`/`##`) before substitution. Match on the
  # heading's FIRST word vs the variant's first token — card headings carry extra
  # prose (`### Morning (05:00-11:59)`, `### Failed (manual action required)`)
  # while callers pass clean slugs (morning, failed). If no variant is given, or
  # no section matches (e.g. a card with no `###` variants), render the whole file.
  local content
  if [ -n "$variant" ]; then
    local vkey="${variant%%[- ]*}"   # first token of the variant slug
    content=$(awk -v vkey="$vkey" '
      function slugfirst(s,   t) { t = tolower(s); sub(/^#+[ \t]*/, "", t); sub(/[ \t(].*/, "", t); return t }
      /^###[ \t]/ {
        if (slugfirst($0) == tolower(vkey)) { grab = 1; next }
        else if (grab) { grab = 0 }
        next
      }
      /^##[ \t]/ { if (grab) grab = 0 }
      grab { print }
    ' "$card_file")
    [ -n "$content" ] || content=$(cat "$card_file")   # no matching section → whole file
  else
    content=$(cat "$card_file")
  fi

  # Substitute ${VARS} then print. See commands/work.md Step 3 for invocation.
  printf '%s\n' "$content" | envsubst
}
