#!/usr/bin/env bash
# kingdom function loader (v0.34.0+).
#
# Functions now live one-per-file in this directory. Source this loader, then
# pull only the helpers a run actually calls:
#
#   source "$(dirname "$0")/.kingdom/.setting/functions/_load.sh"
#   load render_card spawn_master_workspace kingdom_overlay_lane
#   spawn_master_workspace "👑 King · myproj" "$PROJ" Amber
#
# A role/feature spec (roles/*.md) lists the function names it uses; pass those
# names to `load`. `load_all` sources everything (rarely needed).

_KFN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load () {
  local f
  for f in "$@"; do
    if [ -f "$_KFN_DIR/$f.sh" ]; then
      # shellcheck disable=SC1090
      source "$_KFN_DIR/$f.sh"
    else
      echo "load: no function file '$f.sh' in $_KFN_DIR (see functions/index.md)" >&2
      return 1
    fi
  done
}

load_all () {
  local f
  for f in "$_KFN_DIR"/*.sh; do
    [ "$(basename "$f")" = "_load.sh" ] && continue
    # shellcheck disable=SC1090
    source "$f"
  done
}

# load_feature <name>… — source a whole feature (its functions + deps) from manifest.json.
# A feature = an entry in ../manifest.json. `load_feature senior` pulls the 7 senior helpers
# (+ its deps, e.g. core). Don't load_feature a feature to leave it out entirely.
_KMANIFEST="$_KFN_DIR/../manifest.json"
load_feature () {
  local feat dep fn
  for feat in "$@"; do
    for dep in $(jq -r --arg f "$feat" '.features[$f].deps[]?' "$_KMANIFEST" 2>/dev/null); do
      load_feature "$dep"
    done
    for fn in $(jq -r --arg f "$feat" '.features[$f].functions[]?' "$_KMANIFEST" 2>/dev/null); do
      load "$fn"
    done
  done
}
