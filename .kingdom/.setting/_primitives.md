# _primitives.md — Shared bash helpers

> The canonical implementations of every helper function referenced across role docs. Each role doc (`kings.md`, `workers.md`, `co-workers.md`, `watchmans.md`, `cmux.md`, `git.md`) points HERE for the actual code; the role docs say WHEN to use each helper, this file says HOW.

Goal: single source of truth for shared bash patterns. Edit the helper once, every role doc inherits the fix.

---

## Bounded parallel wait — never block forever on a bare `wait` (v0.30.0+, R42)

Bare `wait` blocks until **every** backgrounded subshell exits. If any one hangs (a `git worktree add` blocked on `.git/index.lock`, a `cmux send` to a not-yet-ready workspace, a `gh pr view` on a stale network connection), the parent script hangs forever. The Claude Code harness then auto-pushes the bash call to background and the user sees "Job's output is empty."

`_bounded_wait` enforces a global wall-clock budget: if any PID exceeds it, every surviving PID is `kill -9`ed and the function returns `124` (the conventional GNU-timeout exit code, even though we don't use GNU timeout).

```bash
_bounded_wait () {
  # Inputs:
  #   $1     = max_seconds   (global wall-clock budget; e.g. 60 for spawn, 30 for teardown)
  #   $2..$N = PIDs to wait for (default = all current background jobs from `jobs -p`)
  # Output:
  #   stderr line on timeout listing killed PIDs
  # Returns:
  #   0   — all PIDs exited cleanly within budget
  #   124 — global timeout; surviving PIDs killed (matches GNU `timeout` convention)
  #   N   — first non-zero per-PID exit code if any subshell errored
  local max="$1"; shift
  local pids="${*:-$(jobs -p)}"
  [ -z "$pids" ] && return 0

  local start=$(date +%s)
  local rc=0
  for pid in $pids; do
    while kill -0 "$pid" 2>/dev/null; do
      local now=$(date +%s)
      if [ $((now - start)) -ge "$max" ]; then
        local survivors=""
        for p in $pids; do
          kill -0 "$p" 2>/dev/null && { kill -9 "$p" 2>/dev/null; survivors="$survivors $p"; }
        done
        echo "⚠️ _bounded_wait timeout after ${max}s; killed:$survivors" >&2
        return 124
      fi
      sleep 0.5
    done
    wait "$pid" 2>/dev/null
    local pid_rc=$?
    [ "$pid_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$pid_rc"
  done
  return $rc
}
```

**Budget guidance:**

| Site | Recommended budget | Reasoning |
|---|---|---|
| King workspace-rename fan-out | `5s` | 4 cmux calls × <0.05s each = 0.2s nominal |
| All-lane spawn cycle | `60s` | `git worktree add` + 4 cmux calls per lane × N lanes |
| `parallel_edit_fanout` | `45s` | `gh pr view` + `sed` + `git commit` + `git push --force-with-lease` |
| Save-cycle teardown | `15s` | `cmux close-workspace` per lane (read-after-detach can stall) |
| Watchman orphan-tab sweep | `10s` | `cmux tab-action --action close` per stale tab |

Used by: `commands/work.md` Step 0.4 (King rename + lane spawn), `commands/save.md` teardown, `watchmans.md` orphan-tab sweep, `_primitives.md` `parallel_edit_fanout`. Replaces every bare `wait` in load-bearing fan-outs (see R42).

---

## State + UX helpers

### `cmux_set_state` — update workspace description (live status line)

```bash
cmux_set_state () {
  local ws="${1:-$CMUX_WORKSPACE_ID}" emoji="$2" text="$3"
  cmux workspace-action --action set-description \
    --workspace "$ws" \
    --description "$emoji $text" 2>/dev/null
}

# Usage:
cmux_set_state "$CMUX_WORKSPACE_ID" "▶" "BE-AUTH-3 · ▰▰▰▱ L3 Execution"
cmux_set_state "$KING_WS"           "⚠" "Push? · worker-2 · BE-AUTH-3"
cmux_set_state "$CMUX_WORKSPACE_ID" "🐾" "Awaiting dispatch"
```

State-emoji vocabulary: `▶` running · `⏸` waiting · `⚠` needs attention · `✅` done · `❌` failed · `🐾` idle · `▰▰▰▱` progress bar. Failure is silent — descriptions are cosmetic, not load-bearing.

### `cmux_attention_override` — 3-layer state override (badge + description + notify)

For when cmux's auto-state is wrong and the kingdom KNOWS better (blocked lane, push prompt, gate fail, etc):

```bash
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

# Clear the override when state resolves
cmux_attention_clear () {
  cmux workspace-action --action mark-read --workspace "${1:-$CMUX_WORKSPACE_ID}" 2>/dev/null
}
```

---

## Worktree + branch helpers

### `attach_or_create_worktree` — silent idempotent worktree setup

Three cases handled — never prompts:

```bash
attach_or_create_worktree () {
  local branch="$1" path="$2" base="${3:-develop}"

  # Case A: worktree directory exists → reuse silently
  [ -d "$path" ] && return 0

  # Case B: branch exists (prior kingdom session) → attach silently
  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git worktree add "$path" "$branch" 2>/dev/null
    return $?
  fi

  # Case C: neither exists → create fresh from origin/<base>
  git worktree add -b "$branch" "$path" "origin/$base" 2>/dev/null
}
```

Used by `commands/start.md` Phase 4. Reserved branch namespace: `worker-N` / `co-worker-N` / `watchman-N` / `kingdom`. Manual branches outside this namespace require user resolution.

---

## Hard gates — enforce critical rules at call-site, not in prose (v0.31.0+)

> **Why these exist:** v0.30.0 and earlier encoded R4, R9, R30, R36, R37 as prose in `rules.md`. The 2026-05-20 morning incident showed Kings still violating all of them — committing on `feature/*` instead of `worker-N` (R9), FF-merging onto `kingdom` (R4), `cd`-ing into worker worktrees from the King's session (R30+R37), skipping the workspace-spawn step entirely (R36). Prose isn't a gate. These helpers ARE gates: they call `return 1` on violation and the calling script's `set -e` propagates the failure. Source the helpers, then ANY commit / dispatch / overlay in role docs flows through them. If the King's bash environment doesn't have these sourced, that itself is a setup bug.

### `guard_worker_commit_branch` — block commits on wrong branch from worker worktrees (R4 + R9)

A `git commit` inside `.worktrees/worker-N/` must land on the `worker-N` lane branch — NEVER on `feature/<topic>` (those get carved at push time per R9), and NEVER on `kingdom` (R4). This guard is called before any commit in a lane worktree.

```bash
guard_worker_commit_branch () {
  # Inputs:
  #   $1 = worktree path (defaults to $PWD)
  # Returns:
  #   0  — current branch is acceptable for committing here
  #   1  — R4 or R9 violation; commit MUST NOT proceed
  local wt="${1:-$PWD}"
  local current=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
  local wt_name=$(basename "$wt")

  # Case A: kingdom branch — R4 absolute ban
  if [ "$current" = "kingdom" ]; then
    echo "❌ R4 VIOLATION: commits forbidden on \`kingdom\` branch. It's a dirty working-tree overlay; never advances past origin/develop. Fix: git stash → git switch <worker-N> → git stash pop → re-commit." >&2
    return 1
  fi

  # Case B: feature/* branch in any worktree — R9 absolute ban
  case "$current" in
    feature/*)
      echo "❌ R9 VIOLATION: commits forbidden on \`$current\`. feature branches are CARVED from worker-N tips at push time (byte-for-byte). Fix: git branch -f $wt_name HEAD && git switch $wt_name && git branch -D $current → re-commit." >&2
      return 1
      ;;
  esac

  # Case C: worker-N / co-worker-N / watchman-N worktree but branch name doesn't match
  case "$wt_name" in
    worker-*|co-worker-*|watchman-*)
      if [ "$current" != "$wt_name" ]; then
        echo "❌ R21 + R9 VIOLATION: worktree \`$wt_name\` but current branch \`$current\` ≠ lane branch. Each worktree commits ONLY on its matching lane branch. Fix: git switch $wt_name (creates if missing from base)." >&2
        return 1
      fi
      ;;
  esac

  return 0
}
```

Usage in role docs and wrapper scripts:

```bash
# In workers.md task close-out, watchmans.md PR-backfill, anywhere a commit lands in a worker worktree:
guard_worker_commit_branch "$WT" || exit 1
git -C "$WT" add ...
git -C "$WT" commit -m "..."
```

### `guard_lane_workspace_exists` — block dispatch if lane workspace not visible in cmux (R31 + R36)

R31 says "lane infrastructure spawned + verified BEFORE any dispatch." R36 says "visible workspace progress within ~10s." Both routinely skipped. This guard makes dispatch fail-fast when the lane workspace isn't in `cmux list-workspaces` output.

```bash
guard_lane_workspace_exists () {
  # Inputs:
  #   $1 = lane name (worker-1, co-worker-1, watchman-1, etc.)
  # Returns:
  #   0  — lane workspace visible in cmux + worktree exists; dispatch may proceed
  #   1  — R31/R36 violation; dispatch MUST NOT fire
  local lane="$1"
  local proj_dir="${PROJ:-$PWD}"

  # Worktree check (universal, mode-agnostic per R31 expanded)
  if [ ! -d "$proj_dir/.worktrees/$lane" ]; then
    echo "❌ R31 VIOLATION: worktree .worktrees/$lane missing. Run attach_or_create_worktree before dispatch." >&2
    return 1
  fi

  # cmux workspace check (PRIMARY mode only — AGENT fallback skips this)
  if ! command -v cmux >/dev/null 2>&1; then
    return 0  # FALLBACK/AGENT mode — worktree existence is enough
  fi

  local ws_list=$(cmux list-workspaces 2>/dev/null)
  if [ -z "$ws_list" ]; then
    return 0  # cmux not running; not PRIMARY mode
  fi

  # Look for the lane label in workspace titles (matches "👷 worker-1", "👑 King · ...", etc.)
  if ! echo "$ws_list" | grep -qE "(👷|🧑‍💼|🕵️|👑).*$lane\b|\b$lane\b"; then
    echo "❌ R31 + R36 VIOLATION: lane $lane has no workspace in cmux sidebar. Run spawn_master_workspace before dispatch. Without a visible workspace, the user sees nothing happening (R36 'stuck on fan-out' anti-pattern)." >&2
    return 1
  fi

  return 0
}
```

Usage:

```bash
# In kings.md Step 4 dispatch, work.md Step 4, anywhere a brief is sent to a lane:
guard_lane_workspace_exists "$LANE" || exit 1
cmux rpc surface.send_text "{\"surface_id\":\"...\",\"text\":\"...\"}"
```

### `guard_no_king_session_worktree_cd` — block King's main session from `cd`-ing into a lane worktree (R30 + R37)

R30 says "King is orchestrator-only." R37 says "heavy processing runs IN lane workspaces, not in King's session." The combined violation looks like `cd $PROJ/.worktrees/worker-1 && git commit ...` directly from the King's session — work runs invisibly to the user (no cmux progress), bypasses the workspace pattern entirely, and breaks R30/R37.

```bash
guard_no_king_session_worktree_cd () {
  # Inputs:
  #   $1 = target path being cd'd into
  #   $2 = optional caller role (defaults to whatever $KINGDOM_ROLE is set to; "king" if unset)
  # Returns:
  #   0  — cd is allowed (not King, or target isn't a lane worktree)
  #   1  — R30/R37 violation; cd MUST NOT proceed
  local target="$1"
  local role="${2:-${KINGDOM_ROLE:-king}}"

  # Non-king roles (lanes themselves) cd freely
  [ "$role" != "king" ] && return 0

  # Resolve target to absolute path
  local abs=$(cd "$target" 2>/dev/null && pwd)
  [ -z "$abs" ] && return 0  # target doesn't exist; let the cd fail naturally

  # Detect: is target inside a .worktrees/<lane>/ directory?
  case "$abs" in
    */.worktrees/worker-*|*/.worktrees/co-worker-*|*/.worktrees/watchman-*)
      local lane=$(basename "$abs")
      echo "❌ R30 + R37 VIOLATION: King session attempting to cd into $lane worktree. King is orchestrator-only — heavy processing belongs IN the lane workspace, not the King's session. Fix: cmux rpc surface.send_text into the lane's surface, OR (for trivial reads) use git -C \"$abs\" <cmd> without changing directory." >&2
      return 1
      ;;
  esac

  return 0
}
```

Usage (wraps the `cd` in role docs that the King is meant to run):

```bash
# In any King-side helper that touches lane content:
LANE_WT="$PROJ/.worktrees/worker-1"

# WRONG — direct cd from King session:
# cd "$LANE_WT" && git commit -m "..."

# RIGHT — guarded:
guard_no_king_session_worktree_cd "$LANE_WT" || exit 1   # blocks if called from King
# (you'll never reach here from King; lane runs the commit in its own workspace)

# RIGHT for trivial reads (no cd):
git -C "$LANE_WT" log -1 --oneline
git -C "$LANE_WT" diff --stat
```

### `kingdom_overlay_lane` — auto-overlay a worker's diff onto kingdom as dirty (R15 enforcement)

After every worker sentinel, the kingdom branch should auto-overlay the worker's diff as uncommitted changes — that's the review surface (per R15 + branch-model.md). The 2026-05-20 incident: King carved/committed on `feature/*` instead of overlaying. This helper makes the correct overlay flow callable in one line.

```bash
kingdom_overlay_lane () {
  # Inputs:
  #   $1 = project directory (the worktree on kingdom branch)
  #   $2 = lane name (worker-1, worker-2, etc.)
  #   $3 = base branch (default: develop)
  # Returns:
  #   0 — overlay applied as dirty changes; kingdom HEAD unchanged
  #   1 — overlay refused (R4 guard, or git apply conflict)
  local proj="$1" lane="$2" base="${3:-develop}"

  # Guard 1: kingdom branch must be currently checked out in proj
  local current=$(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$current" != "kingdom" ]; then
    echo "❌ R4 GUARD: kingdom_overlay_lane called but $proj is on $current, not kingdom. Refusing." >&2
    return 1
  fi

  # Guard 2: kingdom HEAD must equal origin/$base (no rogue commits per R4)
  local king_sha=$(git -C "$proj" rev-parse HEAD)
  local base_sha=$(git -C "$proj" rev-parse "origin/$base")
  if [ "$king_sha" != "$base_sha" ]; then
    echo "❌ R4 GUARD: kingdom HEAD ($king_sha) ≠ origin/$base ($base_sha). Run \`git reset --hard origin/$base && git clean -fd\` first." >&2
    return 1
  fi

  # Apply lane's diff as dirty working-tree changes
  if ! git -C "$proj" diff "origin/$base..$lane" | git -C "$proj" apply --3way; then
    echo "❌ overlay failed: git apply --3way returned non-zero for $lane → kingdom" >&2
    return 1
  fi

  echo "✅ overlay applied: $lane diff is now dirty on kingdom (HEAD still $base_sha)" >&2
  return 0
}
```

Usage in `kings.md` Step 7 (auto-fires on every worker sentinel — no longer manual):

```bash
# After detecting a fresh sentinel for worker-N:
kingdom_overlay_lane "$PROJ" "worker-$N" "$BASE" || return 1
# Now user can review the combined dirty overlay in their IDE
```

### `spawn_watchman_loop` — auto-dispatch `/loop` to a watchman workspace (R39)

R39 says watchman runs autonomously. Claude REPL is already up after `spawn_master_workspace` (v0.31.1+ — explicit `claude\n` baked into the spawn helper). This helper does the **watchman-only extra step**: send `/loop\n` so the watchman starts ticking immediately.

```bash
spawn_watchman_loop () {
  # Inputs:
  #   $1 = watchman workspace ref (e.g., workspace:7) — output of spawn_master_workspace
  # Returns:
  #   0 — /loop dispatch fired
  #   1 — dispatch failed (workspace not ready, surface not resolvable)
  local ws_ref="$1"

  # Find the surface inside this workspace (claude REPL is the receiver — already
  # launched by spawn_master_workspace Step 1b)
  local surface=$(cmux rpc workspace.list 2>/dev/null \
    | jq -r ".[] | select(.ref == \"$ws_ref\") | .surfaces[0].ref" 2>/dev/null)

  if [ -z "$surface" ] || [ "$surface" = "null" ]; then
    echo "❌ spawn_watchman_loop: no surface found in $ws_ref" >&2
    return 1
  fi

  # Send /loop to the already-running claude REPL.
  # v0.31.1: the prior `claude\n` send + sleep was removed — that's now
  # spawn_master_workspace's job. Sending /loop here while claude is still
  # booting is safe because cmux buffers surface input until the receiver is
  # ready (Step 1b's 1.5s sleep gives the REPL time to attach).
  cmux rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"/loop\n\"}" 2>/dev/null

  return 0
}
```

Usage in `commands/work.md` Step 0.4 (lane spawn) — wrap the existing spawn call:

```bash
# Existing: spawn_master_workspace "🕵️ watchman-1" "$PROJ/.worktrees/watchman-1" "Rose"
WS_REF=$(spawn_master_workspace "🕵️ watchman-1" "$PROJ/.worktrees/watchman-1" "Rose")
# v0.31.0+: claude is already running by the time spawn_master_workspace returns;
# this only adds the /loop dispatch for watchmen.
case "$WS_REF" in workspace:*) spawn_watchman_loop "$WS_REF" & ;; esac
```

---

## Orientation — Haiku-army doc read (v0.31.1+, R45)

**Every role** (King, worker-N, co-worker-N, watchman-N) calls this when it needs the project's big picture — at session start, at new-task receipt, or any time it's *not sure* about a documented convention. The protocol fans out cheap Haiku reads in parallel so the calling role's own context window stays uncluttered.

### `haiku_read_docs_orientation` — parallel doc digest

```bash
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
```

### Calling protocol (R45)

| Caller | When | What it does with the output |
|---|---|---|
| **King** | At `/kingdom:work` session start, immediately after R14 context read | Reads the consolidated file once; uses it to ground all dispatch briefs that tick |
| **worker-N / co-worker-N** | At task brief receipt (before any code edit, Layer 1 of the 4-layer worker flow) | Reads ONLY the Phase 1 wayfinding section + any Phase 2 digest matching its task keywords (the calling role decides relevance) |
| **watchman-N** | Once at spawn; then refreshed every 10 `/loop` ticks (or when any *.md in root/docs/ changes mtime) | Becomes the doc-context cache for Duty 1's senior-dev review (see `watchmans.md` § Duty 1) |
| **Any role, "not sure"** | When the role can't confirm a pattern, convention, or decision from its current context | One-shot call; reads the new digest before answering / dispatching |

**Hard ceiling:** `HAIKU_CAP=10` per call (the user-facing limit; helper enforces). If a project has >30 `.md` files, Phase 2 reads only the 20 newest — older docs are deemed less likely to reflect current truth. If full coverage is needed, raise the cap or split into multiple calls.

**Cost rough-out:** each Haiku call ~300 input + ~150 output tokens for a 5-bullet digest. 30 files × 450 tokens ≈ 14k Haiku tokens per orientation pass. At Haiku 4.5 pricing this is sub-penny. Fast (parallel) and cheap by design — that's why it's the doc-reading mechanism instead of having the calling role read everything itself.

---

## Workspace spawn — 4-call pattern (master workspaces)

`cmux new-workspace --name "X"` doesn't make the sidebar show "X" (cmux auto-renames to the active surface title like `"✳ Claude Code"`). The kingdom enforces a **4-call** sequence per master to make name + color + description actually stick:

```bash
spawn_master_workspace () {
  local label="$1" path="$2" color="$3"

  # v0.27.0+: respect kingdom.json.cmux.spawnWindow for multi-window users
  # Default = "current": no --window flag → sticks to caller's process window
  # Other valid values: "new" (open fresh window), "window:N" / "window:<uuid>" (explicit ref)
  local spawn_window=$(jq -r '.cmux.spawnWindow // "current"' "$KJSON" 2>/dev/null)
  local window_flag=""
  case "$spawn_window" in
    current|"") window_flag="" ;;
    new)
      # Lazy-create the kingdom window once; cache UUID in workspace-refs.env
      if ! grep -q '^KING_WINDOW=' "$LOGS/workspace-refs.env" 2>/dev/null; then
        local king_win=$(cmux new-window 2>&1 | grep -oE '[A-F0-9-]{36}' | head -1)
        [ -n "$king_win" ] && echo "KING_WINDOW=$king_win" >> "$LOGS/workspace-refs.env"
      fi
      local cached_win=$(grep '^KING_WINDOW=' "$LOGS/workspace-refs.env" | cut -d= -f2)
      [ -n "$cached_win" ] && window_flag="--window $cached_win"
      ;;
    *)
      # Explicit ref/index passed through
      window_flag="--window $spawn_window"
      ;;
  esac

  # Step 1: create the workspace (capture ref via grep -oE — awk pipelines break in some shells).
  #
  # v0.31.1: dropped `--command "claude"`. Consumer-tested 2026-05-21: the flag
  # was unreliable across cmux versions — workspaces frequently came up at a
  # bash prompt and King's subsequent `cmux send -- "<brief>"` landed in the
  # shell. Explicit post-spawn `claude\n` (Step 1b below) replaces it; the
  # `spawn_watchman_loop` helper already proved this pattern works.
  local result=$(cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --focus false \
    $window_flag 2>&1)
  local ref=$(echo "$result" | grep -oE 'workspace:[0-9]+' | head -1)
  [ -z "$ref" ] && { echo "❌ spawn failed: $result" >&2; return 1; }

  # Step 1b (v0.31.1): explicitly launch claude in the workspace's surface.
  # Without this, the workspace sits at a bash prompt and dispatch briefs
  # sent later via `cmux send` land in the shell — silent failure mode.
  local surface=$(cmux rpc workspace.list 2>/dev/null \
    | jq -r ".[] | select(.ref == \"$ref\") | .surfaces[0].ref" 2>/dev/null)
  if [ -n "$surface" ] && [ "$surface" != "null" ]; then
    cmux rpc surface.send_text "{\"surface_id\":\"$surface\",\"text\":\"claude\n\"}" 2>/dev/null
    sleep 1.5   # claude boot — same budget proven by spawn_watchman_loop
  else
    echo "⚠️ $label: no surface found post-spawn; claude REPL not launched. Dispatch will land in shell." >&2
  fi

  # Step 2: FORCE sidebar name (override "✳ Claude Code" auto-title)
  cmux workspace-action --action rename --workspace "$ref" --title "$label" 2>/dev/null

  # Step 3: set color (new-workspace doesn't accept --color)
  [ -n "$color" ] && \
    cmux workspace-action --action set-color --workspace "$ref" --color "$color" 2>/dev/null

  # Step 4: force-set description (auto-title can clobber what new-workspace --description set)
  cmux workspace-action --action set-description \
    --workspace "$ref" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" 2>/dev/null

  echo "$ref"
}
```

**Multi-window confirmation (tested 2026-05-19 in 8-window cmux setup):**

- `cmux new-workspace` (no `--window`) lands in the **caller's process window** (where the King's bash session is anchored), NOT the user's focused window. This is the safer default: lanes glued to the King even if user clicks around to other windows.
- `cmux send` / `cmux notify` / `workspace-action` / `tab-action` / `close-workspace` are all ref-targeted (`workspace:N`) and window-agnostic — they work cross-window with no extra flags.
- `cmux tree --all` enumerates everything globally; R31 lane-readiness check works across windows.
- Set `kingdom.json.cmux.spawnWindow = "new"` if you want the kingdom to claim a fresh window for itself; otherwise leave at default `"current"`.

