# king-watchman-integration.md — King ↔ Watchman contract

> Extracted from [`king.md`](king.md) (v0.35.0 modular reorg). The full contract for how the King consumes the Watchman's output at every decision point — mandatory reads, pre-dispatch checks, daily kickoff routine, reading patterns, and the no-watchman fallback.

See [`king.md`](king.md) for the King role overview, [`watchman.md`](watchman.md) for the Watchman role, [`index.md`](../index.md) for the entry-point router.

---

## Working WITH the Watchman (mandatory when one exists)

The Watchman is NOT background decoration. It writes `WATCH_*.md` reports for every develop tick + PR state change, maintains `watchman_state.json` with current PR snapshots + `blocked_lanes` map, and surfaces `WATCH_DOCS_AUDIT.md` gap findings. **The King must read these at every major decision point** — otherwise watchman is doing work nobody consumes.

### Mandatory reads (before every major King decision)

| King action | Files to read first | Why |
|---|---|---|
| **First message after `/kingdom:work`** (daily kickoff) | **Workspace CLAUDE.md + Project CLAUDE.md + `~/.claude/projects/<ws>/memory/MEMORY.md` + the user's personal notes + Newest 5 `WATCH_*.md` + `WATCH_DOCS_AUDIT.md` + `watchman_state.json`** + **`haiku_read_docs_orientation "king" "$PROJ" "$LOGS"`** (R45, v0.31.1+ — fans out up to 10 Haiku in parallel across the WHOLE project: Phase 1 scans every directory for `readme.md` / `index.md` / `todo*.md` wayfinding files (cap 30); Phase 2 reads the 20 newest `*.md` everywhere else, minus test-reports. Consolidated digest lands at `<LOGS>/.king_<UTC>_doc_context.md`) | Full context: workspace rules, project conventions, the user's preferences, watchman state, AND a fresh project-docs digest. Skipping any of these breaks trust within minutes. |
| **Dispatch a new task to a lane** | `watchman_state.json.blocked_lanes` | Don't dispatch to a lane already blocked on a permission prompt or stuck Claude session |
| **Run pre-commit gate** | Latest `WATCH_*develop_green.md` OR `WATCH_*develop_RED_*.md` | If develop just broke, abort the gate; tell the user to wait until watchman reports green |
| **Ask the user "push?"** | Latest `WATCH_*pr-<N>_*.md` + `watchman_state.json.pr_states[N]` | Flag if the same PR has unaddressed review comments, CI mid-flight, or other watchman concerns |
| **Answer "what's the state?"** | All of the above + `master_agent.log` tail | Comprehensive status, not just lane progress |
| **Long idle / blocking poll** | `watchman_state.json` last-updated timestamp | If watchman has been silent >2× its expected tick, alert the user — watchman may have crashed |

### Pre-dispatch checks (King-side, before sending a brief)

Before `cmux send --workspace $WORKER_WS_N -- "<brief>"`:

```bash
source "$LOGS/workspace-refs.env"   # exposes KING_WS, WORKER_WS_N, etc.

# 1. Is develop green?
LATEST_DEV=$(ls -1t "$PROJ/docs/test-reports/WATCH_"*develop_*.md 2>/dev/null | head -1)
if echo "$LATEST_DEV" | grep -q 'develop_RED'; then
  echo "⛔ develop is RED per $(basename "$LATEST_DEV") — pause dispatch until watchman reports green"
  return 1
fi

# 2. Is the target lane blocked?
TARGET_VAR="WORKER_WS_${N}"
BLOCKED=$(jq -r ".blocked_lanes[\"${TARGET_VAR}\"] // false" "$LOGS/watchman_state.json" 2>/dev/null)
if [ "$BLOCKED" = "true" ]; then
  echo "⛔ ${TARGET_VAR} is blocked (per watchman_state.json) — resolve before dispatching new work"
  return 1
fi

# 3. PR queue clear? (informational, not blocking)
READY=$(jq -r '[.pr_states[]? | select(.ready_to_merge==true)] | length' "$LOGS/watchman_state.json" 2>/dev/null || echo 0)
if [ "$READY" -gt 0 ]; then
  echo "ℹ️  PR queue has $READY ready-to-merge — consider clearing before piling on new work"
  # Continue anyway — King decides
fi

# All checks pass → safe to dispatch
```

### Daily kickoff routine (King's first message of the day)

> **R36 (Tier 1):** Workspace rename + lane spawn happen FIRST (work.md Step 0.4), before context load or processing. User must see immediate sidebar feedback before any of the steps below fire.

On the first dispatch after `/kingdom:work`, the King runs **Session-start context load → Watchman state read → Synthesis** in that order. Context load comes FIRST because watchman state alone is missing the surrounding instructions the user has written.

#### Step −1 — Session-start context load (mandatory)

Before reading watchman state, King reads every authoritative context source:

```bash
WS="$PWD"   # workspace root (where the King was launched)

# 1. Workspace-level CLAUDE.md — workspace rules, project map, cross-cutting conventions
[ -f "$WS/CLAUDE.md" ] && Read "$WS/CLAUDE.md"

# 2. Project-level CLAUDE.md — local stack, gate commands, project-specific rules
[ -f "$WS/${PROJECT}/CLAUDE.md" ] && Read "$WS/${PROJECT}/CLAUDE.md"

# 3. Auto-memory index — durable user preferences, feedback rules, project facts
WS_KEY=$(echo "$WS" | sed 's|/|-|g; s|^-|-|')   # encode path the way Claude Code does
MEM_DIR="$HOME/.claude/projects/${WS_KEY}/memory"
[ -f "$MEM_DIR/MEMORY.md" ] && Read "$MEM_DIR/MEMORY.md"

# 4. Skim flagged memory entries (feedback + project types — load on relevance)
#    MEMORY.md is the index; specific entries are read JIT when the day's plan
#    suggests they apply. King reads the index lines + the title/description of
#    each entry to decide which are load-bearing today.

# 5. Personal notes (if present + Ter has named them)
#    Examples: TER.md, TER_WEEK.md, NOTES.md at workspace root or project root.
#    King reads ONLY for situational awareness — NEVER paste verbatim, NEVER
#    commit; summary into the kickoff synthesis if relevant.
for NOTES in "$WS/TER.md" "$WS/${PROJECT}/TER.md" "$WS/NOTES.md"; do
  [ -f "$NOTES" ] && Read "$NOTES"
done
```

