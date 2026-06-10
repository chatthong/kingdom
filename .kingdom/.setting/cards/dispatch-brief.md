# dispatch-brief

**Fires when:** King dispatches a task to a lane via `cmux send` / `tmux send-keys` / `claude -p`.
**Used by:** [`king.md`](../roles/king.md) dispatch flow; this is the prompt template sent TO lanes (NOT shown in user chat).

## Template

This card is **flow-text, no box-drawing, no GitHub alert wrapper** — it's the raw text sent into the lane's Claude session. Each lane reads it as its task brief.

```text
[BRIEF: ${LANE} · ${TASK_ID}]

📚 Read first (before any code/plan — REQUIRED, R45):
${READ_FIRST_LIST}

Task: ${STORY_HEADING}

Acceptance criteria (mirrored from ${LEDGER_PATH} §${TASK_ID}):
${AC_BULLETS}

Dependencies: ${DEPENDENCIES}
Reference: ${REFERENCE}
Deadline: ${DEADLINE}

Suggested skills (per-task; pick what fits, ignore if unavailable):
${SUGGESTED_SKILLS}

Long/multi-file work: fan out via the Workflow tool (R53) — self-detect
  availability first; if absent, bounded Agent()/visible tabs. One run per task.
Questions/blockers: inbox_send king question ${TASK_ID} yes "..." — don't stall
  silently (R55). Keep working on continuable parts; check your own inbox between steps.

Layer plan:
  L1 Discovery   — pattern grep, identify existing conventions (R8 mandatory)
  L2 Strategy    — choose approach, list edits
  L3 Execution   — write code, flip TODO checkboxes IN PLACE (R24)
  L4 Verify      — Tier-1 gate, write sentinel (R22)

Step 0 (REQUIRED BEFORE ANY EDIT):
  Write task file at .kingdom/${PROJECT}/tasks/${UTC}__${LANE}__${TASK_ID}.md
  per R23 schema (Status / Brief / Plan / Progress notes / Final summary).

Standards (rules.md):
  R8  exhaustive pattern grep before implementation
  R22 closer fires on EVERY completion (raw + curated + log + sentinel)
  R23 task file Step 0 before any sub-agent dispatch
  R24 task file continuously updated, not write-once
  R25 update BOTH kingdom task file AND project task-ledger
  R28 parallel by default for scan + non-conflicting edit
  R51 fan heavy work out to parallel sub-agents (soft target ~10;
      sonnet=standard, haiku=bulk reads/greps, opus=sensitive)

Issue closure (K12): FLAG-ONLY. Never run `gh issue close`. To close an
  issue, put `Closes #N` in the PR body (the lead's merge auto-closes it) OR
  flag it to king-inbox for the lead. Closure = lead sign-off, not lane action.

Commit message style: ${COMMIT_STYLE}
Branch: ${LANE} (DO NOT push; King carves feature/<topic> at push time per R9)

When done: fire closer (raw → curated → master_agent.log → sentinel).
King's auto-gate poll will pick it up and run Tier-1, then overlay onto kingdom for Tier-2.
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane being dispatched | `worker-2` |
| `${TASK_ID}` | task ID from queue | `FE-P0-FOUND.7` |
| `${READ_FIRST_LIST}` | King-composed 3-7 entries the lane MUST read before any work: project CLAUDE.md (always); the docs/ files matching the task domain; the task's key source files. One per line, each `  • <path> — <why>`. See [`king.md`](../roles/king.md) → Composing the Read-first list. | (multi-line, see below) |
| `${STORY_HEADING}` | full Story title from TODO ledger | `Per-app SEO metadata (URL/meta/canonical/ALT)` |
| `${LEDGER_PATH}` | path to project's TODO file | `TODO_Webshop.md` |
| `${AC_BULLETS}` | indented acceptance-criteria list extracted from the Story | (multi-line) |
| `${DEPENDENCIES}` | blocking PRs/tasks, or `none` | `FE-P0-FOUND.8 (PR #258)` |
| `${REFERENCE}` | spec/PR/issue link | `docs/gap-reviews/SWT_2026-05-06.md` |
| `${DEADLINE}` | if any | `none` |
| `${PROJECT}` | active project | `my-app` |
| `${UTC}` | UTC timestamp `YYYY-MM-DDTHHMMZ` | `2026-05-18T1142Z` |
| `${COMMIT_STYLE}` | from `kingdom.json.git.commitStyle` | `Conventional Commits: feat/fix/docs/...` |
| `${SUGGESTED_SKILLS}` | output of `pick_skills_for_task` (or user override). 0-3 lines, each prefixed `  → Skill <name> · <why>`. If empty, the `Suggested skills` line + its content are both dropped from the brief. | (multi-line, see below) |

## `${SUGGESTED_SKILLS}` rendering

The helper `pick_skills_for_task` (in [`functions/index.md`](../functions/index.md)) returns 0-3 entries, each formatted as:

```text
  → Skill nextjs-best-practices · matches keyword: "app router"
  → Skill shadcn-ui · matches keyword: "components.json"
  → Skill supabase:supabase · matches keyword: "supabase-js"
```

If the helper returns empty (no keyword matched), the entire `Suggested skills:` line is dropped from the brief along with its block — no hollow heading.

If the user passed `skill=<name>[,<name>...]` in the instruction, the helper short-circuits and uses that list verbatim. `skill=none` → empty list → dropped section.

## `${READ_FIRST_LIST}` rendering

The King composes this per task — 3 to 7 entries, one per line, each `  • <path> — <why one-liner>`:

```text
  • my-app/CLAUDE.md — project conventions + gate commands (ALWAYS)
  • docs/auth.md — the documented auth pattern this task touches
  • src/lib/auth/session.ts — the file you're extending
  • src/middleware.ts — the call site that consumes it
```

The list is REQUIRED (never empty): the first entry is always the project CLAUDE.md. The King picks the rest from (a) `docs/` files whose name/topic matches the task domain and (b) the task's key source files (grep the brief's nouns against the repo). This is the per-task complement to the lane's own R45 doc orientation — it points the lane straight at the load-bearing files instead of making it rediscover them. See [`king.md`](../roles/king.md) → Composing the Read-first list.

## Notes

- This card is what flows through `cmux_send "<lane-ws>" "<brief>"`. It's NOT printed to the user's chat; it's a system message between King and the lane.
- The brief is intentionally explicit about rules.md references because lanes spawn fresh contexts each task; reminding them up-front is cheaper than re-correcting later.
- For co-workers (paired with the user), drop the "When done: fire closer" autonomous-completion line; co-workers wait for user input at each layer transition.
