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

  # Step 1: create the workspace (capture ref via grep -oE — awk pipelines break in some shells)
  local result=$(cmux new-workspace \
    --name "$label" \
    --description "Kingdom lane · $(basename "$path") · $(date -u +%Y-%m-%dT%H%MZ)" \
    --cwd "$path" \
    --command "claude" \
    --focus false 2>&1)
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

Override via dispatch brief `PR body: manual` — King skips auto-generation and asks Ter to paste a body. Default: auto-generate. Used by `kings.md` § Auto-generated PR body.

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

Used by `kings.md` § Auto-gate on completion. King runs this at session resume + pre-Ter-interaction + post-dispatch polling + on watchman done-notify. Un-gated → auto-fire Tier-1 gate without asking.

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

## Reference

Each role doc points here for the canonical bash. If a role doc has bash that ISN'T here, that's a leak — file a fix to consolidate. Single source of truth for primitives.
