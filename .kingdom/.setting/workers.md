# workers.md — Worker role + 4-step closer

Workers are the autonomous task-execution lanes (`worker-1`, `worker-2`, …). Each runs a long-lived Claude Code teammate in its own `git worktree` on its own `worker-N` branch. Workers pick claimable sub-tasks from the project's task source, execute via their own sub-agent fleet, and signal the King with the 4-step closer.

See [`index.md`](index.md) for entry-point context, [`kings.md`](kings.md) for who dispatches and gates worker work, [`co-workers.md`](co-workers.md) and [`watchmans.md`](watchmans.md) for the other lane roles, [`git.md`](git.md) for branch model.

---

## Worker lane role

- Autonomous task workers. Each lane master picks an unclaimed sub-task from the project's task source (declared in `kingdom.json.taskSource` — CSV path, GH issues filter, Linear project ID, etc.).
- Lane focus (which component a worker owns) is configured per project via `kingdom.json.workers[i].focus` + `ownsPaths`. The King uses these to match claimable sub-tasks to lanes.
- Lane master itself runs **Opus** (high-quality coding inside the lane). Executes via its own sub-agent fleet (P1 Sonnet / P2 Haiku / P3 Opus, unbounded parallel — see Spawn rights below).
- Signals the King via the standard 4-step closer (raw + curated + log + sentinel flag).

---

## Task claiming

Before assigning a sub-task to a lane, **King** writes a claim file:

```bash
echo "worker-1 | $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOGS/claims/$SUBTASK_ID.lane"
```

- Path: `<LOGS>/claims/<sub-task-id>.lane` (e.g., `BE-P0-CICD.1.lane`)
- Contents: `<lane-name> | <UTC>`
- Cleared when the lane's PR is merged
- King checks `<LOGS>/claims/` before picking any new task — if a claim exists, skip that sub-task

Workers don't write claims. King does. Workers just receive their assignment via the dispatch prompt.

---

## Task file (mandatory — first thing the lane writes)

Every task assigned to a lane gets its own **task file** — checkbox doc tracking the multi-layer plan, in-progress progress, and final summary. It's the audit trail for HOW the work happened. Lane master is the sole writer; sub-agents and others read only.

**Path:** `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`
**Example:** `2026-05-17T1430Z__worker-1__BE-P0-CICD.1.md`

**Step 0 of every task** (before any sub-agent dispatch): the lane master creates the task file from this template:

```
# Task: <sub-task-id> — <one-line summary>

## Status
- [ ] planning → [ ] executing → [ ] verifying → [ ] done | blocked

## Brief
<2-4 lines from the King's dispatch prompt: what to do + acceptance criteria>

## Plan (multi-layer)

### Layer 1 — Discovery
- [ ] Spawn N× Agent(haiku) to read <file globs>
- [ ] Synthesise findings

### Layer 2 — Strategy
- [ ] Based on Layer 1, decide approach
- [ ] (optional) Spawn 1× Agent(opus) for sensitive design review

### Layer 3 — Execution
- [ ] Spawn N× Agent(sonnet) for parallel edits — one per logical chunk
- [ ] Run lane-local typecheck after each chunk

### Layer 4 — Verification
- [ ] Run lane-local smoke tests
- [ ] Self-review: does the diff match the brief's acceptance criteria?
- [ ] Run 4-step closer

## Progress notes
<append date-stamped entries as work happens>

## Final summary
<written when status → done OR blocked. covers: what landed, what didn't, why, follow-ups>
```

The status checkboxes are flipped sequentially as work progresses. Each Layer's bullets are checked off as their sub-agents complete. Progress notes are appended freely (one paragraph per layer-completion or significant event).

**Lifecycle:**
- **Created** in Step 0 of every task. Lane never starts sub-agent dispatch without writing the task file first.
- **Updated** continuously — check boxes off, append progress notes, refine plan as discovery yields surprises.
- **Finalised** when status → done or blocked: lane writes the "Final summary" section, then runs the 4-step closer.
- **Never deleted, never reused.** New task = new task file.

**Read access:** anyone (King, sub-agents, Watchman for context, Ter). **Write access:** lane master only. Sub-agents report progress via their own 4-step closer; lane master ingests their curated output and reflects it in the task file's progress notes / checkboxes.

