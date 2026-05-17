# Changelog

All notable changes to `claude-kingdom` are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

---

## [0.3.0] — 2026-05-17

The "audit safety net" release. Adds a forced sweep command + extends watchman with scoped write authority for idle-time docs cleanup.

### Added

- **`/kingdom-update`** — new slash command that forces a docs/log/task audit pass on one project. Spawns a Sonnet sub-agent that re-reads every task file in `.kingdom/<project>/tasks/`, cross-checks each checkbox against `git log`, backfills orphan raw artifacts (raw with no curated digest), repairs missing `master_agent.log` summary lines, and flags higher-risk items (stale digests, merge candidates, archive candidates, suspect entries) for King review. Idempotent; current project only.
- **Watchman docs audit duty** — new section in `watchmans.md` granting watchman scoped write authority on its own project's `tasks/`+`logs/` for low-risk fixes during idle `/loop` time (stale checkboxes, missing log lines, dead `[[name]]` links). Higher-risk findings (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md` for King review.
- **`WATCH_DOCS_AUDIT.md`** — new single-file-per-project rolling artifact at `<workspace>/.kingdom/<project>/logs/WATCH_DOCS_AUDIT.md`. Watchman appends findings; King reviews + clears bullets after acting.
- **"Reviewing watchman audit findings" section** in `kings.md` — documents how/when King consumes `WATCH_DOCS_AUDIT.md` and what to do with each finding category.
- **`/kingdom-doctor` Check 8** — informational scan for orphan raw artifacts (raw with no curated digest). Suggests `/kingdom-update` when found.
- **README FAQ entries** — `/kingdom-update` purpose + watchman write-authority scope.

### Changed

- **Watchman is no longer purely read-only.** Watchman now has WRITE authority scoped to `<workspace>/.kingdom/<project>/{tasks,logs}/`, low-risk fixes only. Project source code, role specs, `kingdom.json`, and `.git/` remain forbidden.
- **Role Control table in `index.md`** — watchman row's `Writes` cell expanded to include `WATCH_DOCS_AUDIT.md` + low-risk fixes during docs audit duty.
- **Watchman's "What watchmen DO / DO NOT do" tables** — clarified that source code remains read-only; low-risk audit writes are allowed; high-risk audit fixes (digest rewrite, merge, archive, role-doc rewrite) are flag-only.

### Compatibility notes

- **Behaviour change** — anyone running v0.2.x watchmen will see the watchman make small edits to `tasks/*.md` and `master_agent.log` during idle time. These are bounded (newest 20 task files + 20 digests per scan) and always low-risk. To opt out, set `watchmen[i].docsAudit = false` in `kingdom.json` (defaults to `true`).
- **Non-breaking** for `kingdom.json` schema — the new `docsAudit` field is optional and defaults to enabled.
- **`WATCH_DOCS_AUDIT.md` is new** — existing kingdoms won't have one until watchman's next idle tick creates it.

---

## [0.2.0] — 2026-05-17

The "actually opinionated" release. Major architectural changes that lock in how the kingdom thinks about work, model selection, and audit trails.

### Added

- **Task files** — new per-task audit artifact at `<workspace>/.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`. Checkbox doc capturing the multi-layer plan (Discovery → Strategy → Execution → Verification), in-progress progress notes, and final summary. Lane master is sole writer; sub-agents and everyone else read only. One file per task; never deleted, never reused.
- **Multi-layer planning** — explicit recursive fan-out pattern in lane master execution. Layer 1 (Discovery, Haiku fan-out) → Layer 2 (Strategy, Sonnet/Opus) → Layer 3 (Execution, Sonnet parallel) → Layer 4 (Verification). Documented as the canonical pattern in `workers.md`; cross-referenced from `kings.md`, `co-workers.md`, `index.md`.
- **Role Control authoritative table** in `index.md` — single source of truth for what each role can/can't do (writes / reads / spawns / pushes / edits / plans). Per-role files now document HOW; this table defines WHAT.
- **Auto-detect outer host mode** — `/kingdom-start` and `/kingdom-doctor` now auto-detect PRIMARY (manaflow/cmux.app) vs FALLBACK (raw tmux) vs HEADLESS (`claude -p`). No user config needed; King adapts to what's installed.
- **Native Mermaid diagrams** — every ASCII chart in role docs, README, and git.md converted to Mermaid (16 diagrams total: 2 in README + 4 in git.md + 4 in kings.md + 3 in workers.md + 2 in watchmans.md + 1 in co-workers.md + 1 in index.md). No theme directive — GitHub auto-adapts to user's light/dark theme.
- **King's own task files for planning sessions** — slug `king-plan` (e.g., `2026-05-17T0900Z__king-plan__pick-todays-3-tasks.md`). Same schema as lane-master task files.
- **CHANGELOG.md** (this file).

