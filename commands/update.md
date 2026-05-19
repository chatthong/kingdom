---
description: (Building block — most users want /kingdom:day instead, which runs this automatically.) Force a docs/log/task audit pass on the current project — Layer-1 project scan + fan-out Haiku readers, then checkbox/orphan/log reconcile + gap synthesis. Idempotent.
argument-hint: [project=<name>] [--force]
---

> **Most users want [`/kingdom:day`](day.md) instead.** `/kingdom:day` always runs this audit as Step 1 + then spawns lanes + enters the auto-gate-poll loop. Use `/kingdom:update` standalone only for mid-day re-audits when watchman flags fresh findings, or to refresh the audit-trail without entering the poll loop.

You are running a forced audit pass on the kingdom's audit-trail artifacts for ONE project. The goal: bring `.kingdom/<project>/{logs,tasks}/` into a self-consistent state AND surface gaps between the project's actual state and what the kingdom has recorded. Idempotent; safe to run any time.

## Step 0 — Resolve project + flags

From `$ARGUMENTS`, extract `project=<name>` (defaults to `basename "$PWD"`) and the optional `--force` flag (defaults to false). `--force` skips the interactive prompts in Step 0.5; warnings still print to the report but never block.

Run:
```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom:init ${project}` must be run first, and stop.

## Step 0.5 — Git state precheck (auto-switch to kingdom)

The audit runs cleanest when the project worktree is on the `kingdom` integration branch (an always-local view that mirrors `origin/<base>` plus any in-flight lanes). Switch to it automatically; never prompt. Switching to kingdom has zero side effects on the user's work: uncommitted changes follow the checkout (git refuses only on direct conflicts), and kingdom is local-only so no remote state changes.

```bash
cd "$PWD/${project}"
echo "👑 git state precheck:"

CURRENT=$(git branch --show-current)
BASE=$(jq -r '.git.base // "develop"' "$PWD/.kingdom/${project}/kingdom.json")

# 1. Fetch latest base
git fetch origin "$BASE" --quiet 2>/dev/null

# 2. Auto-switch to kingdom (create if missing); merge origin/<base>
if [ "$CURRENT" != "kingdom" ]; then
  echo "  ℹ️  was on '$CURRENT' — auto-switching to 'kingdom' integration branch"
  if ! git checkout kingdom 2>/dev/null; then
    if ! git checkout -b kingdom "origin/$BASE" 2>/dev/null; then
      echo "  ❌ git checkout kingdom failed — likely uncommitted changes conflict with kingdom"
      echo "      Resolve with: git stash    (then re-run /kingdom:update)"
      exit 1
    fi
  fi
fi

# 3. Merge origin/<base> into kingdom (idempotent — no-op if already current)
if ! git merge --no-edit "origin/$BASE" 2>&1 | tail -5; then
  echo "  ❌ merge origin/$BASE → kingdom failed (likely conflict). Resolve manually, then re-run."
  exit 1
fi
echo "  ✅ on kingdom · merged origin/$BASE"

# 4. Dirty working tree? Informational only — never blocks.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "  ℹ️  working tree has uncommitted changes (followed from $CURRENT) — Step 3.1 will footnote checkbox matches"
  DIRTY=1
else
  DIRTY=0
fi
```

**Behaviour summary:**

| Situation | Action |
|---|---|
| Already on `kingdom` | Fetch + merge `origin/<base>`. No prompt. |
| On any other branch (`develop`, `working`, `worker-N`, `feature/*`, anything) | Auto-checkout `kingdom`, merge `origin/<base>`. No prompt. Uncommitted changes follow the checkout. |
| `git checkout kingdom` refused (conflicting uncommitted changes) | STOP. Print: "Resolve with: `git stash`, then re-run". Don't override the user's working state. |
| Merge `origin/<base>` → `kingdom` produces conflicts | STOP. User resolves manually, re-runs. Don't auto-resolve. |
| Working tree dirty after switch | Informational only — audit proceeds. Step 3.1 footnotes every newly-ticked checkbox: `> ⚠️ matched commit while working tree was dirty — verify manually`. |

**Why auto-switch is safe:**

- `kingdom` is a **local-only integration branch**. It is never pushed; nothing outside your machine sees it.
- A checkout doesn't lose uncommitted changes: git either carries them over (no conflict) or refuses the switch (conflict) without modifying them.
- The merge from `origin/<base>` is idempotent: if `kingdom` is already up-to-date, the merge is a no-op.
- Audit results are more accurate on `kingdom` because `git log` reflects the latest `origin/<base>` plus integrated lane tips.

The `--force` flag still exists for one purpose only: skip the conflict-stop behaviour and continue auditing on whatever branch you ended up on (typically used when investigating a stuck merge; rare).

