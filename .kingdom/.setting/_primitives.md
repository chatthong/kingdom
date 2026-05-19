# _primitives.md — Shared bash helpers

> The canonical implementations of every helper function referenced across role docs. Each role doc (`kings.md`, `workers.md`, `co-workers.md`, `watchmans.md`, `cmux.md`, `git.md`) points HERE for the actual code; the role docs say WHEN to use each helper, this file says HOW.

Goal: single source of truth for shared bash patterns. Edit the helper once, every role doc inherits the fix.

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

  # Step 1: create the workspace (capture ref via grep -oE — awk pipelines break in some shells)
  local result=$(cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --command "claude" \
    --focus false \
    $window_flag 2>&1)
  local ref=$(echo "$result" | grep -oE 'workspace:[0-9]+' | head -1)
  [ -z "$ref" ] && { echo "❌ spawn failed: $result" >&2; return 1; }

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

## Sub-agent pool — pre-warmed `claude -p` processes (v0.18.0+)

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

  cmux rename-tab --surface "$surface" -- "🐱 sub · idle (pool)"
  cmux send --surface "$surface" -- "claude -p 'AWAITING_DISPATCH'"
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

kingdom_overlay_lane () {
  local lane="$1"
  echo "▶ Overlaying $lane changes..."
  git diff "origin/$BASE..$lane" | git apply --3way - || {
    echo "⚠️ Conflict overlaying $lane — resolve in working tree."
    echo "   TODO_*.md → keep all close-suffix headers"
    echo "   CHANGELOG.md → keep both entries; order by sub-task ID"
    echo "   docs/test-reports/ → no real conflict (different filenames)"
    return 1
  }
}

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
