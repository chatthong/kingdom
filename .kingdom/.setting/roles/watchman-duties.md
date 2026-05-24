# watchman-duties.md — Watchman autonomous surveillance duties (per-tick Haiku fan-out)

> Extracted from [`watchman.md`](watchman.md) (modular reorg). This file holds the per-tick autonomous surveillance duties — Duty 1 (senior-dev review), Duty 2 (CVE scan), Duty 3 (cross-lane conflict scan), Duty 4 (git hygiene scan), Duty 5 (cross-story drift scan) — plus the Haiku cap enforcement and the `WATCH_TICK_<UTC>.md` tick aggregation. See [`watchman.md`](watchman.md) for the watchman role overview, the `/loop` body, dispatch, lifecycle, and read-only scans.

---

## Autonomous Haiku fan-out (v0.29.0+, per rules.md R39 + R40)

Starting in v0.29.0, Watchman becomes fully autonomous within its tick: it no longer only runs smoke commands and PR checks — it also fans out up to `haiku_cap_per_tick` Haiku sub-agents in parallel to perform four new surveillance duties. These sub-agents are spawned either via `Agent(model="haiku", ...)` (when running inside a Claude Code session) or via `cmux_tab_action new-terminal-right --workspace $WATCHMAN_WS` (when running in PRIMARY/cmux mode, per R38). All four duties run in parallel at every tick; no duty waits for another.

**R41 — Skill-aware (v0.29.3+):** Watchman Haiku sub-agents may optionally invoke domain skills to strengthen their analysis. Duty 1 (code review) may use `code-review:code-review`; Duty 2 (CVE scan) may use `security-review`. Invocation is optional — skip if the skill adds no material benefit for a shallow diff or trivial audit file. No cap beyond the normal 3-skill-per-brief limit.

### `haiku_cap_per_tick` enforcement

Read from `kingdom.json.watchman.haikuCapPerTick`. Default: `5`. Maximum: `10`.

```bash
HAIKU_CAP=$(jq -r '.watchman.haikuCapPerTick // 5' "$KJSON")
# Clamp to [1, 10]
if [ "$HAIKU_CAP" -gt 10 ]; then
  HAIKU_CAP=10
  echo "[$(date -u +%Y-%m-%dT%H%MZ)] WARN haiku_cap_per_tick clamped to 10 (configured value exceeded max)" \
    >> "$LOGS/master_agent.log"
fi
if [ "$HAIKU_CAP" -lt 1 ]; then
  HAIKU_CAP=1
fi
```

Count all Haiku sub-agents spawned this tick across all four duties. If the combined count would exceed `HAIKU_CAP`, reduce the code-review fan-out first (it generates the most agents), then skip lower-priority duties in this order: git hygiene, conflict scan, CVE scan (CVE scan is rarely urgent mid-day; skip last). Log a one-line warning to `master_agent.log` whenever clamping occurs.

---

### Duty 1 — Senior-dev review fan-out (with doc cross-check) — v0.31.1+

For each lane that has new commits since the last tick — **worker-N**, **co-worker-N**, AND the **King's overlay state on kingdom** — spawn one Haiku sub-agent that reads the diff plus the project's documented architecture, and writes a one-page senior-dev review.

**Trigger:** `git log --oneline <last-tick-sha>..<lane>-HEAD` returns at least one commit, OR (for King) the kingdom working tree shows uncommitted changes against `origin/$BASE`.

**Doc context — read ONCE per tick, reused across lanes (R28 parallel-safe).** Before fan-out, gather the project's architectural ground truth:

```bash
# Tick-level setup — one-time read for the whole fan-out.
# v0.31.1: prefer the unified haiku_read_docs_orientation helper if you want
# the full R45 protocol (Phase 1 wayfinding + Phase 2 broader docs). For the
# narrower per-tick code-review context, the lightweight scan below is enough.
DOC_CONTEXT_FILE="$LOGS/.watchman_doc_context_${UTC}.txt"
{
  # Root-level docs (CLAUDE.md, README.md, AGENTS.md, CONTRIBUTING.md, etc.).
  # Hard-cap at 10 files to keep the per-lane prompt under ~50k tokens.
  find "$PROJ" -maxdepth 1 -name "*.md" -type f 2>/dev/null | head -10

  # docs/ tree — same hard cap, prefer recently-modified.
  if [ -d "$PROJ/docs" ]; then
    find "$PROJ/docs" -name "*.md" -type f -not -path "*/test-reports/*" 2>/dev/null \
      | while IFS= read -r f; do
          mtime=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null)
          [ -n "$mtime" ] && printf '%s\t%s\n' "$mtime" "$f"
        done | sort -rn | head -10 | cut -f2-
  fi
} > "$DOC_CONTEXT_FILE"

# v0.31.1 fix: DON'T collapse to space-separated — that splits paths with
# spaces (e.g., `docs/My Architecture.md`). Pass the file LIST as-is and let
# the Haiku read it line by line.
```

