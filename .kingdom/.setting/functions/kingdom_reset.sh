#!/usr/bin/env bash
# kingdom function: kingdom_reset

kingdom_reset () {
  git checkout kingdom
  git fetch origin
  git reset --hard "origin/$BASE"
}