All four calls silent-on-failure — descriptions/colors/badges are cosmetic, not load-bearing. Used by `commands/start.md` Phase 5 PRIMARY.

---

## Sub-agent pool — pre-warmed `claude -p` processes (v0.18.0+, v0.31.1 Sonnet default)

**Model default (v0.31.1+):** lane sub-agents default to **Sonnet**. Workers and co-workers are Opus, but their sub-agents handle one logical chunk each — Sonnet is the right cost/quality fit. Override via `kingdom.json.cmux.subAgentPool.model` (`"sonnet"` default, `"haiku"` for cheap reads only, `"opus"` for sensitive design work).

```bash
init_subagent_pool () {
  local pool_size=$(jq -r '.cmux.subAgentPool.perMasterPoolSize // 2' "$KJSON")
  for I in $(seq 1 "$pool_size"); do spawn_pool_slot & done
}

spawn_pool_slot () {
  local result=$(cmux tab-action --action new-terminal-right \
    --workspace "$CMUX_WORKSPACE_ID" --focus false 2>&1)
  local surface=$(echo "$result" | grep -oE 'surface:[0-9]+' | head -1)
  [ -z "$surface" ] && return 1

  # v0.31.1: read model from config (default sonnet) and pass to claude -p.
  # Pool slots are long-lived; the cost gap between Opus and Sonnet matters here.
  local pool_model=$(jq -r '.cmux.subAgentPool.model // "sonnet"' "$KJSON")
  cmux rename-tab --surface "$surface" -- "🐱 sub · idle (pool, $pool_model)"
  # v0.31.1 fix: --model must come BEFORE -p (verified against cmux.md syntax).
  # Wrong: `claude -p --model sonnet`  Right: `claude --model sonnet -p`
  cmux send --surface "$surface" -- "claude --model $pool_model -p 'AWAITING_DISPATCH'"
  cmux send --surface "$surface" Enter

  echo "$surface" >> "$LOGS/.subagent-pool-${CMUX_WORKSPACE_ID#workspace:}.list"
}

spawn_subagent_from_pool () {
  local model="$1" brief="$2"
  local pool_file="$LOGS/.subagent-pool-${CMUX_WORKSPACE_ID#workspace:}.list"
  local surface=$(head -1 "$pool_file" 2>/dev/null)

  if [ -z "$surface" ]; then
    spawn_subagent_tab "$model" "$brief"   # fall back to standard spawn
    return
  fi

  sed -i.bak '1d' "$pool_file" && rm "${pool_file}.bak"

  cmux rename-tab --surface "$surface" -- "🐱 sub · $model · $(echo "$brief" | head -c 30)"
  cmux send --surface "$surface" -- "$brief"
  cmux send --surface "$surface" Enter

  spawn_pool_slot &   # refill pool in background
}
```

