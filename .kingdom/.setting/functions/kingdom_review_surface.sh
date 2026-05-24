#!/usr/bin/env bash
# kingdom function: kingdom_review_surface

kingdom_review_surface () {
  echo "📋 Review surface — all changes UNCOMMITTED on kingdom:"
  git status --short
  echo ""
  git diff "origin/$BASE" --stat
}
