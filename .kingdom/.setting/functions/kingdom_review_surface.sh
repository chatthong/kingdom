#!/usr/bin/env bash
# kingdom function: kingdom_review_surface

kingdom_review_surface () {
  # $BASE unguarded would diff against the broken ref "origin/" — default to develop.
  local base="${BASE:-develop}"
  echo "📋 Review surface — all changes UNCOMMITTED on kingdom:"
  git status --short
  echo ""
  git diff "origin/$base" --stat
}