Pool brings Layer-3 fan-out spawn latency from ~10–20s per tab to ~20ms per `cmux send`. Used by `workers.md` § Pre-warmed sub-agent pool.

---

## Kingdom overlay — working-tree review staging (v0.17.0+)

Never commit on `kingdom`. Reset → overlay → review → discard.

```bash
kingdom_reset () {
  git checkout kingdom
  git fetch origin
  git reset --hard "origin/$BASE"
}

## NOTE: kingdom_overlay_lane moved to "## Hard gates" section above (v0.31.0).
## The new version takes (proj, lane, base) and enforces R4 — refuses to apply
## if kingdom isn't checked out or kingdom HEAD ≠ origin/$base. Callers that
## previously passed only (lane) MUST update to the 3-arg form.

kingdom_discard_overlay () {
  git checkout kingdom
  git restore .   # drops uncommitted working-tree changes
}

kingdom_review_surface () {
  echo "📋 Review surface — all changes UNCOMMITTED on kingdom:"
  git status --short
  echo ""
  git diff "origin/$BASE" --stat
}
```

Used by `kings.md` § Kingdom as review staging. Push approval requires Tier-2 gate pass on the overlay.

### `kingdom_resync_after_merge` — restore truth after a PR squash-merges (v0.19.0+, R26)

