---
description: Force a docs/log/task audit pass on the current project — Layer-1 project scan + fan-out Haiku readers, then checkbox/orphan/log reconcile + gap synthesis. Idempotent.
argument-hint: [project=<name>] [--force]
---

You are running a forced audit pass on the kingdom's audit-trail artifacts for ONE project. The goal: bring `.kingdom/<project>/{logs,tasks}/` into a self-consistent state AND surface gaps between the project's actual state and what the kingdom has recorded. Idempotent — safe to run any time.

## Step 0 — Resolve project + flags

From `$ARGUMENTS`, extract `project=<name>` (defaults to `basename "$PWD"`) and the optional `--force` flag (defaults to false). `--force` skips the interactive prompts in Step 0.5; warnings still print to the report but never block.

Run:
```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom:new ${project}` must be run first, and stop.

## Step 0.5 — Git state precheck

A dirty / off-branch / out-of-date working tree produces noisy audit results — Step 3.1 checkbox-reconcile matches against uncommitted code; Gap synthesis misses fresh upstream work. Verify the project's git state before continuing.

```bash
cd "$PWD/${project}"
echo "👑 git state precheck:"

# 1. Clean working tree?
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "  ⚠️  DIRTY  — uncommitted changes present:"
  git status --short | head -10
  DIRTY=1
else
  echo "  ✅ working tree clean"
  DIRTY=0
fi

# 2. On expected branch?
CURRENT=$(git branch --show-current)
BASE=$(jq -r '.git.base // "develop"' "$PWD/.kingdom/${project}/kingdom.json")
case "$CURRENT" in
  "$BASE"|kingdom|worker-*|co-worker-*|watchman-*) echo "  ✅ on branch: $CURRENT (recognised)"; OFFBRANCH=0 ;;
  *) echo "  ⚠️  OFF-EXPECTED-BRANCH: $CURRENT (expected: $BASE / kingdom / role-N)"; OFFBRANCH=1 ;;
esac

# 3. Up to date with origin/<base>?
git fetch origin "$BASE" --quiet 2>/dev/null
LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse "origin/$BASE" 2>/dev/null)
if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
  AHEAD=$(git rev-list --count "origin/$BASE..HEAD" 2>/dev/null || echo 0)
  BEHIND=$(git rev-list --count "HEAD..origin/$BASE" 2>/dev/null || echo 0)
  echo "  ℹ️  ahead $AHEAD / behind $BEHIND vs origin/$BASE"
fi
```

**Behaviour:**

| Check | Result | Action without `--force` | Action with `--force` |
|---|---|---|---|
| Dirty working tree | Files modified/staged | Print files + ask `continue anyway? (y/n)`. Stop on `n`. | Warn + continue |
| Off-expected branch | Branch ∉ {base, kingdom, role-N} | Ask `continue anyway? (y/n)`. Stop on `n`. | Warn + continue |
| Behind/ahead origin | Local SHA ≠ remote SHA | Info only — don't block | Same |

The Audit Lead receives these flags in its brief — `dirty=true` causes Step 3.1 to add a footnote on every newly-ticked checkbox: `> ⚠️ matched commit while working tree was dirty — verify manually`.

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

Spawn ONE Sonnet sub-agent via the Agent tool, `run_in_background=true`. This is the **Lead** — it fans out Haiku scanners for Step 3.0 (project state scan), then runs the mechanical reconcile steps + gap synthesis itself.

Lead brief (substitute `<PROJECT>` + `<PWD>` + `<UTC>` where shown):