---

## Spawn rights inside a lane — NO ECO MODE (applies to ALL models)

**The lane master itself runs Opus** (high-quality coding inside the lane). The sub-agents it spawns follow the P1/P2/P3 chain: **Sonnet** by default (P1), **Haiku** for bulk reads (P2), **Opus** for sensitive files (P3). The lane master's model is separate from the sub-agent chain.

Each lane master is a full Claude Code process and has the **Agent tool available**. Inside a single task it can:

- Spawn **as many** parallel sub-agents as the work needs — **across every model in the chain**, not just Haiku. The count comes from the work's *structure*, not from a 1:1 mapping. Examples of trade-offs:
  - 12 isolated file edits with no shared context → fan out 6-12 parallel `Agent(model="sonnet")` calls (one per file or per logical chunk).
  - 12 files where edits need consistent style / cross-file naming → maybe just 1-2 `Agent(model="sonnet")` calls each handling 6 files, because shared context produces a more coherent result than 12 isolated agents working blind.
  - Same logic for `haiku` (bulk reads — sometimes 1 agent with all 12 files in context summarises better than 12 isolated digests) and `opus` (sensitive work — 1 agent across related files often beats N isolated agents).
- Mix models freely per the P1/P2/P3 chain. A single task can fan out a mixed batch — e.g., 5 Sonnet edits + 2 Haiku digests + 1 Opus secret-rotation, all spawned in one message.
- Spawn sequentially when later work depends on earlier work, or in parallel when independent.
- **Never cap or "eco-throttle" for cost reasons** — but also don't max-out parallel just because you can. **Pick N from the work's structure: maximum that still gives the BEST RESULT.** Coherence > raw parallelism when work has cross-file dependencies.

Each layer's spawn pattern is captured in the task file's plan section (see Multi-layer planning below).

The only spawn rules binding a lane master are the P1/P2/P3 model-selection rules (see [`index.md`](index.md) → Sub-agent model priority) and the 4-step closer (below).

---

## Multi-layer planning (recursive fan-out)

Lane masters **plan before executing.** Planning produces 2-4 layers in the task file; each layer is a fan-out + synthesise step. Typical structure:

| Layer | Purpose | Typical model + count | Output |
|---|---|---|---|
| **1 — Discovery** | Read relevant code/docs | Agent(haiku) × N (one per file/module) | File inventory + summaries |
| **2 — Strategy** | Decide approach | Agent(sonnet) × 1 for design help; Agent(opus) × 1 if sensitive files involved | Refined plan in task file |
| **3 — Execution** | Make the edits | Agent(sonnet) × N (one per logical chunk; can be Opus for sensitive code) | Code changes in the lane's worktree |
| **4 — Verification** | Local checks before signalling done | Sometimes none (lane master runs typecheck itself); sometimes Agent(sonnet) × 1 for review | Confirm 4-step closer's curated digest is honest |

Each layer's sub-agents follow the 4-step closer themselves (raw + curated + log + flag). Lane master polls THEIR flags, reads their curated TL;DRs, synthesises, then ticks the layer's checkboxes in the task file before moving to the next layer.

Depth >4 is usually a sign of unclear scope — surface to King/Ter rather than spiral deeper.

**Spawn rules within a layer are unchanged** — see "Spawn rights" above. N is chosen for best result, not 1:1 with files. Coherence > raw parallelism when work has cross-file dependencies.

---

## Task sequencing inside a lane — sequential tasks, parallel sub-agents

A lane runs **one task at a time** (no two task briefs from the King in flight against the same lane). But **within that task**, the lane master self-plans its sub-agent fan-out and parallelises freely.

Sequence:

0. King sends task brief → lane pane. **Lane master creates the task file** (`<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`) with status, brief, and multi-layer plan filled in. No sub-agent is dispatched until the task file exists.
1. King sends task brief → lane pane (via `cmux send` / `tmux send-keys` / `claude -p`).
2. Lane master reads the brief, analyzes the work, plans its sub-agent strategy (recorded in the task file).
3. Lane master spawns its sub-agents — parallel where independent, sequential where dependent.
4. Lane master synthesizes sub-agent outputs, makes edits to the lane's worktree, updates task file progress notes and checkboxes.
5. Lane master finalises the task file (writes Final summary, flips status → done/blocked), then runs the 4-step closer.
6. King polls the sentinel flag, runs pre-commit gate → push approval (see [`kings.md`](kings.md) → Push approval gate).
7. Lane master receives `/compact` from King, then the next task brief — back to step 0.