## Step 1 — Inventory (no edits yet)

Collect counts:

```bash
ls "$PWD/.kingdom/${project}/tasks/"*.md       2>/dev/null | wc -l   # task files
ls "$PWD/.kingdom/${project}/logs/"*.md        2>/dev/null | wc -l   # curated digests
ls "$PWD/.kingdom/${project}/logs/raw/"*.md    2>/dev/null | wc -l   # raw artifacts
ls "$PWD/.kingdom/${project}/logs/done/"*.flag 2>/dev/null | wc -l   # sentinels
wc -l "$PWD/.kingdom/${project}/logs/master_agent.log" 2>/dev/null   # log lines

# Project doc inventory (what the gap-scan will read)
find "$PWD/${project}" \
  \( -name '.git' -o -name 'node_modules' -o -name '.next' -o -name 'dist' \
     -o -name 'build' -o -name '.venv' -o -name '__pycache__' -o -name '.kingdom' \) -prune -o \
  \( -name '*.md' -o -name '*.txt' -o -name '*.csv' \) -type f -print | wc -l
```

Report the inventory + project doc count to the user before continuing.

## Step 2 — Dispatch the Audit Lead (Sonnet, background)

Spawn ONE Sonnet sub-agent via the Agent tool, `run_in_background=true`. This is the **Lead**: it **fans out 4 specialist sub-agents in parallel** (each owns a coherent slice of Steps 3.0-3.6), waits for all 4 sentinels, then synthesizes Step 3.7 gaps and writes the closer itself.

**Why fan out:** sequential Lead-does-everything was the bottleneck. Steps 3.0-3.6 have disjoint write sets and (mostly) independent reads; running them in parallel cuts wall-clock from ~5min sequential to ~90s (longest specialist gates the rest).

Lead brief (substitute `<PROJECT>` + `<PWD>` + `<UTC>` where shown):

