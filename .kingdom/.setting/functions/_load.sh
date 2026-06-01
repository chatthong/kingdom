#!/usr/bin/env bash
# kingdom function loader (v0.34.0+).
#
# Functions live one-per-file. Most sit flat in this directory; provider-scoped
# wrappers live in a subfolder (e.g. functions/cmux/, functions/tmux/ later) so
# each dispatch backend stays self-contained. `load` resolves a bare name in either
# place, so callers + manifest.json never need to know the path.
#
#   source "$(dirname "$0")/.kingdom/.setting/functions/_load.sh"
#   load render_card spawn_master_workspace kingdom_overlay_lane
#   spawn_master_workspace "👑 King · myproj" "$PROJ" Amber
#
# A role/feature spec (roles/*.md) lists the function names it uses; pass those
# names to `load`. `load_all` sources everything (rarely needed).

# zsh-safe self-location. Claude Code's Bash tool runs zsh on macOS, where
# ${BASH_SOURCE[0]} is empty — _KFN_DIR would resolve to cwd and every `load`
# would fail with "command not found". The eval hides zsh-only syntax from
# bash's parser (bash treats it as an opaque string); only zsh ever runs it.
if [ -n "${ZSH_VERSION:-}" ]; then
  eval '_KFN_DIR="${${(%):-%x}:A:h}"'   # zsh: %x = file being sourced; :A:h = absolute dirname
else
  _KFN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
fi

load () {
  local f path
  for f in "$@"; do
    if [ -f "$_KFN_DIR/$f.sh" ]; then
      path="$_KFN_DIR/$f.sh"
    else
      # fall back to one level of provider/feature subfolders (cmux/, tmux/, browser/, …).
      # `find` instead of a shell glob: zsh aborts the whole function on a no-match
      # glob (NOMATCH), and the 2>/dev/null on `ls` can't suppress that.
      path=$(find "$_KFN_DIR" -mindepth 2 -maxdepth 2 -name "$f.sh" 2>/dev/null | head -1)
    fi
    if [ -n "$path" ] && [ -f "$path" ]; then
      # shellcheck disable=SC1090
      source "$path"
    else
      echo "load: no function file '$f.sh' in $_KFN_DIR or its subfolders (see functions/index.md)" >&2
      return 1
    fi
  done
}

load_all () {
  local f
  # flat files + one level of subfolders, via `find` (zsh-safe: a glob with no
  # match aborts the function under zsh's NOMATCH; find never does).
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "_load.sh" ] && continue
    # shellcheck disable=SC1090
    source "$f"
  done < <(find "$_KFN_DIR" -mindepth 1 -maxdepth 2 -name '*.sh')
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