When `feature/<topic>` squash-merges to `develop`, kingdom is stale by one commit + worker-N branches may now contain commits that already landed on develop. This helper rebuilds the truth.

```bash
kingdom_resync_after_merge () {
  local merged_pr="$1" merged_lane="$2"   # e.g. 246, worker-3
  local before after

  before=$(git -C "$WORKTREE" rev-parse origin/"$BASE")

  # Step 1: clean overlay state on kingdom (drop any uncommitted overlay)
  git -C "$WORKTREE" switch kingdom 2>/dev/null
  git -C "$WORKTREE" reset --hard HEAD
  git -C "$WORKTREE" clean -fd

  # Step 2: fetch + fast-forward base
  git -C "$WORKTREE" fetch origin
  git -C "$WORKTREE" switch "$BASE"
  git -C "$WORKTREE" merge --ff-only "origin/$BASE" || {
    echo "❌ $BASE diverged from origin/$BASE — manual recovery needed"
    return 1
  }
  after=$(git -C "$WORKTREE" rev-parse origin/"$BASE")

  # Step 3: reset kingdom onto fresh base
  git -C "$WORKTREE" branch -f kingdom "$BASE"
  git -C "$WORKTREE" switch kingdom

  # Step 4: free the merged lane (its commit just landed)
  git -C "$WORKTREE" branch -f "$merged_lane" "$BASE"

  # Step 5: rebase remaining active lanes onto new base
  local lanes_freed="$merged_lane"
  for lane in $(git -C "$WORKTREE" branch --list 'worker-*' | tr -d ' *'); do
    [ "$lane" = "$merged_lane" ] && continue
    [ -z "$(git -C "$WORKTREE" log "$BASE..$lane" 2>/dev/null)" ] && {
      git -C "$WORKTREE" branch -f "$lane" "$BASE"
      lanes_freed="$lanes_freed,$lane"
      continue
    }
    git -C "$WORKTREE" switch "$lane"
    git -C "$WORKTREE" rebase "origin/$BASE" || {
      echo "⚠️ rebase conflict on $lane — resolve manually, then re-run resync"
      return 1
    }
  done

  # Step 6: verify kingdom shows ONLY open-lane commits
  git -C "$WORKTREE" switch kingdom
  echo "📋 kingdom..origin/$BASE delta (should be empty — no duplicates):"
  git -C "$WORKTREE" log --oneline "origin/$BASE..kingdom" || true

  # Step 7: log resync line
  printf '%s  KINGDOM_RESYNC  merged_pr=#%s  base_advanced=%s..%s  lanes_freed=%s\n' \
    "$(date -u +%FT%TZ)" "$merged_pr" "${before:0:7}" "${after:0:7}" "$lanes_freed" \
    >> "$LOGS/master_agent.log"
}
```