**Per-lane Haiku prompt:**

```bash
LAST_SHA=$(jq -r ".lane_shas[\"$LANE\"] // empty" "$LOGS/watchman_state.json")
NEW_SHA=$(git -C "$WORKTREES/$LANE" rev-parse HEAD 2>/dev/null)
[ "$LAST_SHA" = "$NEW_SHA" ] && continue   # no new commits — skip

UTC=$(date -u +%Y-%m-%dT%H%MZ)
REVIEW_FILE="$PROJ/docs/test-reports/WATCH_REVIEW_${UTC}__${LANE}.md"

Agent(
  model="haiku",
  prompt="You are a SENIOR DEVELOPER reviewing this lane's recent work. Your job is two-fold:
(1) standard code review and (2) cross-check the changes against the project's
documented architecture, conventions, and decisions.

== Project documentation (architectural ground truth) ==
The file paths to read are listed (one per line, may contain spaces) in:
  $DOC_CONTEXT_FILE
Use your Read tool on each path in that file (do NOT use cat — Read returns
line-numbered content with cleaner cap behavior). Build your mental model of
how this project is *supposed* to be structured BEFORE you open the diff.

Pay special attention to:
- README.md / docs/architecture.md / docs/how-it-works.md — system design
- CLAUDE.md / AGENTS.md — codebase conventions and project-specific rules
- CONTRIBUTING.md / docs/style.md — naming, patterns, file organization
- docs/branch-model.md or docs/git-workflow.md — git conventions
- Any 'decisions' / 'ADR' / 'rfc' files — locked-in architectural choices

== Lane diff (the work to review) ==
git -C $WORKTREES/$LANE diff $LAST_SHA..$NEW_SHA

== Output file ==
$REVIEW_FILE

== Review schema ==
## TL;DR
- **Severity:** urgent | warn | info
- **Lane:** $LANE
- **Verdict:** <one sentence — does this change align with the project's documented direction?>

## Doc cross-check (NEW — senior-dev lens)
For each meaningful change in the diff, locate the relevant doc anchor and verify:
- Does the change follow the documented pattern? (e.g., README says 'all DB calls go through repo/, this PR adds a direct DB call in route handler' → urgent)
- Does the change contradict a documented decision? (e.g., docs/decisions/01-auth.md says 'JWT in httpOnly cookie', PR uses localStorage → urgent)
- Is the change in the right architectural layer? (e.g., business logic in a UI component → warn)
- Does the change need a doc update that wasn't made? (e.g., new env var added but README setup section unchanged → warn)
Cite the doc file + line/section when you flag a mismatch.

## Code review (the existing dimensions)
- Missing or thin test coverage (any function >20 LOC with zero test calls)
- Large untested chunks (>50 LOC change with no matching test file change)
- Security smells (raw SQL, unescaped user input, hardcoded secrets, unsafe evals)
- Style outliers (naming, file length, unusual patterns vs the rest of the lane's history)

## Recommendations
A short bulleted list — what should change before this is ready for King's gate?
If nothing needs to change, write 'LGTM — aligns with documented architecture.'

Severity ladder:
- urgent — contradicts a documented decision, security smell, or breaks a documented invariant
- warn   — drifts from documented patterns, missing doc update, missing tests for >50 LOC chunk
- info   — minor style/naming, suggestion only

Write ONLY the review file — no other edits."
)
```

**King overlay review (the new third reviewee).** Once per tick, after lane fan-out, also review what's currently overlaid on kingdom (if anything):