> You are the **Audit Lead** for `/kingdom:update` on project `<PROJECT>`. Working dir: `<PWD>`. Audit root: `<PWD>/.kingdom/<PROJECT>/`. You are **read-mostly + low-risk-write**. NEVER edit project source code. NEVER push. ONLY edit files under `.kingdom/<PROJECT>/{tasks,logs}/`. Idempotent: if a fix is already applied, skip it silently.
>
> Your job in 3 phases:
>
> 1. **Spawn 4 specialists in parallel** (single Bash with 4 `Agent(...)` calls, all `run_in_background=true`).
> 2. **Poll all 4 sentinels** in ONE blocking Bash loop (zero token cost while waiting).
> 3. **Synthesize Step 3.7 gaps** (uses outputs from A + B + C), write the closer.
>
> ---
>
> ### Specialist A — 🐱 Project scanner (Sonnet sub-Lead, owns Step 3.0)
>
> Brief:
>
> > Find all `.md` / `.txt` / `.csv` files in `<PWD>/<PROJECT>/` excluding `.git/`, `node_modules/`, `.next/`, `dist/`, `build/`, `.venv/`, `__pycache__/`, `.kingdom/`. Chunk into N slices, N = min(10, ceil(count/20)). Spawn one **Haiku** sub-agent per slice via `Agent(model="haiku")`, all parallel.
> >
> > Each Haiku scanner brief: read each file in its slice; extract **completion markers** (`[x]`, `✅`, `Status:\s*(done|shipped|completed)`, `DONE\b`, `Shipped on YYYY-MM-DD`, `Completed on YYYY-MM-DD`, dated done-bullets), **pending markers** (`[ ]`, `Status:\s*(pending|in.progress|blocked)`, `TODO\b`, `FIXME\b`), and **references to other files** (markdown links `[…](path.md)`, prose mentions `see X.md` / `(X.md)` / `points to X.md` / `details in X.csv`). **Transitive read 1 hop only:** if a reference looks load-bearing for completion status, read that linked file too. Return JSON: `{ file, completion_markers, pending_markers, refs_followed, summary }`.
> >
> > Wait for all Haikus (single blocking poll). Synthesize a **project reality picture**: list of completion claims (file:line + claim + date), list of pending items, cross-file deps.
> >
> > Closer: raw at `logs/raw/<UTC>__sonnet-audit-A-project.md` (Haiku outputs verbatim), digest at `logs/audit-A-project-<UTC>.md`, log line, sentinel `logs/done/<UTC>__sonnet-audit-A.flag`.
>
> ### Specialist B — 🐱 Task reconciler (Sonnet, owns Step 3.1)
>
> Brief:
>
> > For each `tasks/*.md`, parse the checkbox list. For each unchecked item, search `git log --all --oneline` in the project's primary checkout for a commit message matching the item's keywords. If found, tick the box in place and append `→ <SHA>` inline. For each checked item, verify a commit exists; if none, leave checked but add footnote: `> ⚠️ flagged by /kingdom:update <UTC>: claimed done but no commit trace`.
> >
> > If git state precheck reported DIRTY=1 (Lead passes this in your brief), ALSO add this footnote on every newly-ticked checkbox: `> ⚠️ matched commit while working tree was dirty — verify manually`.
> >
> > Writes scope: ONLY `tasks/*.md`. Closer: raw at `logs/raw/<UTC>__sonnet-audit-B-tasks.md`, digest at `logs/audit-B-tasks-<UTC>.md`, log line, sentinel `logs/done/<UTC>__sonnet-audit-B.flag`.
>
> ### Specialist C — 🐱 Logs reconciler (Sonnet, owns Steps 3.2 + 3.3 + 3.5)
>
> Brief:
>
> > **Step 3.2 — Orphan raw artifacts.** For each `logs/raw/<ID>__*.md` with NO corresponding `logs/<ID>.md`: generate a curated digest (TL;DR + key decisions + files touched) from the raw, write to `logs/<ID>.md`, append a log line to `master_agent.log`. **ID extraction:** strip known shard suffixes (`__kimi-p<N>`, `__shard-<N>`, `__pane<N>`) first; fall back to `<UTC>` prefix match for leftovers.
> >
> > **Step 3.3 — Missing log lines.** For each `logs/<ID>.md` not represented in `master_agent.log`, append a one-line summary.
> >
> > **Step 3.5 — Digest re-understanding (flag-only, HIGH-RISK).** For each `logs/<ID>.md` where the raw contains material the digest dropped that NOW looks load-bearing, list path + reason under `## Digest re-understanding candidates` in your digest. DO NOT rewrite digests in place.
> >
> > Writes scope: `logs/*.md` (new digests, never overwrite existing), `master_agent.log` (append-only). Closer: raw at `logs/raw/<UTC>__sonnet-audit-C-logs.md`, digest at `logs/audit-C-logs-<UTC>.md`, log line, sentinel `logs/done/<UTC>__sonnet-audit-C.flag`.
>
> ### Specialist D — 🐱 Organization audit (Sonnet, owns Steps 3.4 + 3.6)
>
> Brief:
>
> > **Step 3.4 — Stale `[[name]]` links.** Grep all `tasks/*.md` and `logs/*.md` for `[[name]]` patterns. If the target file doesn't exist, leave the link but add a footnote flagging it.
> >
> > **Step 3.6 — Merge / archive candidates (flag-only).** Flag any: (a) two task files covering the same component drift → merge candidate; (b) task files older than 30 days with all boxes checked → archive candidate. DO NOT execute merges or archives.
> >
> > Writes scope: footnotes appended to `tasks/+logs/*.md` (additive, never modify existing content). Closer: raw at `logs/raw/<UTC>__sonnet-audit-D-org.md`, digest at `logs/audit-D-org-<UTC>.md`, log line, sentinel `logs/done/<UTC>__sonnet-audit-D.flag`.
>
> ---
>
> ### Polling all 4 sentinels (one blocking Bash call)
>
> ```bash
> until [ -f "logs/done/<UTC>__sonnet-audit-A.flag" ] && \
>       [ -f "logs/done/<UTC>__sonnet-audit-B.flag" ] && \
>       [ -f "logs/done/<UTC>__sonnet-audit-C.flag" ] && \
>       [ -f "logs/done/<UTC>__sonnet-audit-D.flag" ]; do
>   sleep 5
> done
> ```
>
> Then `cat` each specialist's digest into a buffer for Step 3.7.
>
> ---
>
> ### Step 3.7 — Gap synthesis (Lead does this directly, post-fan-out)
>
> Cross-reference Specialist A's **project reality picture** against Specialist B's task results + Specialist C's log results + the existing `master_agent.log` + curated digests. Write two new sections in your final report:
>
> ```markdown
> ## Gap A — Project says done, kingdom has no record
> - <file>:<line> claims "<completion text>" (<date if found>); no master_agent.log entry matching <topic keyword> near <date>
>
> ## Gap B — Kingdom logged it, project docs don't reflect it
> - master_agent.log:<line> shipped <topic> on <UTC> — <project-doc-path> still lists it as <pending text at file:line>
> ```
>
> Match heuristic: topic keyword fuzzy-match + date proximity (±3 days).
>
> ---
>
> ### Lead's closer (after Step 3.7)
>
> - **Aggregate raw log:** `logs/raw/<UTC>__sonnet-kingdom-update.md` — combine all 4 specialists' raws (verbatim) + your gap-synthesis notes
> - **Aggregate curated digest:** `logs/kingdom-update-<UTC>.md` — top-level summary referencing each specialist's digest, plus the two `## Gap A` / `## Gap B` sections you wrote. Must include: `## Counts: fixed=N (B+C aggregated) re-understood-flagged=N suspect=N merge-candidates=N archive-candidates=N gap-a=N gap-b=N`
> - **Master log line:** append to `master_agent.log` summarising the aggregate
> - **Final sentinel:** `logs/done/<UTC>__sonnet-kingdom-update.flag`
>
> The 4 specialist digests stay in `logs/` as referenceable sub-reports; King can drill into any of them.