Trigger: King polls `gh pr view <N> --json state -q .state`; when it flips to `MERGED`, call this helper with the PR number + the lane whose commit just merged. Used by `kings.md` § Post-merge sync (to be added in v0.19.0).

---

## Feature carve — `feature/<topic>` byte-for-byte from worker-N (v0.16.3+)

Strict equality: feature branch is a fast-forward checkout of the lane's tip; NO commits added on the feature branch after carving.

```bash
carve_and_push_feature () {
  local lane="$1" topic="$2" sub_task_id="$3"

  # CORRECT — fast-forward checkout; no new commits
  git checkout -b "feature/$topic" "$lane"

  # Auto-generate PR body from task file (v0.18.0+)
  local pr_body=$(generate_pr_body_from_task_file "$lane" "$sub_task_id")
  local pr_title=$(get_pr_title_from_task_file "$lane" "$sub_task_id")

  git push -u origin "feature/$topic"
  gh pr create \
    --base develop \
    --head "feature/$topic" \
    --title "$pr_title" \
    --body "$pr_body"

  # After push, discard the kingdom overlay (different concern — kingdom branch)
  kingdom_discard_overlay
}

# WRONG (anti-pattern):
#   git checkout -b "feature/$topic" "$lane"
#   cp some-extra-file .
#   git commit -m "add extra"     ← feature/* now diverges from lane tip
```

Used by `kings.md` § Push approval gate. If extra content needs to be in the PR, put it on `worker-N` first (Option A) or open a separate PR (Option B). Never add commits on `feature/*`.

---

## Auto-generated PR body (v0.18.0+)

```bash
generate_pr_body_from_task_file () {
  local lane="$1" sub_task_id="$2"
  local task_file=$(ls -1t "$WS/.kingdom/${PROJECT}/tasks/"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)
  local digest_file=$(ls -1t "$LOGS/"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)
  local test_report=$(ls -1t "$PROJ/docs/test-reports/KING_"*"__${lane}__${sub_task_id}.md" 2>/dev/null | head -1)

  cat <<EOF
## Summary

$(awk '/^## Brief/,/^##/' "$task_file" | sed '1d;$d')

## Implementation

$(awk '/^## Plan/,/^## Progress/' "$task_file" | sed '1d;$d' | grep -E '^\s*- \[x\]')

## Verification

$(awk '/^## Final summary/,/^##/' "$task_file" | sed '1d;$d')

$([ -n "$test_report" ] && echo "📋 Test report: $(basename "$test_report")")

## Test plan

- [x] Tier-1 gate passed
- [x] Tier-2 gate passed (integrated on kingdom)
- [ ] Manual review by lead

---

🤖 PR body auto-generated from kingdom task file: \`tasks/$(basename "$task_file")\`
🤖 Curated closer artifact: \`logs/$(basename "$digest_file")\`
EOF
}
```

Override via dispatch brief `PR body: manual` — King skips auto-generation and asks the user to paste a body. Default: auto-generate. Used by `kings.md` § Auto-generated PR body.

---

## Pattern grep — exhaustive discovery before implementation (v0.17.2+)

Worker's mandatory Layer-1 step. Default stance: "the project HAS a pattern; my job is to find it. Burden of proof on me to show one doesn't exist via grep evidence."

```bash
pattern_grep_fanout () {
  local key_term="$1" project_root="$2"

  # Fan out N Haiku scanners in parallel (capacity is unlimited per v0.15.0)
  # Each scanner reads a slice; aggregate findings.

  # Mandatory checks:
  grep -rln "$key_term" --include='*.{ts,tsx,js,py,sh,yml,yaml,json,md,env,env.example}' "$project_root"

  # Read every .env / .env.example in relevant subtree
  find "$project_root" -name '.env*' -o -name '.env.example' | xargs cat

  # Read all scripts/ files matching the topic
  ls "$project_root"/scripts/*"$key_term"* 2>/dev/null | xargs cat

  # Read lib/*-defaults.* for HOW-TO comments
  find "$project_root" -name '*defaults*.ts' -o -name '*defaults*.py' | xargs head -30

  # Read compose.*.yml for container env contracts
  find "$project_root" -name 'compose.*.yml' -o -name 'docker-compose*.yml' | xargs cat

  # Read project CLAUDE.md
  cat "$project_root/CLAUDE.md" 2>/dev/null
}
```

After grep, worker synthesises in task file Step 1:
- "Pattern found at `<file:line>`. Reusing it." → follow
- OR: "No pattern. Grepped N files. Confirming new approach with King BEFORE implementing." → escalate

Used by `workers.md` § Layer 1 — Discovery.

---

## Parallel edit fan-out — N branches, one search/replace each (v0.30.0+, R27/R28)

Sibling to `pattern_grep_fanout`. Where the grep helper does parallel **reads**, this does parallel **writes** across N independent branch worktrees. Each unit: `cd $lane_wt && rg --replace + amend + force-push-with-lease`. Serial **within** a branch (switch → edit → amend → push is atomic), parallel **across** branches (no shared destination — each lane writes only to its own worktree).

