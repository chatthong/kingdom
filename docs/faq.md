# ❓ FAQ

> Part of the [kingdom](../README.md) docs.

<details>
<summary><strong>Does this require Opus?</strong></summary>

Yes for the King, Workers, and Co-workers. Watchmen are Sonnet (P1) by default. Sub-agents use Sonnet (P1) / Haiku (P2) / Opus (P3), lane masters choose based on task weight.

</details>

<details>
<summary><strong>Does this work on Linux?</strong></summary>

The "primary" path (cmux.app) is macOS-only. The "fallback" path uses raw tmux and works on Linux, git worktrees are built-in everywhere. Same artifact protocol on both paths; just the dispatch mechanism differs. See [`TMUX-Guide.md`](../TMUX-Guide.md).

</details>

<details>
<summary><strong>What if my project uses different commands?</strong></summary>

Edit `kingdom.json` → `gate.*` arrays per project. The King runs whatever you put there: `cargo check`, `pytest`, `mvn verify`, anything.

</details>

<details>
<summary><strong>How does the King pick which skills to invoke?</strong></summary>

R41 (v0.29.3+) made skill-aware execution mandatory. Resolution is three steps: (1) the King calls `pick_skills_for_task` against the keyword → skill mapping table in [`.kingdom/.setting/reference/skill-routing.md`](../.kingdom/.setting/reference/skill-routing.md) — domain skills (Next.js, Prisma, Supabase, etc) are matched here; (2) if no routing match, the system-reminder skill list is scanned as a fallback; (3) if still no match, the task proceeds without a skill invocation — that's valid. Process skills (`superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`) are always evaluated independently of domain matching. To add project-specific keywords, edit `.kingdom/.setting/reference/skill-routing.md` — no restart needed. Full rule: [R41](../.kingdom/.setting/rules/R41-auto-discover-and-use.md).

</details>

<details>
<summary><strong>What happened to /kingdom:day?</strong></summary>

Renamed to `/kingdom:work` in v0.29.0 (hard break, no alias). All other commands also renamed: `/kingdom:doctor` → `/kingdom:self-care`, `/kingdom:exit` → `/kingdom:save` (simplified to state snapshot only — no commits or pushes). The building-block commands `/kingdom:start` and `/kingdom:update` were folded into `/kingdom:work`. (`/kingdom:update` was later reintroduced in v0.38.0 with a completely different meaning — workspace migration after a plugin update, not an audit sweep.)

</details>

<details>
<summary><strong>Can I have 7 workers?</strong></summary>

Yes. Set `kingdom.json` → `shape.workers = 7`. Soft cap is 10 lanes total (`sanityCap`); the workspace gets cramped past that. Override `sanityCap` in `kingdom.json` if you really want more.

</details>

<details>
<summary><strong>How is the git workflow configured?</strong></summary>

Via `kingdom.json` → `git`: `base` (the branch lanes fork from / PRs target, default `develop`), `integrationBranch` (the local working-tree overlay, default `kingdom`), `branchNamingPattern` (default `feature/<topic>`), and `pushPolicy` (default `always-ask` — the King never pushes without your explicit `push`, per R1). The King carves clean, byte-for-byte feature branches from each lane tip (R9); how a PR is finally merged (merge-commit vs squash) is your repo's / GitHub's setting, not the kingdom's.

</details>

<details>
<summary><strong>Can I commit <code>.kingdom/</code> to my workspace?</strong></summary>

`.kingdom/` is outside any project's git by design (workspace root is not a repo). If your workspace IS a repo, gitignore `.kingdom/<project>/logs/`, the config file (`.kingdom/<project>/kingdom.json`) is fine to commit and useful for onboarding new agents.

</details>

<details>
<summary><strong>What's a task file?</strong></summary>

Every assignment to a lane creates one at `.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`. It's a checkbox markdown doc with the multi-layer plan, progress notes, and final summary. Lane master writes; sub-agents and you can read it to follow along. Never deleted, never reused. Full schema in [`worker.md`](../.kingdom/.setting/roles/worker.md) → "Task file".

</details>

<details>
<summary><strong>What happens if a lane crashes?</strong></summary>

State persists in the worktree filesystem. Re-running `/kingdom:work <project>` detects existing worktrees and `cd`s into them (resume) instead of `git worktree add` (create). The 4-step closer's sentinel flag is the source of truth: if the flag is present, the lane finished; if not, dispatch a fix-task.

</details>

<details>
<summary><strong>Can I run this without manaflow/cmux?</strong></summary>

Yes. `/kingdom:work` auto-detects what's available. If cmux.app isn't running, it falls back to raw tmux automatically, no config change, no extra tools required.

</details>

<details>
<summary><strong>How do I update an existing workspace after the plugin updates? (What is /kingdom:update?)</strong></summary>

Run **`/kingdom:update`** (v0.38.0+) after `/plugin update kingdom`. It migrates a live workspace to the new plugin version without losing anything: it clean-replaces the kit (`.kingdom/.setting/`, backup → fresh), additively merges new schema keys into each `kingdom.json` (your tuned values always win), and **never touches** your `tasks/`, `logs/`, `state.json`, `king-inbox`, or memory. It previews the full delta and asks for an explicit `update` before any write; every write is backed up first. `/kingdom:self-care` (Check 12) flags when the kit is behind the installed plugin.

Use `/kingdom:init` for scaffolding a *new* workspace/project; use `/kingdom:update` for *upgrading* an existing one.

> Note: the name `/kingdom:update` was used pre-v0.29.0 for a different thing (an audit sweep, since folded into `/kingdom:work`). v0.38.0 reuses the name for the workspace-migration command described here.

</details>

<details>
<summary><strong>Does the watchman edit my files?</strong></summary>

Only audit artifacts under `.kingdom/<project>/{tasks,logs}/`, and only for **low-risk** fixes (tick a stale checkbox when a matching commit is found, backfill a missing log line, fix a dead `[[name]]` link). It NEVER edits project source code, role specs, `kingdom.json`, or `.git/`. **High-risk** changes (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md`, King decides + acts. Full split in [`watchman.md`](../.kingdom/.setting/roles/watchman.md) → "Docs audit duty".

</details>

## See also

- [`work-cycle.md`](work-cycle.md): how the everyday commands fit together
- [`configuration.md`](configuration.md): pick the right shape
- [`how-it-works.md`](how-it-works.md): mechanics behind the claims