```bash
KINGDOM_DIRTY=$(git -C "$PROJ" status --porcelain 2>/dev/null | head -1)
if [ -n "$KINGDOM_DIRTY" ] && [ "$(git -C "$PROJ" branch --show-current)" = "kingdom" ]; then
  KING_REVIEW_FILE="$PROJ/docs/test-reports/WATCH_REVIEW_${UTC}__king-overlay.md"
  Agent(
    model="haiku",
    prompt="Review King's current kingdom-branch overlay against the docs above.
Diff: git -C $PROJ diff origin/$BASE
Same schema as the lane review, but the lane name is 'king-overlay'.
Extra check: is the overlay consistent across the lanes it stitched together?
(e.g., two lanes adding the same env var with different default values)
Output file: $KING_REVIEW_FILE"
  )
fi
```

Update `watchman_state.json` after fan-out: `lane_shas["$LANE"] = $NEW_SHA`.

**Why this is Tier 2, not Tier 1:** the senior-dev review is advisory — it does NOT block the King's gate. R11 still applies: watchman never edits project source. If watchman flags `urgent` doc-drift, King reads the report at gate time and decides whether to dispatch a fix-up task to the lane. The user retains final say at push time.

---

### Duty 2 — CVE scan

Detect the project's package manager(s) by inspecting the project root. Spawn ONE Haiku per detected manager.

**Detection → audit command map:**

| Indicator file | Audit command |
|---|---|
| `package.json` + `pnpm-lock.yaml` | `pnpm audit --json` |
| `package.json` (no pnpm lock) | `npm audit --json` |
| `requirements.txt` or `pyproject.toml` | `pip-audit --format json` |
| `Cargo.toml` | `cargo audit --json` |
| `go.mod` | `go list -json -m -u all` |

Multiple managers may coexist (e.g., a monorepo with both `pnpm-lock.yaml` and `requirements.txt`). Each gets its own Haiku, but each counts against `haiku_cap_per_tick`.

**Output file:** `$LOGS/WATCH_CVE_<UTC>.md`

**Haiku prompt (per manager):**

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
CVE_FILE="$LOGS/WATCH_CVE_${UTC}.md"

Agent(
  model="haiku",
  prompt="Run: $AUDIT_CMD in $PROJ
Parse the JSON output. Write $CVE_FILE with:
## TL;DR
- Severity: 'urgent' (any critical/high) | 'warn' (moderate) | 'info' (low/none)
- Critical: N, High: N, Moderate: N, Low: N
## Findings
One row per advisory: package name | installed version | patched version | CVE ID | severity.
## Remediation
For each critical/high: recommended update command.
Write ONLY the CVE file — no other edits."
)
```

If no indicator files are found, skip this duty and note in the tick summary.

---

### Duty 3 — Cross-lane conflict scan

Build a file-touch matrix across all active lanes since the last tick. Flag cases where two or more lanes have modified the same file.

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
CONFLICT_FILE="$LOGS/WATCH_CONFLICTS_${UTC}.md"

# Build per-lane changed-file lists (using last-tick SHA from watchman_state.json)
declare -A LANE_FILES
for LANE in worker-1 worker-2 worker-3 co-worker-1; do
  LAST_SHA=$(jq -r ".lane_shas[\"$LANE\"] // empty" "$LOGS/watchman_state.json")
  [ -z "$LAST_SHA" ] && continue
  CHANGED=$(git -C "$WORKTREES/$LANE" diff --name-only "$LAST_SHA"..HEAD 2>/dev/null)
  LANE_FILES["$LANE"]="$CHANGED"
done

Agent(
  model="haiku",
  prompt="You are given per-lane file-touch lists below. Compute overlaps: any file touched
by 2+ lanes since last tick is a potential conflict.

Lane file lists:
$(for L in "${!LANE_FILES[@]}"; do echo "=== $L ==="; echo "${LANE_FILES[$L]}"; done)

Output file: $CONFLICT_FILE
Format:
## TL;DR
- Severity: 'urgent' (same file modified in 2+ lanes) | 'info' (no overlaps)
- N overlapping file(s) found

## Conflict pairs
| File | Lane A | Lane B | Risk |
|---|---|---|---|
<one row per overlap — Risk = 'merge conflict likely' if both modified; 'watch' if one added, one modified>

Write ONLY the conflicts file — no other edits."
)
```

If no overlaps exist, Haiku writes a minimal `## TL;DR — info: no overlaps this tick` file. Watchman still logs it in the tick summary.

---

### Duty 4 — Git hygiene scan

Spawn one Haiku to scan for git-state drift across the kingdom worktree layout.