```bash
parallel_edit_fanout () {
  # Inputs:
  #   $1 = search term            (literal string, no regex)
  #   $2 = replacement term       (literal string)
  #   $3 = lane spec              (space-separated: "worker-1=246 worker-2=247 co-worker-1=248")
  #                               format = "<lane>=<pr_number>"; pr_number resolves the lane's target PR
  #   $4 = file glob              (relative to lane worktree; default '**/*')
  # Outputs:
  #   per-lane stdout line: "OK <lane> <files_changed>" or "SKIP <lane> <reason>"
  #   exit 0 iff every lane succeeded or skipped cleanly
  local search="$1" replace="$2" spec="$3" glob="${4:-}"
  local rc=0 lane pr lane_wt pids=""
  local tmpdir=$(mktemp -d)

  for unit in $spec; do
    lane="${unit%=*}"
    pr="${unit#*=}"
    lane_wt="$WORKTREES/$lane"
    [ -d "$lane_wt" ] || { echo "SKIP $lane no-worktree" >> "$tmpdir/out"; continue; }

    # Each lane runs in its own subshell — parallel across branches,
    # but `switch → edit → amend → push` stays atomic within the branch.
    (
      cd "$lane_wt" || { echo "SKIP $lane cd-failed" >> "$tmpdir/out"; exit 0; }

      # R27: skip if PR already merged (force-push would touch a closed branch)
      if [ -n "$pr" ]; then
        state=$(gh pr view "$pr" --json state -q .state 2>/dev/null)
        [ "$state" = "MERGED" ] && { echo "SKIP $lane pr-merged" >> "$tmpdir/out"; exit 0; }
        [ "$state" = "CLOSED" ] && { echo "SKIP $lane pr-closed" >> "$tmpdir/out"; exit 0; }
      fi

      # Discover files containing the search term (scoped by glob if provided)
      if [ -n "$glob" ]; then
        files=$(rg -l --fixed-strings "$search" -g "$glob" 2>/dev/null)
      else
        files=$(rg -l --fixed-strings "$search" 2>/dev/null)
      fi
      [ -z "$files" ] && { echo "SKIP $lane no-matches" >> "$tmpdir/out"; exit 0; }

      # Apply replacement (literal, no regex — sed -i '' on macOS, sed -i on Linux)
      n=0
      while IFS= read -r f; do
        if [ "$(uname)" = "Darwin" ]; then
          sed -i '' "s|$(printf '%s' "$search" | sed 's/[][\/.*^$|]/\\&/g')|$(printf '%s' "$replace" | sed 's/[\/&|]/\\&/g')|g" "$f"
        else
          sed -i "s|$(printf '%s' "$search" | sed 's/[][\/.*^$|]/\\&/g')|$(printf '%s' "$replace" | sed 's/[\/&|]/\\&/g')|g" "$f"
        fi
        n=$((n + 1))
      done <<< "$files"

      # Amend + force-with-lease (R1 / R28 exclusive-sensitive — but limited to lane's
      # own short-lived worktree, not a primary branch; safe under R28's parallel-across-
      # branches clause). --force-with-lease bails if remote moved since fetch.
      git add -u 2>/dev/null
      if git diff --cached --quiet; then
        echo "SKIP $lane no-staged-changes" >> "$tmpdir/out"
        exit 0
      fi
      git commit --amend --no-edit >/dev/null 2>&1 || {
        echo "FAIL $lane amend-failed" >> "$tmpdir/out"
        exit 1
      }
      git push --force-with-lease >/dev/null 2>&1 || {
        echo "FAIL $lane push-failed" >> "$tmpdir/out"
        exit 1
      }
      echo "OK $lane $n" >> "$tmpdir/out"
    ) &
    pids="$pids $!"
  done
  # R42: bounded wait — each subshell does gh + sed + git commit + git push --force-with-lease;
  # network stalls on any one of those would block bare `wait` forever. 45s budget covers
  # the slowest credible case (push to slow remote × parallelism).
  _bounded_wait 45 $pids
  local wait_rc=$?
  [ "$wait_rc" -eq 124 ] && echo "FAIL _bounded_wait timeout — surviving subshells killed" >> "$tmpdir/out"

  # Aggregate + log
  cat "$tmpdir/out" 2>/dev/null
  if grep -q '^FAIL ' "$tmpdir/out" 2>/dev/null; then
    rc=1
  fi
  printf '%s  PARALLEL_EDIT_FANOUT  search=%q  replace=%q  result=%s\n' \
    "$(date -u +%FT%TZ)" "$search" "$replace" \
    "$([ $rc -eq 0 ] && echo ok || echo partial)" \
    >> "$LOGS/master_agent.log"
  rm -rf "$tmpdir"
  return $rc
}
```

Used by:
- `watchmans.md` § PR-number backfill duty — `(PR #pending) → (PR #<N>)` flips across all active lanes.
- Future R28 fan-out work — any "N independent branches, same string operation" task.

**Why a helper, not inlined per call site:** the inlined pattern in `watchmans.md` was correct but duplicated the parallel `&` + `wait` skeleton, the `--force-with-lease` bail logic, and the MERGED/CLOSED state guard. Three call sites would have triplicated the bug surface. One helper, one place to fix.

---

## Sentinel detection — un-gated work scan (v0.14.10+)

```bash
find_ungated_sentinels () {
  for FLAG in "$LOGS"/done/*.flag; do
    [ -f "$FLAG" ] || continue
    BASE=$(basename "$FLAG" .flag)
    LANE=$(echo "$BASE" | sed 's/^[0-9-]*T[0-9]*Z__[a-z]*-//;s/__.*//')
    SUBTASK_ID=$(echo "$BASE" | sed 's/.*__//')

    # Already gated? (test report exists)
    if ! ls "$PROJ/docs/test-reports/KING_"*"__${LANE}__${SUBTASK_ID}.md" >/dev/null 2>&1; then
      echo "UN_GATED: $LANE / $SUBTASK_ID"
    fi
  done
}
```

Used by `kings.md` § Auto-gate on completion. King runs this at session resume + pre-user-interaction + post-dispatch polling + on watchman done-notify. Un-gated → auto-fire Tier-1 gate without asking.

---

## Artifact path helpers

### `make_artifact_id` / `raw_path` / `curated_path` — artifact path helpers

```bash
# Generate the shared ID for a task. Master calls this once per task.
make_artifact_id() {     # usage: make_artifact_id <task-type> <sub-agent> <slug>
  printf '%s__%s__%s__%s' \
    "$(date -u +%Y-%m-%dT%H%MZ)" "$1" "$2" "$3"
}

# Compute a worker's raw path (no I/O — just the path string).
raw_path() {             # usage: raw_path <logs_dir> <ID> <sub-agent> <worker-slug>
  printf '%s/raw/%s__%s-%s.md' "$1" "$2" "$3" "$4"
}

# Compute the curated path (shared across all workers in a task).
curated_path() {         # usage: curated_path <logs_dir> <ID>
  printf '%s/%s.md' "$1" "$2"
}
```

Used by `workers.md` § Path / ID helpers. Master calls `make_artifact_id` once per task to generate the shared `<ID>`; workers compute their artifact paths via `raw_path` and `curated_path` using that ID.

---

## File-naming conventions — every artifact carries the lane (v0.15.2+)

| Artifact | Path | Lane location |
|---|---|---|
| Task file | `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md` | segment 2 |
| Raw output | `<LOGS>/raw/<UTC>__<sub>-<lane>__<sub-task-id>.md` | segment 2 |
| Curated digest | `<LOGS>/<UTC>__<lane>__<sub-task-id>.md` | segment 2 |
| Sentinel flag | `<LOGS>/done/<UTC>__<sub>-<lane>__<sub-task-id>.flag` | segment 2 |
| Test report (King) | `<project>/docs/test-reports/KING_<UTC>__<lane>__<sub-task-id>.md` | segment 2 |

