#!/usr/bin/env bash
# kingdom function: haiku_read_docs_orientation

haiku_read_docs_orientation () {
  # Inputs:
  #   $1 = ROLE         — "king" | "worker-1" | "co-worker-2" | "watchman-1" | etc.
  #   $2 = PROJ         — project root
  #   $3 = LOGS         — kingdom logs dir (digests + final context file land here)
  # Env (optional):
  #   HAIKU_CAP         — max parallel Haiku sub-agents (default 10, hard ceiling)
  # Returns:
  #   prints path to consolidated context file on stdout
  local role="$1" proj="$2" logs="$3"
  local cap="${HAIKU_CAP:-10}"; [ "$cap" -gt 10 ] && cap=10
  local utc=$(date -u +%Y-%m-%dT%H%MZ)
  local digest_dir="$logs/.${role}_${utc}_doc_digests"
  local out="$logs/.${role}_${utc}_doc_context.md"
  mkdir -p "$digest_dir"

  # === Phase 1: "you are here" files ===
  # readme.md / index.md / todo*.md in EVERY directory (not just root + docs/).
  # These are the project's wayfinding — read first so subsequent doc reads land
  # in the right mental scaffold.
  #
  # v0.31.1 fix: dropped the `eval "find ..."` indirection. eval was redundant
  # and introduced a quoting vulnerability if $proj contains special chars.
  # Backslash-escaped parens for the prune group work directly in bash.
  local phase1_files
  phase1_files=$(find "$proj" \
    -type d \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build -o -name target -o -name .venv -o -name __pycache__ \) -prune \
    -o -type f \( -iname 'readme.md' -o -iname 'index.md' -o -iname 'todo*.md' \) -print 2>/dev/null | head -30)

  # === Phase 2: full markdown landscape (minus Phase 1) ===
  # v0.31.1: also dropped eval here for the same reason.
  local all_md
  all_md=$(find "$proj" \
    -type d \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build -o -name target -o -name .venv -o -name __pycache__ -o -name test-reports \) -prune \
    -o -type f -name '*.md' -print 2>/dev/null)

  # Subtract Phase 1; sort by mtime desc; cap to 20 newest.
  # v0.31.1 fix: all variable expansions quoted to preserve filenames with spaces.
  # Previous version word-split paths like `docs/My Architecture.md` before sort.
  local phase2_files
  phase2_files=$(comm -23 \
    <(printf '%s\n' "$all_md"      | sort -u) \
    <(printf '%s\n' "$phase1_files" | sort -u) \
    | while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        # Try BSD stat (-f) first, then GNU stat (-c) — explicit if-else avoids
        # silent empty-output from a partially-succeeding stat (rare but real
        # on minimal Alpine containers where neither flavour is GNU).
        if mtime=$(stat -f '%m' "$f" 2>/dev/null); then :
        else mtime=$(stat -c '%Y' "$f" 2>/dev/null); fi
        [ -n "$mtime" ] && printf '%s\t%s\n' "$mtime" "$f"
      done | sort -rn | head -20 | cut -f2-)

  # === Phase 1 fan-out — read wayfinding files first ===
  # Up to $cap Haiku in parallel; bounded by _bounded_wait so one slow read
  # doesn't hang the orientation step (R42).
  local pids="" count=0
  for f in $phase1_files; do
    [ "$count" -ge "$cap" ] && break
    local slug=$(echo "$f" | sed 's|/|_|g; s|^[._]*||; s|\.md$||')
    (
      Agent \
        model="haiku" \
        prompt="Read $f. Write a 5-bullet digest covering:
1. What this file is FOR (purpose / audience)
2. Where it sits in the project (root readme? subdir todo? api index?)
3. Current state it captures (status / open work / decisions locked in)
4. Cross-refs it makes (other docs it points to)
5. Anything a new contributor MUST know from this file before touching nearby code
Output ONLY to $digest_dir/phase1__${slug}.md — no other edits."
    ) &
    pids="$pids $!"; count=$((count+1))
  done
  _bounded_wait 45 $pids   # 45s budget; phase1 files are short

  # === Phase 2 fan-out — full doc landscape ===
  pids=""; count=0
  for f in $phase2_files; do
    [ "$count" -ge "$cap" ] && break
    local slug=$(echo "$f" | sed 's|/|_|g; s|^[._]*||; s|\.md$||')
    (
      Agent \
        model="haiku" \
        prompt="Read $f. Write a 5-bullet digest:
1. One-line purpose
2. Key conventions / patterns / decisions stated here
3. Anything that would override default behaviour for a lane working in this area
4. Pointers to deeper docs it references
5. Last-modified context (is this file fresh or stale?)
Output ONLY to $digest_dir/phase2__${slug}.md — no other edits."
    ) &
    pids="$pids $!"; count=$((count+1))
  done
  _bounded_wait 60 $pids   # 60s budget; phase2 docs can be longer

  # === Consolidate ===
  {
    echo "# Doc orientation for $role — $utc"
    echo ""
    echo "## Source files digested"
    echo ""
    echo "### Phase 1 — wayfinding (readme / index / todo)"
    printf '%s\n' "$phase1_files" | sed 's/^/- /'
    echo ""
    echo "### Phase 2 — broader docs"
    printf '%s\n' "$phase2_files" | sed 's/^/- /'
    echo ""
    echo "---"
    echo ""
    echo "## Phase 1 digests"
    echo ""
    for d in "$digest_dir"/phase1__*.md; do
      [ -f "$d" ] && { echo "### $(basename "$d" .md | sed 's/^phase1__//')"; cat "$d"; echo ""; }
    done
    echo "## Phase 2 digests"
    echo ""
    for d in "$digest_dir"/phase2__*.md; do
      [ -f "$d" ] && { echo "### $(basename "$d" .md | sed 's/^phase2__//')"; cat "$d"; echo ""; }
    done
  } > "$out"

  echo "$out"
}