The King synthesises this into a brief "context loaded" line in the kickoff output so the user sees what got picked up:

```
👑 Context loaded:
   • Workspace CLAUDE.md   (Bonfire — multi-project workspace, 8 projects)
   • Project CLAUDE.md     (bfg-swt — Django+Next.js+Keycloak, develop→main flow)
   • MEMORY.md             (42 entries — 18 feedback, 7 user, 14 project, 3 reference)
   • Personal notes        (TER.md — read but never quoted)
```

This step is **non-negotiable**. Without it, the King may dispatch tasks against rules the user has explicitly written down ("never use Prisma migrations", "confirm before every edit", "no source-project attribution in commits") and burn the user's trust + cycles re-correcting.

**R41 (Tier 2):** After loading context, King resolves its own process-skill set (`pick_skills_for_task` against `skill-routing.md`) before deciding today's plan — see work.md Step 0.3.5 for the full resolution procedure.

#### Step 0 — Watchman state read

Then the watchman state read happens (per § "Mandatory reads" above). The combined Step −1 + Step 0 output is the **single synthesis paragraph** the user sees:

```text
👑 Good morning.

Context loaded:
   • Workspace CLAUDE.md   (Bonfire — multi-project workspace, 8 projects)
   • Project CLAUDE.md     (bfg-swt — Django+Next.js+Keycloak, develop→main flow)
   • MEMORY.md             (42 entries; will load specific ones JIT)
   • Personal notes        (TER.md — read but never quoted)

Watchman state:
   • develop:        green @ 2026-05-18T01:30Z (latest tick)
   • PR queue:       2 open
                       #234 — CI green, awaiting your review (idle 4h)
                       #236 — CI failed × 3 retries (last 01:20Z)
   • Lanes blocked:  none
   • Gap findings:   1 Gap-A in WATCH_DOCS_AUDIT.md
                       docs/STEP.md claims "Phase 2 done" — no log trace
   • Last watchman tick:  2 min ago (healthy)

Today's plan (king-plan task file: 2026-05-18T0900Z__king-plan__monday-kickoff.md):
   1. Address Gap A — dispatch worker-3 to verify Phase 2 reality
   2. Resume in-flight — worker-1 on BE-AUTH-3 (last at L3/4 73%)
   3. Investigate #236 CI fail — possibly fix-task to worker who pushed it
   4. Hold worker-2 idle — clear #234 first if you want

Awaiting your go / overrides.
```

King writes this synthesis every morning, after every long break, and whenever the user says "what's the state?".

**R33 (Tier 2):** Before deciding "Today's plan," King MUST scan `.kingdom/<project>/tasks/*.md` for in-flight task files (status `planning|executing|verifying` with no matching sentinel). Resume queue takes priority over fresh dispatch — the synthesis "Today's plan" section should open with resume candidates before new work. See work.md Step 0.6 for the full scan procedure.

### Reading patterns (bash helpers)

```bash
# Latest watchman develop heartbeat (passing OR failing)
ls -1t "$PROJ/docs/test-reports/WATCH_"*develop_*.md 2>/dev/null | head -1

# All PR transitions logged today
ls -1t "$PROJ/docs/test-reports/WATCH_"*pr-*.md 2>/dev/null \
  | xargs -I{} grep -l "$(date -u +%Y-%m-%d)" {} 2>/dev/null

# Current PR state snapshot
jq '.pr_states' "$LOGS/watchman_state.json"

# Blocked lanes (output of v0.14.6 blocked-lane scan)
jq '.blocked_lanes' "$LOGS/watchman_state.json"

# Gap findings
[ -f "$LOGS/WATCH_DOCS_AUDIT.md" ] && cat "$LOGS/WATCH_DOCS_AUDIT.md"

# Watchman alive check (last tick timestamp)
jq -r '.last_smoke_ts' "$LOGS/watchman_state.json"
```

### What changes when there's NO watchman (shape: `watchman: 0`)

If the kingdom was started with `watchman: 0` in `kingdom.json.shape`, the King skips all watchman reads — those checks become no-ops. King still does the rest (lane state from `master_agent.log`, gate runs, push approvals) but has no automated develop / PR / blocked-lane visibility. This is a valid choice for solo-fast-prototype work but loses the safety net. **Default kingdom shape includes 1 watchman for a reason.**

### Anti-pattern: ignoring watchman alerts

The King MUST NOT:

- ❌ Dispatch new tasks while develop is RED without telling the user first
- ❌ Skip reading `WATCH_DOCS_AUDIT.md` at session start (it has Gap A/B findings that should shape today's plan)
- ❌ Treat blocked-lane alerts as "the lane will figure it out" — blocked lanes need human resolution or kingdom dispatch
- ❌ Send a "push?" prompt without checking the PR's latest watchman alert first

If watchman is sending alerts that the King keeps ignoring, the kingdom is worse than running solo. Watchman is the King's eyes — closed eyes are no eyes.