Grep contract: `ls *__worker-3__*` from any artifact dir returns lane-attached files only. Non-lane artifacts (audit digests, watchman reports, King planning files) carry the artifact TYPE in segment 2 (`audit-A`, `WATCH_*`, `king-plan`) instead of a lane.

Used by `workers.md` § Task-artifact naming and every role doc that creates artifacts.

---

## Card rendering (v0.22.0+)

Cards in [`cards/`](cards/) are reusable display templates. Each card is a markdown file with `${VAR}` placeholders. `render_card` loads a card, substitutes the variables, and prints to chat.

### `fetch_weather_line` — weather slot for `welcome` card

Uses ipapi.co for geolocation + open-meteo for current weather. Both free, no API key. 3s timeout per call; silent failure (returns empty string).

```bash
fetch_weather_line () {
  # Opt-out via kingdom.json.welcome.weather = false
  local enabled=$(jq -r '.welcome.weather // true' "$KJSON" 2>/dev/null)
  [ "$enabled" = "false" ] && return 0

  # Geolocation
  local loc=$(curl -s --max-time 3 https://ipapi.co/json/ 2>/dev/null)
  [ -z "$loc" ] && return 0
  local city=$(echo "$loc" | jq -r '.city // empty')
  local lat=$(echo "$loc" | jq -r '.latitude // empty')
  local lon=$(echo "$loc" | jq -r '.longitude // empty')
  [ -z "$lat" ] || [ -z "$lon" ] && return 0

  # Weather
  local wx=$(curl -s --max-time 3 \
    "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code&timezone=auto" 2>/dev/null)
  [ -z "$wx" ] && return 0
  local temp=$(echo "$wx" | jq -r '.current.temperature_2m // empty')
  local feels=$(echo "$wx" | jq -r '.current.apparent_temperature // empty')
  local code=$(echo "$wx" | jq -r '.current.weather_code // empty')
  [ -z "$temp" ] && return 0

  # WMO code → emoji + label
  local emoji label
  case "$code" in
    0)     emoji="☀️";  label="clear" ;;
    1|2)   emoji="🌤️"; label="partly cloudy" ;;
    3)     emoji="☁️";  label="overcast" ;;
    45|48) emoji="🌫️"; label="fog" ;;
    51|53|55|56|57|61|63|65|66|67)
           emoji="🌧️"; label="rain" ;;
    71|73|75|77) emoji="❄️"; label="snow" ;;
    80|81|82)    emoji="🌦️"; label="showers" ;;
    95|96|99)    emoji="⛈️"; label="thunderstorm" ;;
    *)     emoji="🌍";  label="weather" ;;
  esac

  printf '%s  %s · %s°C · %s · feels like %s°C\n' "$emoji" "$city" "$temp" "$label" "$feels"
}
```

### `random_task_done_line` — pick a random line from `cards/task-complete.md` pool

Avoids repeating the most-recent pick by keeping a small ring buffer in `<LOGS>/.last-task-done-line`.

```bash
random_task_done_line () {
  local pool_file="$WS/.kingdom/.setting/cards/task-complete.md"
  local last_file="$LOGS/.last-task-done-line"
  local last=$(cat "$last_file" 2>/dev/null || echo "0")

  # Extract the 20 numbered lines from the pool file
  mapfile -t lines < <(grep -E '^[0-9]+\. ' "$pool_file" | sed 's/^[0-9]\+\. //')
  local count=${#lines[@]}
  [ "$count" -eq 0 ] && return 0

  # Pick a random index that isn't last
  local idx
  while true; do
    idx=$((RANDOM % count))
    [ "$idx" != "$last" ] && break
  done
  echo "$idx" > "$last_file"
  echo "${lines[$idx]}"
}
```

### `pick_skills_for_task` — per-task skill picker (v0.23.0+)

Reads the keyword → skill mapping table from [`skill-routing.md`](skill-routing.md), greps the task brief + AC + reference files, picks up to 3 matching skills sorted by priority. Returns multi-line text ready for `${SUGGESTED_SKILLS}` substitution in [`cards/dispatch-brief.md`](cards/dispatch-brief.md).

