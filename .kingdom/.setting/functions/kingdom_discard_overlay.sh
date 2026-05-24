#!/usr/bin/env bash
# kingdom function: kingdom_discard_overlay

kingdom_discard_overlay () {
  git checkout kingdom
  git restore .   # drops uncommitted working-tree changes
}