**What to scan:**

| Item | How to detect | Flag if |
|---|---|---|
| Stale worktrees | `ls $PROJ/.worktrees/` vs `git worktree list` | Directory exists but `git worktree list` has no matching entry |
| Orphan branches | `git branch` (local) vs `kingdom.json.shape` lane names | Local branch not in kingdom shape + not `develop`/`main`/`watchman-*` |
| Unflushed `.lane` claims | `ls $LOGS/claims/*.lane` | Claim file exists but matching sentinel in `$LOGS/done/` also exists |
| Broken sentinels | `ls $LOGS/done/*.flag` | Sentinel flag exists but no matching task file in `$LOGS/tasks/` |
| Commit-without-sentinel pairs | `git log --oneline` on each lane vs `$LOGS/done/` | Lane has ≥1 commit since last tick but no new sentinel in `done/` within 5 min of commit time |

```bash
UTC=$(date -u +%Y-%m-%dT%H%MZ)
GIT_FILE="$LOGS/WATCH_GIT_${UTC}.md"

Agent(
  model="haiku",
  prompt="Perform a git hygiene scan for project $PROJ.

Worktrees dir: $PROJ/.worktrees/
Kingdom logs: $LOGS/
Kingdom JSON: $KJSON

Check all five hygiene items (stale worktrees, orphan branches, unflushed .lane claims,
broken sentinels, commit-without-sentinel pairs). For each issue found, record:
- Item type
- Affected path / branch / file
- Recommended remediation (one line)

Output file: $GIT_FILE
## TL;DR
- Severity: 'urgent' (broken sentinel or commit-without-sentinel >30 min old) | 'warn' (stale worktree or orphan branch) | 'info' (no issues)
- N issue(s) found

## Findings
<bulleted list, one item per finding>

Write ONLY the git hygiene file — no other edits."
)
```

---

### Tick aggregation — `WATCH_TICK_<UTC>.md`

At the END of each `/loop` tick (after all four fan-out duties complete and their Haiku sub-agents have written their output files), Watchman writes a single tick summary:

**File:** `$LOGS/WATCH_TICK_<UTC>.md`

```markdown
# Watchman tick summary — <UTC>

### Duty 5 — Cross-story drift scan (v0.32.0+, R50)

When `kingdom.json.watchman.duties.crossStoryScan` is true and story pods are in flight, the watchman runs `watchman_cross_story_scan "$PROJ"` (see [`_primitives.md`](../_primitives.md)) each tick. It does a pairwise `git merge-tree` across all `story/*` branches and emits a drift summary.

This is the King's cross-story signal (R50): the watchman only **detects and reports** drift (it never resolves). The King consumes the latest drift line at push time and coordinates a rebase / re-merge of the affected story branch before opening its PR. The boundary with the Senior holds: the Senior owns *within-story* conflicts (R49); the watchman flags *between-story* drift; the King resolves it. Output severity: `warn` (a documented-decision contradiction across stories may be `urgent`).

## TL;DR
- Develop SHA: <sha> (moved | unchanged)
- Smoke: pass | fail | skipped
- Haiku sub-agents spawned: N / <haiku_cap_per_tick>
- Highest severity this tick: urgent | warn | info

## Duty results
| Duty | Ran? | Findings | Severity | Output file |
|---|---|---|---|---|
| Code review fan-out | yes / no (cap) | N reviews written | urgent/warn/info | WATCH_REVIEW_... |
| CVE scan | yes / no (no lockfile) | N advisories | urgent/warn/info | WATCH_CVE_... |
| Cross-lane conflict scan | yes / no (cap) | N overlaps | urgent/warn/info | WATCH_CONFLICTS_... |
| Git hygiene scan | yes / no (cap) | N issues | urgent/warn/info | WATCH_GIT_... |

## Lane activity
| Lane | New commits | Files changed | Conflicts |
|---|---|---|---|
| worker-1 | N | N | — |
...

## Cap warnings
<list any duties skipped or trimmed due to haiku_cap_per_tick, or "none">
```

**Urgent escalation:** If any duty's output file contains `severity: urgent` (case-insensitive in its TL;DR), Watchman renders a `watchman-tick` card (from the `cards/` directory) and fires `cmux_notify` to both `$KING_WS` and `$WATCHMAN_WS`. Non-urgent ticks are logged only; no notification.