```bash
pick_skills_for_task () {
  local task_id="$1" lane="$2"
  local routing="$WS/.kingdom/.setting/skill-routing.md"
  local task_file=$(ls -1t "$WS/.kingdom/$PROJECT/tasks/"*"__${lane}__${task_id}.md" 2>/dev/null | head -1)
  [ -f "$task_file" ] || return 0

  # Check for user override first
  if [ -n "$SKILL_OVERRIDE" ]; then
    [ "$SKILL_OVERRIDE" = "none" ] && return 0
    echo "$SKILL_OVERRIDE" | tr ',' '\n' | while read -r skill; do
      [ -n "$skill" ] && printf '  → Skill %s · user override\n' "$skill"
    done
    return 0
  fi

  # Build the search corpus: task file + linked reference files
  local corpus=$(cat "$task_file")
  for ref in $(grep -oE 'docs/[a-zA-Z0-9_/-]+\.md' "$task_file" 2>/dev/null | sort -u); do
    [ -f "$PROJ/$ref" ] && corpus+=$'\n'"$(cat "$PROJ/$ref" 2>/dev/null)"
  done
  corpus=$(echo "$corpus" | tr '[:upper:]' '[:lower:]')

  # Parse routing table — extract rows from the markdown table
  local picks=""
  awk -F'|' '/^\| (P1|P2|P3) \|/ {
    priority=$2; gsub(/^ +| +$/, "", priority);
    skill=$3;    gsub(/^ +| +$/, "", skill); gsub(/^`|`$/, "", skill);
    keywords=$4; gsub(/^ +| +$/, "", keywords);
    print priority "\t" skill "\t" keywords
  }' "$routing" | while IFS=$'\t' read -r priority skill keywords; do
    # Try each comma-separated keyword
    echo "$keywords" | tr ',' '\n' | while read -r kw; do
      kw=$(echo "$kw" | sed 's/^ *`//; s/` *$//; s/^ *//; s/ *$//')
      [ -z "$kw" ] && continue
      if echo "$corpus" | grep -qiwF "$kw"; then
        echo "$priority|$skill|$kw"
        break
      fi
    done
  done | sort -u | sort -t'|' -k1,1 | head -3 | while IFS='|' read -r priority skill kw; do
    printf '  → Skill %s · matches keyword: "%s"\n' "$skill" "$kw"
  done
}
```

Used by `kings.md` § Dispatch (and `commands/day.md` Step 4) to populate `${SUGGESTED_SKILLS}` in the dispatch-brief. Per [`skill-routing.md`](skill-routing.md), skills are per-task, not per-lane-lifetime.

### `render_card` — load a card, substitute variables, print

```bash
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
```

(The full `render_card` implementation handles variant selection, line-drop on empty `${VAR}`, and width-padding for box alignment. See [`cards/README.md`](cards/README.md) § Variable substitution.)

---

## Session state persistence (v0.29.0+)

Persists lane state across King sessions so `/kingdom:work` can resume mid-flight tasks without re-interrogating git or re-reading every task file from scratch.

**state.json schema (canonical):**

```json
{
  "schema_version": "1",
  "saved_at_utc": "2026-05-19T16:30:00Z",
  "lanes": {
    "worker-1": {
      "branch": "worker-1",
      "head_sha": "abc1234",
      "uncommitted_files": 0,
      "task": {
        "id": "FE-P0-FOUND.5",
        "task_file": "tasks/2026-05-19T0353Z__worker-1__FE-P0-FOUND.5.md",
        "status": "discovery-complete",
        "layer": "L1",
        "blockers": ["legal:terms seed", "@workspace/db dep route"]
      }
    },
    "worker-2": { "branch": "worker-2", "head_sha": "def5678", "uncommitted_files": 0, "task": null }
  },
  "open_prs": [
    { "number": 257, "branch": "feature/fe-p0-found-7", "state": "OPEN" }
  ],
  "ready_for_fresh_work": false
}
```

Note: `task: null` means the lane was idle at save time (no in-flight task file).

### `save_session_state` — called by `/kingdom:save`

```bash
save_session_state () {
  local state_file="$WS/.kingdom/$PROJECT/state.json"
  local saved_at
  saved_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build the lanes object by iterating over lanes declared in kingdom.json
  local lanes_json
  lanes_json=$(jq -r '.shape | keys[]' "$KJSON" 2>/dev/null)
  [ -z "$lanes_json" ] && { echo "⚠️ save_session_state: no lanes in $KJSON" >&2; return 1; }

  local lanes_obj='{}'
  while IFS= read -r lane; do
    local worktree_path="$WS/.worktrees/$lane"
    local branch head_sha uncommitted task_obj

    # branch: the checked-out branch name (fall back to lane name if worktree absent)
    if [ -d "$worktree_path/.git" ] || [ -f "$worktree_path/.git" ]; then
      branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$lane")
      head_sha=$(git -C "$worktree_path" rev-parse --short HEAD 2>/dev/null || echo "unknown")
      uncommitted=$(git -C "$worktree_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    else
      branch="$lane"
      head_sha="unknown"
      uncommitted=0
    fi

    # task: find the most recent in-flight task file for this lane (no done/*.flag yet)
    local task_file
    task_file=$(ls -1t "$WS/.kingdom/$PROJECT/tasks/"*"__${lane}__"*.md 2>/dev/null \
      | while read -r f; do
          base=$(basename "$f" .md)
          subtask_id=$(echo "$base" | sed 's/.*__//')
          # skip if a done flag exists (task already closed)
          ls "$WS/.kingdom/$PROJECT/logs/done/"*"__${lane}__${subtask_id}.flag" >/dev/null 2>&1 \
            && continue
          echo "$f"
          break
        done)

    if [ -n "$task_file" ]; then
      local task_id status layer blockers_json
      task_id=$(basename "$task_file" .md | sed 's/.*__//')
      # Read Status and Layer fields from the task file header block
      status=$(grep -m1 '^Status:' "$task_file" 2>/dev/null | awk '{print $2}' || echo "unknown")
      layer=$(grep -m1 '^Layer:' "$task_file" 2>/dev/null | awk '{print $2}' || echo "")
      # Blockers: lines under a "## Blockers" section
      blockers_json=$(awk '/^## Blockers/,/^##/' "$task_file" 2>/dev/null \
        | grep '^- ' | sed 's/^- //' \
        | jq -Rs '[split("\n")[] | select(length > 0)]' 2>/dev/null || echo '[]')
      local rel_task_file="tasks/$(basename "$task_file")"
      task_obj=$(jq -n \
        --arg id "$task_id" \
        --arg tf "$rel_task_file" \
        --arg st "$status" \
        --arg ly "$layer" \
        --argjson bl "$blockers_json" \
        '{id: $id, task_file: $tf, status: $st, layer: $ly, blockers: $bl}')
    else
      task_obj="null"
    fi

    lanes_obj=$(echo "$lanes_obj" | jq \
      --arg lane "$lane" \
      --arg branch "$branch" \
      --arg sha "$head_sha" \
      --argjson uc "$uncommitted" \
      --argjson task "$task_obj" \
      '.[$lane] = {branch: $branch, head_sha: $sha, uncommitted_files: $uc, task: $task}')
  done <<< "$lanes_json"

  # Collect open PRs via gh CLI (silent if gh unavailable)
  local open_prs_json='[]'
  if command -v gh >/dev/null 2>&1; then
    open_prs_json=$(gh pr list --repo "$(git -C "$PROJ" remote get-url origin 2>/dev/null)" \
      --state open --json number,headRefName,state 2>/dev/null \
      | jq 'map({number: .number, branch: .headRefName, state: .state})' 2>/dev/null || echo '[]')
  fi

  local ready
  ready=$(compute_ready_for_fresh_work "$(jq -n --argjson l "$lanes_obj" '{lanes: $l}')")

  local state_json
  state_json=$(jq -n \
    --arg sv "1" \
    --arg ts "$saved_at" \
    --argjson lanes "$lanes_obj" \
    --argjson prs "$open_prs_json" \
    --argjson ready "$( [ "$ready" = "true" ] && echo "true" || echo "false" )" \
    '{schema_version: $sv, saved_at_utc: $ts, lanes: $lanes, open_prs: $prs, ready_for_fresh_work: $ready}')

  # Atomic write: tmp → mv (avoids partial reads if concurrent)
  local tmp
  tmp=$(mktemp "${state_file}.XXXXXX")
  printf '%s\n' "$state_json" > "$tmp" && mv "$tmp" "$state_file"
  echo "✅ state saved → $state_file"
}
```

### `read_session_state` — called by `/kingdom:work` Step 0.6 (resume scan)

```bash
read_session_state () {
  local state_file="$WS/.kingdom/$PROJECT/state.json"
  [ -f "$state_file" ] || { echo '{"lanes":{},"ready_for_fresh_work":true}'; return 0; }

  # Schema version guard: warn on unknown schema_version
  local schema_version
  schema_version=$(jq -r '.schema_version // "unknown"' "$state_file" 2>/dev/null)
  case "$schema_version" in
    "1") : ;;  # current — proceed
    *)
      echo "⚠️ read_session_state: unknown schema_version=\"$schema_version\" in $state_file — continuing anyway" >&2
      ;;
  esac

  cat "$state_file"
}
```

### `compute_ready_for_fresh_work` — returns `"true"` or `"false"`

```bash
compute_ready_for_fresh_work () {
  local state_json="$1"
  # true iff every lane in state.lanes has task=null AND uncommitted_files=0
  local has_in_flight
  has_in_flight=$(echo "$state_json" \
    | jq '[.lanes[] | select(.task != null or .uncommitted_files > 0)] | length')
  [ "$has_in_flight" = "0" ] && echo "true" || echo "false"
}
```

**Notes:**

- **Atomic writes** — `save_session_state` always writes to a `mktemp` file then `mv`s it into place. This prevents a concurrent reader (e.g. a watchman sub-agent polling `state.json`) from seeing a half-written file.
- **Schema versioning** — v0.29.0 sets `schema_version: "1"`. Future structural changes to the schema must increment this string. `read_session_state` checks the version and emits a warning (not a hard exit) on unknown values so older state files degrade gracefully.
- **Where `state.json` lives** — `.kingdom/<project>/state.json`, project-scoped. Not inside `logs/` (state is live operational data, not a log artifact). One file per project; overwritten on each `/kingdom:save`.

---

## Reference

Each role doc points here for the canonical bash. If a role doc has bash that ISN'T here, that's a leak — file a fix to consolidate. Single source of truth for primitives.
