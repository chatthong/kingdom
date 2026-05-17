# Changelog

All notable changes to `kingdom` (formerly `claude-kingdom`) are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [SemVer](https://semver.org/).

---

## [0.10.0] — 2026-05-18

The "settings permissions + branch tree polish" release. Fixes a real failure mode where background sub-agents stalled silently because workspace `.claude/settings.json` had no `permissions.allow` list. Also polishes the README branch model diagram and fixes a stale config example.

### Added

- **`/kingdom:doctor` Check 10 — Workspace `.claude/settings.json` permissions.** Verifies the workspace-scoped settings file has `permissions.allow ⊇ {Bash, Read, Write, Edit, Grep, Glob, Agent}`. Without this, background sub-agents spawned by `/kingdom:update`'s parallel fan-out, by worker dispatches, by watchman alerts, etc., stall on permission prompts that nobody sees — sentinels never appear, audits never complete. Auto-patches with `jq` after user approval; preserves any existing keys; dedupes the allow-list.
- **`/kingdom:init` Step 4.5 — Workspace permissions scaffold.** Same check + patch as doctor's Check 10, but runs at scaffold time so the kingdom is usable on first dispatch without a separate doctor visit. Asks before writing.

### Changed

- **README hero branch diagram** — was a minimal abstract sketch (worker-1..N → feature/topic with one arrow). Now shows a concrete worked example: 3 features in flight (`feature/auth-refactor` from worker-1, `feature/checkout-flow` from co-worker-1, `feature/db-migrate` from worker-2) with every transition labelled: `git fetch + merge` (develop → kingdom), `git worktree add` (kingdom → lanes), `King carves + push + gh pr create` (lane → feature), `PR review → squash merge` (feature → develop), `release cycle` (develop → main). Uses role emojis (👑 👷 🧑‍💼 🕵️). Adds a "What lives where" table summarising each branch's lifetime + writer + whether it reaches origin.
- **README configure example** — stale v0.4-era config with `workers[i].focus` + `ownsPaths` removed (those were deprecated in v0.5.0 — workers are now generic capacity). Example now shows the actual current schema: `workers: [{slug, model}]`, `coworkers: [{slug, model}]`, `watchmen: [{slug, model, docsAudit}]`.

### Why this matters

Real failure: a user ran `/kingdom:update bfg-swt`, the Lead dispatched 4 parallel specialists in background, and nothing ever completed. Workspace `.claude/settings.json` was empty `{}` — every Bash call from each specialist hit a permission prompt, but background mode doesn't surface them. Sentinels never wrote. The fix (add `permissions.allow`) is one line of JSON; the cost of forgetting it is total system stall. Now both `/kingdom:init` and `/kingdom:doctor` check it.

---

## [0.9.0] — 2026-05-18

The "fan out the audit, stop waiting" release. Restructures `/kingdom:update` from "Lead does steps 3.1-3.7 sequentially" to "Lead spawns 4 specialists in parallel, then synthesizes gaps". Target wall-clock: under 2 minutes for typical mid-size projects (was ~5 min sequential).

### Changed

- **`/kingdom:update` is now Sonnet Lead + 4 parallel specialists + Haiku scanner fan-out.** The 4 specialists, all dispatched in one Agent batch and polled via a single blocking Bash loop:
  - 🐱 **A · Project scanner** (Sonnet sub-Lead) — owns Step 3.0 (Layer-1 project state scan). Itself fans out ≤10 Haiku scanners reading `.md`/`.txt`/`.csv` files with 1-hop transitive reads.
  - 🐱 **B · Task reconciler** (Sonnet) — owns Step 3.1 (checkbox reconciliation against `git log`). Writes only `tasks/*.md`.
  - 🐱 **C · Logs reconciler** (Sonnet) — owns Steps 3.2 + 3.3 + 3.5 (orphan digests + log backfill + digest re-understanding flags). Writes only new `logs/<ID>.md` + appends `master_agent.log`.
  - 🐱 **D · Organization audit** (Sonnet) — owns Steps 3.4 + 3.6 (stale `[[name]]` links + merge/archive candidates). Writes only additive footnotes.
- **Disjoint write sets.** B/C/D write to non-overlapping paths, so the parallel fan-out is race-safe without locks or coordination beyond the Lead's poll-and-aggregate.
- **Lead does Step 3.7 (gap synthesis) directly** after all 4 specialists complete. Uses Specialist A's project reality picture + B's task results + C's log results. Writes the aggregate `logs/kingdom-update-<UTC>.md` with two top-level `## Gap A` / `## Gap B` sections + counts.
- **4 specialist sub-digests survive** at `logs/audit-{A,B,C,D}-<...>-<UTC>.md` — King can drill into any of them when investigating a specific section of the aggregate.

### Why this matters

Real-test feedback on v0.8.0: the audit on bfg-swt was running every step sequentially inside one Sonnet, ~5 minutes wall-clock. With 4 parallel specialists, the same audit completes in under 2 minutes (longest-running specialist gates the rest). No correctness changes — only speed. Same digest structure, same gap surfacing.

---

## [0.8.0] — 2026-05-17

The "auto-switch" patch on top of v0.7.0. Refines `/kingdom:update` Step 0.5 to remove the off-branch prompt entirely — switching to `kingdom` is a local-only no-side-effect operation, so the audit just does it.

### Changed

- **`/kingdom:update` Step 0.5 — auto-switch to `kingdom`, never prompt.** Was: prompted `continue anyway? (y/n)` on off-expected-branch (e.g., `working` / `feature/*`). Now: auto-checkout `kingdom` (creates from `origin/<base>` if missing) + merges `origin/<base>` into it. No prompt. Reasoning: `kingdom` is local-only (never pushed), so switching to it has zero side effects on the user's work — uncommitted changes either follow the checkout cleanly or git refuses the switch (in which case audit STOPS and tells the user to `git stash`, not retry-on-press-Y).
- **Dirty working tree is now informational only.** No prompt — audit always proceeds. Step 3.1 footnotes every newly-ticked checkbox with `verify manually` when matching against a dirty tree, so the trust signal is in the audit output rather than a gate at the start.
- **`--force` flag scope narrowed.** v0.7.0 used `--force` to skip dirty/off-branch prompts (now removed since there are no prompts). `--force` now serves one purpose: continue auditing on the current branch when an `origin/<base>` merge into `kingdom` produces conflicts — used for stuck-merge investigation, rare.

### Why this matters

Real test case: bfg-swt was on its sanctioned scratch branch `working` (per `bfg-swt/SPEC-Git.md`). v0.7.0 flagged this as "off-expected-branch" and asked. v0.8.0 just switches to `kingdom`, pulls develop, and runs the audit — same answer the user would have given anyway, without the round-trip.

---

## [0.7.0] — 2026-05-17

The "git-aware + role-themed" release. Two user-driven additions: `/kingdom:update` now sanity-checks git state before auditing (dirty tree or off-branch surfaces immediately), and every role gets a distinctive emoji that flows through tab titles, dispatch templates, and chat conventions.

### Added

- **`/kingdom:update` Step 0.5 — Git state precheck.** Before any audit work, verify the project worktree is clean, on a recognised branch (`base` / `kingdom` / `worker-N` / `co-worker-N` / `watchman-N`), and report drift vs `origin/<base>`. Dirty tree or off-branch triggers an interactive `continue anyway? (y/n)` prompt. New `--force` flag skips prompts (warnings still log to the audit digest). When dirty, Step 3.1 footnotes every newly-ticked checkbox with `verify manually` so you don't trust an audit run against uncommitted code.
- **`/kingdom:doctor` Check 9 — Git state across projects.** Informational across-the-board sweep — for every project with a `kingdom.json`, reports `clean|DIRTY on <branch>` + drift indicator. Doesn't block; flags projects where `/kingdom:update` will prompt.
- **Role emoji convention** — new section in `.kingdom/.setting/index.md` documenting:
  - 👑 King
  - 👷 Worker
  - 🧑‍💼 Co-worker
  - 🕵️ Watchman
  - 🐱 Sub-agent

  Convention flows through: cmux/tmux tab titles (`👑 King`, `👷 worker-1`, …), dispatch templates, log line prefixes, chat replies relaying role activity, README hero diagram, and all role docs. Emojis are used WITHOUT skin-tone modifiers for cross-terminal stability.

### Changed

- **Role docs and templates** — bulk-swapped `⚙️` → `👷` (Worker), `🤝` → `🧑‍💼` (Co-worker), `👁` → `🕵️` (Watchman), `🧩` → `🐱` (Sub-agent) across `README.md`, `.kingdom/.setting/*.md`, and Mermaid hero diagrams. King's `👑` is unchanged.
- **`commands/start.md` Phase 6** — pane title setup now uses role-emoji prefixes (`cmux rename-tab "👷 worker-1"`, `tmux select-pane -T "👑 King"`, etc.) for visual scan-ability in the sidebar / pane-border-status row.

---

## [0.6.0] — 2026-05-17

The "learn first, then update" release. `/kingdom:update` becomes a true Layer-1 Discovery pass — it reads the project's own docs before reconciling logs/tasks, so the audit catches gaps between what the project claims and what the kingdom recorded. Also fixes a real over-count bug in `/kingdom:doctor` Check 8.

### Added

- **`/kingdom:update` Step 3.0 — Project state scan (Layer-1 fan-out).** Audit Lead (Sonnet) now spawns Haiku scanners in parallel (≤10) to read every `.md` / `.txt` / `.csv` file in the project tree. Each scanner extracts completion markers (`[x]`, `✅`, `Status: done`, "Shipped on YYYY-MM-DD", dated done-bullets), pending markers, and cross-file references. **Transitive read (1 hop):** when a file flags a referenced doc as load-bearing for completion status, the scanner reads that doc too — but no deeper, preventing recursion blow-up. Excluded dirs: `.git/`, `node_modules/`, `.next/`, `dist/`, `build/`, `.venv/`, `__pycache__/`, `.kingdom/`.
- **`/kingdom:update` Step 3.7 — Gap synthesis.** Cross-references the project reality picture against `master_agent.log` + `tasks/*` + curated digests. Two new sections in every audit digest:
  - `## Gap A — Project says done, kingdom has no record` — surfaces out-of-band work (manual commits, ad-hoc changes) where the project doc claims completion but no kingdom log entry exists.
  - `## Gap B — Kingdom logged it, project docs don't reflect it` — surfaces docs that need updating after shipped work.
- **King action table** (in `kings.md` → "Reviewing watchman audit findings") gets two new rows for Gap A and Gap B with the recommended follow-up per row (backfill log line vs dispatch doc-update task).
- **Watchman project-state scan (bounded)** — watchman's idle docs audit now does a small 5-file scan of project docs per tick, contributing to `## Gap A` / `## Gap B` sections of `WATCH_DOCS_AUDIT.md`. Flag-only — never edits project source.

### Changed

- **`/kingdom:update` is now Sonnet Lead + Haiku fan-out.** Mechanical reconcile (Steps 3.1-3.6) still happens, but the new Step 3.0 fan-out and Step 3.7 gap synthesis make the audit a proper Discovery pass — not just a mechanical sweep. Lead stays Sonnet; Haiku for parallel reads; Opus reserved for King-dispatched digest rewrites (Step 3.5 follow-up).
- **`/kingdom:doctor` Check 8 orphan-counting heuristic** — was using naïve `cut -d'_' -f1-2` which over-counted when raw filenames had lane-shard suffixes (e.g. `__kimi-p<N>`). Now strips known shard suffixes (`__kimi-p<N>`, `__shard-<N>`, `__pane<N>(-…)?`) before matching, then falls back to `<UTC>` timestamp-prefix match for leftovers. Tested case: bfg-swt audit dropped from 19 false-orphans → 12 actual orphans.

### Fixed

- File-path corruption from the v0.4.0 rename — `kingdom-update-<UTC>.md` filenames in `commands/update.md` had been incorrectly rewritten to `kingdom:update-<UTC>.md` (colon) by an over-broad sed. Restored to hyphen form.

---

## [0.5.0] — 2026-05-17

The "generic workers, any domain" release. Workers are no longer pre-specialised — every worker is identical capacity. King assigns task scope at dispatch time. Bonus: the kit is now explicitly domain-agnostic — code, research, finance, science, manuscripts.

### Changed

- **Workers are generic capacity.** Removed `workers[i].focus` and `workers[i].ownsPaths` from `kingdom.json` (and the same for `coworkers[i]`). Every worker starts identical; `worker-1` and `worker-2` are interchangeable. Same worker can do backend today, frontend tomorrow, finance-model audit the day after.
- **King assigns task scope per dispatch**, not per config. New "Dispatch brief schema" section in `kings.md` documents what King sends each worker. Cross-lane conflict prevention shifted entirely to (a) King's Layer-1 planning (sub-agents scan candidate task overlap) + (b) FINAL `git merge-tree` check at push gate. The combination replaces what `ownsPaths` did in v0.4.0 without the path-staleness problem.
- **`gate.*` keys are now explicitly arbitrary.** Template still ships `typecheck`/`tests`/`smoke`/`lint` as dev-friendly defaults, but role docs + template comments make clear the keys are user-defined. Finance kingdoms use `validate`/`audit`; science kingdoms use `reproduce`/`peer-review`; writing kingdoms use `spellcheck`/`fact-check`. Same `kingdom.json` schema, different vocabulary.
- **Domain-agnostic framing.** README hero + tagline + workers.md now state explicitly: kingdom works for any domain that uses git for versioning, not just software dev.
- **`kingdom.json.template` simplified.** Per-lane entries now have only `slug` + `model` (was: `slug` + `model` + `focus` + `ownsPaths`). Significantly smaller, faster to read.

### Compatibility notes

- **Breaking** for anyone who has filled in `workers[i].focus` or `workers[i].ownsPaths` in their `kingdom.json` for v0.4.0 or earlier. Migration:
  ```bash
  # Open .kingdom/<project>/kingdom.json
  # Delete every "focus" and "ownsPaths" key from workers[] and coworkers[]
  # Leave shape + git + gate untouched
  ```
  No re-install needed; the schema change is read-side only.
- **Non-breaking** for v0.4.0 users who did NOT customise focus/ownsPaths.
- **Behavioural change:** King now writes scope into each dispatch brief (lives in the task file at `tasks/<UTC>__<lane>__<id>.md`, not in `kingdom.json`). Audit trail is per-task instead of per-config — finer-grained, no staleness.

---

## [0.4.0] — 2026-05-17

The "rename" release. Drops the `claude-` prefix everywhere — plugin name, marketplace name, GitHub repo, and command names. Slash commands now read `/kingdom:doctor` instead of `/claude-kingdom:kingdom-doctor`.

### Changed

- **Plugin name** — `claude-kingdom` → `kingdom`. The slash-command namespace prefix is now `/kingdom:` instead of `/claude-kingdom:`. Reads cleaner and matches the brand.
- **Marketplace name** — `claude-kingdom` → `kingdom`. Install becomes `/plugin install kingdom@kingdom` (plugin@marketplace, both `kingdom`).
- **GitHub repo** — `chatthong/claude-kingdom` → `chatthong/kingdom`. Old URL auto-redirects via GitHub.
- **Command files** — dropped the redundant `kingdom-` prefix. The plugin namespace already provides the qualifier:
  - `commands/kingdom-doctor.md` → `commands/doctor.md` (slash: `/kingdom:doctor`)
  - `commands/kingdom-init.md` → `commands/init.md` (slash: `/kingdom:init`)
  - `commands/kingdom-new.md` → `commands/new.md` (slash: `/kingdom:new`)
  - `commands/kingdom-start.md` → `commands/start.md` (slash: `/kingdom:start`)
  - `commands/kingdom-update.md` → `commands/update.md` (slash: `/kingdom:update`)
- **All docs** — README, CHANGELOG intro, role docs in `.kingdom/.setting/`, CMUX-Guide.md, TMUX-Guide.md — all references to `/kingdom-<cmd>` updated to `/kingdom:<cmd>`.

### Compatibility notes

- **Breaking** for anyone on v0.3.x or earlier. To upgrade:
  ```
  /plugin marketplace remove claude-kingdom
  /plugin uninstall claude-kingdom
  /plugin marketplace add chatthong/kingdom
  /plugin install kingdom@kingdom
  ```
  Any of your scripts, aliases, or notes referencing `/kingdom-doctor` (etc.) need to become `/kingdom:doctor`.
- **GitHub auto-redirect** — `github.com/chatthong/claude-kingdom` still resolves to the new location, so old clones can `git remote set-url origin https://github.com/chatthong/kingdom.git` to keep working.
- **No functional changes** — every command does exactly what it did in v0.3.0. Pure rename.

---

## [0.3.0] — 2026-05-17

The "audit safety net" release. Adds a forced sweep command + extends watchman with scoped write authority for idle-time docs cleanup. Also adds `marketplace.json` so the repo is installable directly via `/plugin marketplace add chatthong/kingdom`.

### Added

- **`.claude-plugin/marketplace.json`** — makes this repo serve as its own single-plugin marketplace. Install flow is now `/plugin marketplace add chatthong/kingdom` followed by `/plugin install kingdom@kingdom`. (Local-path install — `/plugin install /path/to/repo` — still works for development.)
- **`/kingdom:update`** — new slash command that forces a docs/log/task audit pass on one project. Spawns a Sonnet sub-agent that re-reads every task file in `.kingdom/<project>/tasks/`, cross-checks each checkbox against `git log`, backfills orphan raw artifacts (raw with no curated digest), repairs missing `master_agent.log` summary lines, and flags higher-risk items (stale digests, merge candidates, archive candidates, suspect entries) for King review. Idempotent; current project only.
- **Watchman docs audit duty** — new section in `watchmans.md` granting watchman scoped write authority on its own project's `tasks/`+`logs/` for low-risk fixes during idle `/loop` time (stale checkboxes, missing log lines, dead `[[name]]` links). Higher-risk findings (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md` for King review.
- **`WATCH_DOCS_AUDIT.md`** — new single-file-per-project rolling artifact at `<workspace>/.kingdom/<project>/logs/WATCH_DOCS_AUDIT.md`. Watchman appends findings; King reviews + clears bullets after acting.
- **"Reviewing watchman audit findings" section** in `kings.md` — documents how/when King consumes `WATCH_DOCS_AUDIT.md` and what to do with each finding category.
- **`/kingdom:doctor` Check 8** — informational scan for orphan raw artifacts (raw with no curated digest). Suggests `/kingdom:update` when found.
- **README FAQ entries** — `/kingdom:update` purpose + watchman write-authority scope.

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
- **Auto-detect outer host mode** — `/kingdom:start` and `/kingdom:doctor` now auto-detect PRIMARY (manaflow/cmux.app) vs FALLBACK (raw tmux) vs HEADLESS (`claude -p`). No user config needed; King adapts to what's installed.
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
- **README rewritten** — replaced the "What a session looks like" transcript with role intros ("Meet the King — and the masters that work for it"). Expanded `/kingdom:new` documentation to a 5-use-case block (mid-size, large, solo, UI-heavy, unattended) with concrete `workers=N co-workers=M watchman=K` examples. Added FAQ entry for task files.
- **All worker / co-worker slug examples** swapped from `sonnet-worker-1` to `opus-worker-1` to match the new model defaults. Watchman slugs remain `sonnet-watchman-1`.
- **kingdom.json.template** — each `workers[i]` and `coworkers[i]` entry now has explicit `"model": "opus"`; each `watchmen[i]` entry has `"model": "sonnet"`. `_comment` documents the convention.

### Removed

- **craigsc/cmux dependency** — kingdom no longer requires the worktree-CLI wrapper. Worktree management now uses plain `git worktree add/remove` (built into git ≥ 2.5). One less install step; no PATH collision risk.
- **"What a session looks like" transcript** in README — replaced with the role intro section (see Changed).
- **Common shapes table** in README's `/kingdom:new` section — replaced with 5 per-use-case blocks (each its own emoji + heading + code block) for cleaner rendering at narrow widths.
- **AGENTS.md mirror pattern** — never used in v0.x; kit is Claude-only. Documented retirement in role files.

### Fixed

- Stale `templates/role-files/` and `templates/kingdom.json.template` path references in slash commands and README after the layout restructure.
- Inconsistent model labels across role docs (some still said "Sonnet" for lane masters after the Opus default was set).
- README's branch-model ASCII diagram had wrapping issues at narrow viewports → replaced with side-by-side Mermaid subgraphs.

### Compatibility notes

- **Breaking** for anyone who installed v0.1.x and customised paths under `templates/role-files/` — those moved to `.kingdom/.setting/`. Re-run `/kingdom:init` after upgrading to pick up the new layout.
- **Non-breaking** for anyone who used v0.1's `kingdom.json` — schema is additive (new optional fields, defaults kept compatible).
- **Behaviour change**: Worker / Co-worker lanes now spawn Opus by default. Cost-per-lane increases. Override in `kingdom.json.workers[i].model` if you want Sonnet for cost reasons (Sonnet is still valid for these roles; just no longer the default).

---

## [0.1.0] — 2026-05-16

Initial public release.

### Added

- 4 slash commands: `/kingdom:doctor`, `/kingdom:init`, `/kingdom:new`, `/kingdom:start`.
- 6 role docs in `templates/role-files/`: `index.md`, `kings.md`, `workers.md`, `co-workers.md`, `watchmans.md`, `git.md`.
- `kingdom.json.template` config template.
- `CMUX-Guide.md` (manaflow/cmux reference).
- `TMUX-Guide.md` (tmux 101 for the fallback path).
- README with install + usage + role overview.
- LICENSE (MIT).