> You are the **Audit Lead** for `/kingdom:update` on project `<PROJECT>`. Working dir: `<PWD>`. Audit root: `<PWD>/.kingdom/<PROJECT>/`. You are **read-mostly + low-risk-write**. NEVER edit project source code. NEVER push. ONLY edit files under `.kingdom/<PROJECT>/{tasks,logs}/`. Idempotent: if a fix is already applied, skip it silently.
>
> Execute every step in order. Write the final report to `.kingdom/<PROJECT>/logs/kingdom-update-<UTC>.md`.
>
> ---
>
> **Step 3.0 — Project state scan (Layer-1 fan-out).**
>
> Find all `.md` / `.txt` / `.csv` files in the project tree (excluding `.git/`, `node_modules/`, `.next/`, `dist/`, `build/`, `.venv/`, `__pycache__/`, `.kingdom/`). Chunk them into N slices where N = min(10, ceil(file-count / 20)). Spawn one Haiku sub-agent per slice via `Agent(model="haiku")` — all in parallel via the standard fan-out pattern.
>
> Each Haiku scanner receives this brief:
>
> > Scan this slice of project files: `<list of paths>`. For each file:
> >
> > 1. Read the file.
> > 2. Extract any **completion markers**: `[x]`, `✅`, lines matching `Status:\s*(done|shipped|completed)`, `DONE\b`, `Shipped on YYYY-MM-DD`, `Completed on YYYY-MM-DD`, dated done-bullets (`- 2026-MM-DD …`).
> > 3. Extract any **pending markers**: `[ ]`, `Status:\s*(pending|in.progress|blocked)`, `TODO\b`, `FIXME\b`.
> > 4. Extract **references to other files** that look load-bearing for completion status — markdown links `[…](path.md)`, prose mentions `see X.md` / `(X.md)` / `points to X.md` / `details in X.csv`.
> > 5. **Transitive read (1 hop only):** If a reference looks load-bearing for understanding completion (e.g., the current file says "Phase 0 status — see PHASE0_STATUS.md"), read THAT linked file too. Do NOT follow links from the linked file (single hop, no recursion).
> > 6. Return JSON: `{ file, completion_markers: [...], pending_markers: [...], refs_followed: [...], summary: "<2-3 sentences on what this file claims about project state>" }`.
>
> Wait for all Haiku scanners to complete (single blocking poll inside one Bash call — see kings.md → "Master idle policy").
>
> Synthesize all scanner outputs into a **project reality picture**:
> - List of all completion claims (file:line + claim + date if found).
> - List of all pending items.
> - Cross-file dependencies discovered through transitive reads.
>
> ---
>
> **Step 3.1 — Task file checkbox reconciliation.** For each `tasks/*.md`:
> - Parse the checkbox list (`- [ ]` / `- [x]`).
> - For each unchecked item, `git log --all --oneline` in the project's primary checkout for a commit message matching the item's keywords. If found, tick the box and append `→ <SHA>` inline.
> - For each checked item, verify a commit exists. If none, leave checked but add a footnote: `> ⚠️ flagged by /kingdom:update <UTC>: claimed done but no commit trace`.
>
> **Step 3.2 — Orphan raw artifacts.** For each `logs/raw/<ID>__*.md` with NO corresponding `logs/<ID>.md`, generate a curated digest (TL;DR + key decisions + files touched) from the raw, write to `logs/<ID>.md`, append a log line to `master_agent.log`. **ID extraction:** strip known shard suffixes from the raw filename first (`__kimi-p<N>`, `__shard-<N>`, `__pane<N>`), then if no exact-ID match found, fall back to matching by `<UTC>` timestamp prefix (the first `YYYY-MM-DDTHHMMZ` token). Many lane-shard raws are covered by a single parent digest at the same UTC + base slug — count them as covered, not orphaned.
>
> **Step 3.3 — Missing `master_agent.log` lines.** For each `logs/<ID>.md` not represented in `master_agent.log`, append a one-line summary.
>
> **Step 3.4 — Stale `[[name]]` links.** Grep all `tasks/*.md` and `logs/*.md` for `[[name]]` patterns. If the target file doesn't exist, leave the link but add a footnote flagging it.
>
> **Step 3.5 — Digest re-understanding (HIGH-RISK, flag-only).** For each `logs/<ID>.md` where the raw contains material the digest dropped that NOW looks load-bearing: list path + reason under `## Digest re-understanding candidates`. Do NOT rewrite in place.
>
> **Step 3.6 — Merge / archive candidates (flag-only).** Flag (do NOT execute) any merge or archive candidates.
>
> **Step 3.7 — Gap synthesis (NEW — uses Step 3.0 output).**
>
> Cross-reference the project reality picture against `master_agent.log` + `tasks/*.md` + curated digests. Write two new sections in the final report:
>
> ```markdown
> ## Gap A — Project says done, kingdom has no record
> - <file>:<line> claims "<completion text>" (<date if found>) — no master_agent.log entry matching <topic keyword> near <date>
> - ...
>
> ## Gap B — Kingdom logged it, project docs don't reflect it
> - master_agent.log:<line> shipped <topic> on <UTC> — <project-doc-path> still lists it as <pending text at file:line>
> - ...
> ```
>
> Match heuristic: topic keyword fuzzy-match + date proximity (±3 days). For Gap A, this surfaces out-of-band work. For Gap B, this surfaces docs that need updating.
>
> ---
>
> **Closer (mandatory):**
> - Raw log: `logs/raw/<UTC>__sonnet-kingdom-update.md` — include the Haiku scanner outputs verbatim
> - Curated digest: `logs/kingdom-update-<UTC>.md` (must include `## Counts: fixed=N re-understood-flagged=N suspect=N merge-candidates=N archive-candidates=N gap-a=N gap-b=N`)
> - Master log line: append to `master_agent.log`
> - Sentinel: `logs/done/<UTC>__sonnet-kingdom-update.flag`

## Step 3 — Poll + report

Poll the sentinel flag in a single blocking Bash call (zero token cost while waiting):

```bash
until [ -f "$PWD/.kingdom/${project}/logs/done/${UTC}__sonnet-kingdom-update.flag" ]; do
  sleep 5
done
cat "$PWD/.kingdom/${project}/logs/kingdom-update-${UTC}.md"
```

Show the digest to the user. Highlight any `⚠️ flagged` entries, the `## Digest re-understanding candidates`, and the new `## Gap A` / `## Gap B` sections — those need King's attention.

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
- **Sonnet Lead, Haiku fan-out.** Lead orchestrates; Haiku scanners do bulk reads (P2 chain — cheap parallel reads). Escalate Lead to Opus only when Step 3.5 flags warrant digest rewrites (King-dispatched follow-up).
- **Transitive read = 1 hop.** A Haiku scanner reads a referenced file when the current file flags it as load-bearing for completion status — but does NOT recurse from there. Prevents fan-out blow-up.
- **Watchman overlap.** Watchman runs continuous low-risk audit (including the same project-scan pattern, flag-only) during idle `/loop` time — see `.kingdom/.setting/watchmans.md` → "Docs audit duty". `/kingdom:update` is the explicit one-shot version.