## Step 3 — Poll + report

Poll the sentinel flag in a single blocking Bash call (zero token cost while waiting):

```bash
until [ -f "$PWD/.kingdom/${project}/logs/done/${UTC}__sonnet-kingdom-update.flag" ]; do
  sleep 5
done
```

Then render the [`audit-summary`](../.kingdom/.setting/cards/audit-summary.md) card with the run stats:

```bash
REPORT="$PWD/.kingdom/${project}/logs/kingdom-update-${UTC}.md"
N_CHECKBOXES_FLIPPED=$(grep -c '^- \[x\]' "$REPORT" 2>/dev/null || echo 0)
N_ORPHANS_BACKFILLED=$(grep -c '^### Orphan backfilled:' "$REPORT" 2>/dev/null || echo 0)
N_LOG_LINES_REPAIRED=$(grep -c '^### Log line repaired:' "$REPORT" 2>/dev/null || echo 0)
N_DIGESTS_STALE=$(grep -c '^### Stale digest:' "$REPORT" 2>/dev/null || echo 0)
N_TASK_MERGES=$(grep -c '^### Merge candidate:' "$REPORT" 2>/dev/null || echo 0)
N_SUSPECT=$(grep -c '^### Suspect:' "$REPORT" 2>/dev/null || echo 0)

export PROJECT="$project" N_SPECIALISTS=4 DURATION \
  N_CHECKBOXES_FLIPPED N_ORPHANS_BACKFILLED N_LOG_LINES_REPAIRED \
  N_DIGESTS_STALE N_TASK_MERGES N_SUSPECT REPORT_PATH="$REPORT"
render_card "audit-summary"
```

Then `cat` the report for the user to scroll. Highlight any `⚠️ flagged` entries, the `## Digest re-understanding candidates`, and the new `## Gap A` / `## Gap B` sections: those need King's attention.

## Step 4 — King's follow-up (advisory)

For each flagged item, the King decides:
- **Digest re-understanding candidate** → dispatch an Opus sub-agent with the digest + raw path; have it rewrite the digest in place.
- **Merge candidate** → King authors a consolidation task file; assigns to a lane.
- **Archive candidate** → King moves the task file to `tasks/archive/<YYYY-MM>/` (subdirectory; never delete).
- **Suspect (claimed done but no commit)** → King investigates: lane crash? wrong branch? lost work?
- **Gap A (project says done, kingdom unaware)** → King either backfills a synthetic `master_agent.log` line documenting the out-of-band work, or dispatches a worker to verify and replicate.
- **Gap B (kingdom done, docs not updated)** → King dispatches a doc-update task to a worker (small scope: edit the named file to reflect shipped state).

Stop. King drives next steps from the report.

---

## Conventions

- **Idempotent.** Re-running re-fixes nothing already fixed. Safe to invoke daily / weekly / pre-release.
- **Current project only.** This command never touches sibling projects under `.kingdom/`.
- **Parallel by default.** Lead spawns 4 specialists (A/B/C/D) in one Agent batch + Specialist A spawns up to 10 Haiku scanners. Peak concurrency: ~10-15 agents. Wall-clock target: under 2 minutes on a typical mid-size project.
- **Disjoint write sets.** B writes only `tasks/*.md`; C writes only new `logs/<ID>.md` + appends `master_agent.log`; D writes only footnotes (additive). No two specialists touch the same line; safe to run in parallel without locks.
- **Sonnet specialists, Haiku scanners.** Lead and the 4 specialists are Sonnet. Project scanner's fan-out children are Haiku (P2 chain: cheap parallel reads). Escalate to Opus only when Specialist C's `## Digest re-understanding candidates` warrant follow-up rewrites (King-dispatched, separate run).
- **Transitive read = 1 hop.** A Haiku scanner reads a referenced file when the current file flags it as load-bearing for completion status — but does NOT recurse from there. Prevents fan-out blow-up.
- **Watchman overlap.** Watchman runs continuous low-risk audit (including the same project-scan pattern, flag-only) during idle `/loop` time — see `.kingdom/.setting/watchmans.md` → "Docs audit duty". `/kingdom:update` is the explicit one-shot version.
