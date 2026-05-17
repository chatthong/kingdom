---
description: Force a docs/log/task audit pass on the current project — re-check checkboxes, re-understand stale digests, fix orphan artifacts. Idempotent.
argument-hint: [project=<name>]
---

You are running a forced audit pass on the kingdom's audit-trail artifacts for ONE project. The goal: catch anything master / sub-agent / watchman missed, and bring `.kingdom/<project>/{logs,tasks}/` into a self-consistent state. Idempotent — safe to run any time.

## Step 0 — Resolve project

From `$ARGUMENTS`, extract `project=<name>`. If missing, default to the basename of `$PWD`.

Run:
```bash
ls "$PWD/.kingdom/${project}/" 2>/dev/null && echo "PROJECT_EXISTS" || echo "PROJECT_MISSING"
```

If `PROJECT_MISSING`, tell the user `/kingdom-new ${project}` must be run first, and stop.

## Step 1 — Inventory (no edits yet)

Collect counts:

```bash
ls "$PWD/.kingdom/${project}/tasks/"*.md       2>/dev/null | wc -l   # task files
ls "$PWD/.kingdom/${project}/logs/"*.md        2>/dev/null | wc -l   # curated digests
ls "$PWD/.kingdom/${project}/logs/raw/"*.md    2>/dev/null | wc -l   # raw artifacts
ls "$PWD/.kingdom/${project}/logs/done/"*.flag 2>/dev/null | wc -l   # sentinels
wc -l "$PWD/.kingdom/${project}/logs/master_agent.log" 2>/dev/null   # log lines
```

Report the inventory to the user before continuing.

## Step 2 — Dispatch the audit sub-agent (Sonnet, background)

Spawn ONE Sonnet sub-agent via the Agent tool, `run_in_background=true`. Escalate to Opus ONLY if the agent's report flags digest re-understanding candidates (Step 3.5 below); never default to Opus.

Sub-agent brief (substitute `<PROJECT>` + `<PWD>` + `<UTC>` where shown):

> You are the `/kingdom-update` audit agent for project `<PROJECT>`. Working dir: `<PWD>`. Audit root: `<PWD>/.kingdom/<PROJECT>/`. You are **read-mostly + low-risk-write**. NEVER edit project source code. NEVER push. ONLY edit files under `.kingdom/<PROJECT>/{tasks,logs}/`. Idempotent: if a fix is already applied, skip it silently.
>
> Execute every step in order. Write a final summary report to `.kingdom/<PROJECT>/logs/kingdom-update-<UTC>.md`.
>
> **Step 3.1 — Task file checkbox reconciliation.** For each `tasks/*.md`:
> - Parse the checkbox list (`- [ ]` / `- [x]`).
> - For each unchecked item, `git log --all --oneline` in the project's primary checkout for a commit message matching the item's keywords. If found, tick the box and append `→ <SHA>` inline.
> - For each checked item, verify a commit exists. If none, leave checked but add a footnote: `> ⚠️ flagged by /kingdom-update <UTC>: claimed done but no commit trace`.
>
> **Step 3.2 — Orphan raw artifacts.** For each `logs/raw/<ID>__*.md` with NO corresponding `logs/<ID>.md`:
> - Generate a curated digest (TL;DR + key decisions + files touched) from the raw.
> - Write to `logs/<ID>.md`.
> - Append a log line to `master_agent.log`.
>
> **Step 3.3 — Missing master_agent.log lines.** For each `logs/<ID>.md` not represented in `master_agent.log`, append a one-line summary.
>
> **Step 3.4 — Stale `[[name]]` links.** Grep all `tasks/*.md` and `logs/*.md` for `[[name]]` patterns. If the target file doesn't exist, leave the link but add a footnote flagging it.
>
> **Step 3.5 — Digest re-understanding (HIGH-RISK, flag-only).** For each `logs/<ID>.md` where the raw contains material the digest dropped that NOW looks load-bearing (judgment call):
> - DO NOT rewrite in place.
> - List the digest path + one-line reason in your final report under `## Digest re-understanding candidates`.
>
> **Step 3.6 — Merge / archive candidates (flag-only).** Flag (do NOT execute) any:
> - Two task files covering the same component drift → merge candidate.
> - Task files older than 30 days with all boxes checked → archive candidate.
>
> **Closer (mandatory):**
> - Raw log: `logs/raw/<UTC>__sonnet-kingdom-update.md`
> - Curated digest: `logs/kingdom-update-<UTC>.md` (must include `## Counts: fixed=N re-understood-flagged=N suspect=N merge-candidates=N archive-candidates=N`)
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

Show the digest to the user. Highlight any `⚠️ flagged` entries and the `## Digest re-understanding candidates` section — those need King's attention.

## Step 4 — King's follow-up (advisory)

For each flagged item, the King decides:
- **Digest re-understanding candidate** → dispatch an Opus sub-agent with the digest + raw path; have it rewrite the digest in place.
- **Merge candidate** → King authors a consolidation task file; assigns to a lane (or self-handles for `king-plan` planning tasks).
- **Archive candidate** → King moves the task file to `tasks/archive/<YYYY-MM>/` (subdirectory; never delete).
- **Suspect (claimed done but no commit)** → King investigates: lane crash? wrong branch? lost work?

Stop. King drives next steps from the report.

---

## Conventions

- **Idempotent.** Re-running re-fixes nothing already fixed. Safe to invoke daily / weekly / pre-release.
- **Current project only.** This command never touches sibling projects under `.kingdom/`.
- **Sonnet default.** Mechanical checking is well within Sonnet capability; Opus only for digest rewrites (King-dispatched follow-up).
- **Watchman overlap.** Watchman runs continuous low-risk audit during idle `/loop` time (see `.kingdom/.setting/watchmans.md` → "Docs audit duty"). `/kingdom-update` is the explicit one-shot version when King wants a forced full sweep.