### Changed

- **Lane master model defaults** — Worker and Co-worker now default to **Opus** (was Sonnet). King is unchanged (Opus). Watchman remains Sonnet (passive monitor; doesn't need top-tier reasoning). Sub-agents continue to follow the P1/P2/P3 chain (Sonnet/Haiku/Opus).
- **Priority chain semantics clarified** — "P1 = Sonnet (default)" now explicitly applies to sub-agents only, not to lane masters. Two-tier framing documented in `index.md`.
- **Repo layout restructured** to mirror the consumer workspace layout:
  - `templates/role-files/*.md` → `.kingdom/.setting/*.md`
  - `templates/kingdom.json.template` → `.kingdom/templates/kingdom.json.template`
  - Slash commands updated to reference the new paths.
- **README rewritten** — replaced the "What a session looks like" transcript with role intros ("Meet the King — and the masters that work for it"). Expanded `/kingdom-new` documentation to a 5-use-case block (mid-size, large, solo, UI-heavy, unattended) with concrete `workers=N co-workers=M watchman=K` examples. Added FAQ entry for task files.
- **All worker / co-worker slug examples** swapped from `sonnet-worker-1` to `opus-worker-1` to match the new model defaults. Watchman slugs remain `sonnet-watchman-1`.
- **kingdom.json.template** — each `workers[i]` and `coworkers[i]` entry now has explicit `"model": "opus"`; each `watchmen[i]` entry has `"model": "sonnet"`. `_comment` documents the convention.

### Removed

- **craigsc/cmux dependency** — kingdom no longer requires the worktree-CLI wrapper. Worktree management now uses plain `git worktree add/remove` (built into git ≥ 2.5). One less install step; no PATH collision risk.
- **"What a session looks like" transcript** in README — replaced with the role intro section (see Changed).
- **Common shapes table** in README's `/kingdom-new` section — replaced with 5 per-use-case blocks (each its own emoji + heading + code block) for cleaner rendering at narrow widths.
- **AGENTS.md mirror pattern** — never used in v0.x; kit is Claude-only. Documented retirement in role files.

### Fixed

- Stale `templates/role-files/` and `templates/kingdom.json.template` path references in slash commands and README after the layout restructure.
- Inconsistent model labels across role docs (some still said "Sonnet" for lane masters after the Opus default was set).
- README's branch-model ASCII diagram had wrapping issues at narrow viewports → replaced with side-by-side Mermaid subgraphs.

### Compatibility notes

- **Breaking** for anyone who installed v0.1.x and customised paths under `templates/role-files/` — those moved to `.kingdom/.setting/`. Re-run `/kingdom-init` after upgrading to pick up the new layout.
- **Non-breaking** for anyone who used v0.1's `kingdom.json` — schema is additive (new optional fields, defaults kept compatible).
- **Behaviour change**: Worker / Co-worker lanes now spawn Opus by default. Cost-per-lane increases. Override in `kingdom.json.workers[i].model` if you want Sonnet for cost reasons (Sonnet is still valid for these roles; just no longer the default).

---

## [0.1.0] — 2026-05-16

Initial public release.

### Added

- 4 slash commands: `/kingdom-doctor`, `/kingdom-init`, `/kingdom-new`, `/kingdom-start`.
- 6 role docs in `templates/role-files/`: `index.md`, `kings.md`, `workers.md`, `co-workers.md`, `watchmans.md`, `git.md`.
- `kingdom.json.template` config template.
- `CMUX-Guide.md` (manaflow/cmux reference).
- `TMUX-Guide.md` (tmux 101 for the fallback path).
- README with install + usage + role overview.
- LICENSE (MIT).