Task lifecycle within a lane:

```mermaid
flowchart TB
    A(["⚙️ King sends task brief\n(cmux send / tmux send-keys / claude -p)"])
    A0["Step 0: Create task file\n(status + brief + multi-layer plan)"]
    B["Lane master reads brief\nplans sub-agent strategy"]
    C["Spawn sub-agents\n(parallel if independent, sequential if dependent)"]
    D["Synthesize outputs\nedit worktree\nupdate task file progress"]
    E0["Finalise task file\n(Final summary → done/blocked)"]
    E["Run 4-step closer\n(raw → curated → log → flag)"]
    F{"King polls\nsentinel flag"}
    G["Pre-commit gate\n+ push approval"]
    H(["King sends /compact\n→ next task brief"])

    A --> A0 --> B --> C --> D --> E0 --> E --> F
    F -- "flag present" --> G --> H
    H --> A

    classDef lane stroke:#6b7280,stroke-width:1.5px
    classDef king stroke:#a16207,stroke-width:1.5px
    classDef decision stroke:#1e40af,stroke-width:1.5px
    class A,H king
    class A0,B,C,D,E0,E lane
    class F decision
```

Lanes never receive a "queue" of multiple tasks; the King serialises task-to-lane assignment. This keeps the lane's reasoning context focused and the gate boundaries clean.

---

## Slug convention

- **Lane master itself** uses slug `<role>-<n>` (e.g., `opus-worker-1`).
- **Sub-agents spawned by lane master** use **dot-suffixed** slugs: `worker-1.a`, `worker-1.b`, `worker-1.docs`, `worker-1.tests` — chosen by the lane master per its internal partition.
- The shared `<LOGS>/` already disambiguates because the task `<ID>` is unique per dispatch.

---

## The 4-step closer (mandatory for every worker task)

The worker prompt has **four mandatory closing actions** done at the end of each task, in this order:

> **Note:** The task file (see "Task file" section above) is an auxiliary parallel artifact — like the claim file, it runs alongside the task lifecycle. The task file's "Final summary" section is written and status flipped to done/blocked **before step 1 of the closer fires.** The closer itself is always exactly 4 steps.

1. **Write raw** → `<LOGS>/raw/<ID>__<sub>-<lane-name>.md` (full raw output of the task)
2. **Write curated** → `<LOGS>/<ID>.md` with `## TL;DR` at top (machine-readable digest)
3. **Append 1-line status** → `<LOGS>/master_agent.log`
4. **Touch sentinel flag** → `<LOGS>/done/<ID>__<sub>-<lane-name>.flag` (+ optional `cmux notify --pane <self> 'lane <lane-name> done: <ID>'` for sidebar badge)

4-step write chain:

```mermaid
flowchart LR
    A[("raw/\nID__sub-lane.md")]
    B[("ID.md\n## TL;DR")]
    C[("master_agent\n.log")]
    D(["done/\nID__sub-lane.flag"])

    A -->|"1 write raw"| B
    B -->|"2 write curated"| C
    C -->|"3 append 1-line"| D

    classDef store stroke:#6b7280,stroke-width:1.5px
    classDef sentinel stroke:#15803d,stroke-width:1.5px
    class A,B,C store
    class D sentinel
```

Master writes nothing under `<LOGS>/`. The worker is the only writer for its task's artifacts.

### Required curated-artifact header (mandatory schema)

Every curated `.md` (single-worker self-curate OR archivist merge) must start with `## TL;DR` so master can read only the first ~15 lines via `Read(file_path, limit=15)`:

```markdown
# <Title>

## TL;DR
- **Status:** done | partial | failed
- <key finding 1 — one line>
- <key finding 2 — one line>
- <key finding 3 — one line, optional>
- **Next action:** <what master should do next, if anything>

---

- **Date (UTC):** <ISO>
- **Project:** <project basename>
- **Task type:** <doc-pull | code-survey | audit | migration-plan | …>
- **Sub-agent(s):** <lane-name> (worker) [+ archivist when multi-worker]
- **Mode / worker slugs:** standalone / a,b,c   (or CMUX / worker-1, worker-2, worker-3)
- **Inputs:** (list of raw paths used)
- **Master log refs:** `[<UTC>]`, …
- **Follow-up artifacts:** (links to other `<LOGS>/*.md` if any)

## Summary
<2–10 bullets — what was learned>

## Result
<merged content / table / synthesis>

## Followups / TODO
<bullets that should land in CLAUDE.md / <NAME>.md / a ticket>
```

Rules:

- `## TL;DR` is **mandatory** and must be the first section after the title (before the metadata block) so `Read(limit=15)` always sees it.
- Master's default read pattern: `Read(<ID>.md, limit=15)` first → only re-read without `limit` if the TL;DR is insufficient.
- The 4-step closer applies whether the worker was spawned via Agent / cmux teammate / tmux pane / claude -p. Same artifact layout in all dispatch modes.

---

## Shared `<ID>` rule (strict)

Every task gets one `<ID>` generated by the master. Raw + curated share it.

```text
<ID>  =  YYYY-MM-DDTHHMMZ__<task-type>__<sub-agent>__<kebab-slug>

raw      <LOGS>/raw/<ID>__<sub>-<lane-name>.md      ← one file per worker
curated  <LOGS>/<ID>.md                              ← worker self-curates (single) or archivist merges (multi)
flag     <LOGS>/done/<ID>__<sub>-<lane-name>.flag    ← sentinel
```

| Field | Rule | Example |
|---|---|---|
| `YYYY-MM-DDTHHMMZ` | UTC, `T`-separated, **no colons**, trailing `Z`. Sortable. | `2026-04-29T1914Z` |
| `task-type` | `doc-pull`, `code-survey`, `audit`, `migration-plan`, `e2e-run`, `bug-repro`, `refactor-plan`, `release-notes`, `kb`, `other`. Lowercase kebab. | `doc-pull` |
| `sub-agent` | `sonnet` / `haiku` / `opus` / `mixed` / `solo` | `sonnet` |
| `kebab-slug` | 2-6 lowercase words, hyphen-separated. **No paths.** | `repo-architecture-pull` |
| Worker suffix (raw) | `__<sub>-<lane-name>` where lane-name = `worker-N` / `co-worker-N` / `watchman-N` (CMUX mode) or short tag like `a`/`b`/`c` (standalone parallel fan-out). | `__opus-worker-1` |
| Separator | **Double underscore `__`** between fields (single `-` for date and slug). | |

---

## Path / ID helpers (master generates IDs; worker uses paths in its prompt)

```bash
# Workspace + project anchors — set once per session.
WS=/Users/ter/Desktop/Bonfire                       # workspace root
PROJ_NAME=<project>                                  # project directory basename
LOGS="$WS/.kingdom/$PROJ_NAME/logs"                 # this project's logs dir under .kingdom/

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

There is no `log_master` helper — master writes nothing. The worker prompt embeds its own `echo … >> master_agent.log` line as step 3 of the closer.

---

## Worker dispatch — Single-worker self-curate (most common)

Master dispatches via the `Agent` tool (standalone) or `cmux send` / `tmux send-keys` (kingdom mode). The lane master runs **Opus**; sub-agents it spawns follow the P1/P2/P3 chain (default = Sonnet for sub-agents).

```bash
# Master-side setup (Bash) — generate IDs and paths.
WS=/Users/ter/Desktop/Bonfire
PROJ=$WS/<project>
LOGS=$WS/.kingdom/$(basename "$PROJ")/logs
ID="$(make_artifact_id doc-pull opus docs-summary)"
mkdir -p "$LOGS/raw" "$LOGS/done"

SUB=opus
SLUG=solo                                # synthetic worker tag (single worker)
RAW="$(raw_path "$LOGS" "$ID" "$SUB" "$SLUG")"
CURATED="$(curated_path "$LOGS" "$ID")"
TASK_TYPE=doc-pull
```

Master issues the `Agent` call with the closer baked in:

```text
Agent(model="opus", prompt="""
Read <PROJ>/docs/ARCHITECTURE.md and produce a 5-bullet summary.

You MUST do FOUR things, in this exact order, before replying:

1) Write the full raw output to: <RAW>

2) Write a curated digest to: <CURATED>
   The curated file MUST start with this header (no exceptions):

   # <Title>

   ## TL;DR
   - **Status:** done | partial | failed
   - <key finding 1>
   - <key finding 2>
   - **Next action:** <next step>

   ---
   - **Date (UTC):** <ISO>
   - **Project:** <PROJ basename>
   - **Task type:** <TASK_TYPE>
   - **Sub-agent:** opus-<SLUG>
   - **Inputs:** <RAW>

   ## Summary
   <2-10 bullets>

   ## Result
   <merged content>

   ## Followups / TODO
   <bullets>

3) Append exactly one line to <LOGS>/master_agent.log:
   echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] task=<TASK_TYPE> id=<ID> sub=opus-<SLUG> status=<pass|fail> raw=raw/$(basename <RAW>) curated=$(basename <CURATED>)" >> <LOGS>/master_agent.log

4) Touch the done flag: touch <LOGS>/done/<ID>__opus-<SLUG>.flag

Reply with only: saved: <CURATED>
""")
```

After issuing, master blocks on the done flag (see [`kings.md`](kings.md) → Master idle policy).

### Kingdom-mode variant (lane runs inside a worktree)

When the kingdom is active (primary via cmux.app or fallback via raw tmux), the worker runs inside a lane worktree:

1. **Create** worktree: `git worktree add -b "worker-N" "$PROJ/.worktrees/worker-N" "origin/$BASE"` (run once at kingdom startup).
   **Resume** existing worktree: `cd "$PROJ/.worktrees/worker-N"` (worktree already exists).
2. Worker prompt uses **absolute paths** to `<workspace-root>/.kingdom/<project>/logs/` — that path is identical from primary checkout and from every worktree.

Filenames become:
```text
raw       <WS>/.kingdom/<project>/logs/raw/<ID>__opus-worker-1.md
curated   <WS>/.kingdom/<project>/logs/<ID>.md
flag      <WS>/.kingdom/<project>/logs/done/<ID>__opus-worker-1.flag
```

After the flag appears, the King decides: `cmux merge` (if commits to keep + Ter approves push) → carve `feature/<topic>` → push. See [`git.md`](git.md) → Commit flow.

---

## Multi-worker tasks

For parallel fan-outs, master issues multiple `Agent` calls (one per worker, each with its own slug) in **a single message** so they run concurrently. Each worker runs the same 4-step closer with its own slug. The curated path is shared (`<LOGS>/<ID>.md`) — the **last** worker to finish overwrites the previous one's `<ID>.md`, which is why multi-worker tasks require an archivist merge.

### Multi-worker archivist — required when ≥2 workers share an `<ID>`

When multiple workers contribute to the same `<ID>`, each writes its own raw and a per-worker curated, but they all overwrite the same `<ID>.md`. To get a coherent merged digest, spawn an archivist sub-agent as the **last step**. One-shot — no recycling.

Default archivist model = **Sonnet** (P1). Pick Haiku only if per-worker curated files are unusually large (≥10 KB each). Opus is not appropriate for archivist work unless the underlying task was already Opus-sensitive.

```bash
# 1. Wait for all worker done flags
for SLUG in a b c; do
  until [ -f "$LOGS/done/${ID}__opus-${SLUG}.flag" ]; do sleep 5; done
done

# 2. Compose the archivist prompt
INPUTS="a,b,c"
CURATE="Read every file in ${LOGS}/raw/ matching the prefix '${ID}__'.
Merge them into ONE curated artifact at:

  ${LOGS}/${ID}.md

This OVERWRITES whatever the per-worker self-curates wrote there. Use the
exact header from the 'Required curated-artifact header' section above
(## TL;DR first, then metadata, then ## Summary / ## Result / ## Followups).
The TL;DR must synthesise across all workers, not just one.

Then close out by appending ONE line to ${LOGS}/master_agent.log :

  echo \"[\$(date -u +%Y-%m-%dT%H:%M:%SZ)] task=doc-pull id=${ID} sub=sonnet-archivist status=merged curated=${ID}.md inputs=${INPUTS}\" >> ${LOGS}/master_agent.log

And touch the merge-done flag:

  touch ${LOGS}/done/${ID}__archivist.flag

Reply with only: saved: ${LOGS}/${ID}.md"

# 3. Issue archivist (standalone recommended; no worktree needed for archivist work):
Agent(model="sonnet", prompt=$CURATE)   # archivist stays Sonnet (P1); only the lane master is Opus

# 4. Master blocks on merge flag, then reads:
until [ -f "$LOGS/done/${ID}__archivist.flag" ]; do sleep 5; done
tail -n 5 "$LOGS/master_agent.log"
```

---

## When NOT to write artifacts

The 4-step closer is **mandatory for every information-producing worker task**. The only exemptions:

- **Pure orchestration plumbing by master** (cmux.app/tmux commands, parallel `Agent` dispatch, log tailing) — master-side shell/tool commands, not worker tasks.
- **Master-side `tail` / `Read` of existing artifacts** — reading is free, no new artifact needed.
- **Throw-away one-line probes** master runs itself (e.g., `ls`, `docker ps`) — not worker tasks; if you find yourself wanting to log them, you're probably missing a worker dispatch.

If a worker runs and produces any reasoning / analysis / file content, **all four closer steps are required** — don't skip the curated digest "to save time", because that's exactly what costs Opus tokens later when master has to read raw instead.

---

## What workers DO NOT do (King-only operations)

| ❌ Forbidden for workers | ✅ Belongs to King |
|---|---|
| `git push` | King runs all pushes — see [`kings.md`](kings.md) → Push approval gate |
| `feature/*` branch creation | King carves `feature/<topic>` from lane branch tip |
| `gh pr create` | King opens PRs after Ter's "push" OK + FINAL conflict check |
| FINAL conflict check against `origin/develop` | King runs `git merge-tree` after Ter approves |
| Authoritative pre-commit gate | King runs the gate; workers may run fast feedback tests internally but those are hygiene, not gating |
| Reuse task files across tasks | New task = new task file. Task files are never reused or overwritten for a subsequent task. |

Workers DO: read, edit, commit locally to `<role>-<n>`, spawn their own sub-agents (P1/P2/P3, no eco cap), run the 4-step closer, signal completion via the sentinel flag (+ optional `cmux notify` for sidebar badge). Everything else is the King.

---

## Sub-agent lifecycle inside a lane

A lane master is itself long-lived (across multiple tasks). Its sub-agents (`Agent(model=...)` calls it issues) are short-lived (one task per Agent call).

Lifecycle: what the lane master decides after each sub-agent's done flag appears.

```mermaid
flowchart TB
    F{{"⚙️ Sub-agent finished\n(done flag present)"}}
    S["SPAWN more\nAgent() calls\n(more work remains)"]
    D["SHUTDOWN\nAgent done\n(task complete)"]
    C["COMPACT\nlane master\n(/compact before next task)"]

    F -- "more sub-tasks\nindependent" --> S
    F -- "task complete\nno further work" --> D
    F -- "task complete\nnext task incoming" --> C

    S --> F

    classDef decision stroke:#1e40af,stroke-width:1.5px
    classDef action stroke:#6b7280,stroke-width:1.5px
    classDef compact stroke:#a16207,stroke-width:1.5px
    class F decision
    class S,D action
    class C compact
```

For lane master itself (long-lived across tasks): `/compact` between tasks is mandatory. Without it, lane context accumulates and pollutes the next task's reasoning. The King's per-task closing sequence ends with sending `/compact` to the lane pane via `cmux send` (or `tmux send-keys`).

For sub-agents spawned by lane master: each `Agent()` call is one-shot; it returns when done. The lane master collects results, synthesises, then moves to the next dispatch within the same task (or completes the task and runs the 4-step closer).

**Forbidden:**
- ❌ Lane master idle / "wait and see" without `/compact` — old context pollutes the next task.
- ❌ Repeat-round-trip polling — use one bash call with internal loop.
- ❌ Recycling a lane master across unrelated tasks without `/compact` first.
