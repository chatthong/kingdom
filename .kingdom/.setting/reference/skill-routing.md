# skill-routing.md — Per-task skill picking (v0.23.0+)

When King dispatches a task to a lane, the dispatch-brief carries a `## Suggested skills` block listing 0-3 Claude Code skills the lane should invoke for this specific task. **Skills are per-task, not per-lane-lifetime.** Worker-2 doing a Supabase task today gets `supabase:supabase`; the same worker-2 doing a shadcn task tomorrow gets `shadcn:shadcn-ui`. Previous-task skills don't persist.

This file is the canonical **keyword → skill** mapping table that `pick_skills_for_task` (helper in [`functions/index.md`](../functions/index.md)) reads on every dispatch.

## How the matcher works

For each task, `pick_skills_for_task`:

1. Reads the task's Story heading + acceptance criteria + reference files (linked specs/PRs).
2. Lowercases the combined text.
3. For each row in the mapping table below, checks if ANY of that row's keywords appear (whole-word match, case-insensitive).
4. Collects matching skills, dedupes, sorts by **priority** (P1 first), keeps top 3.
5. Returns the list to King; King writes it into the dispatch-brief.

Skills are listed by their exact `Skill` invocation name (the lane calls `Skill <name>` to load it). If the named skill isn't installed in the lane's environment, the lane silently falls through — no error.

## Mapping table

| Priority | Skill name | Keywords (any whole-word match triggers) |
|---|---|---|
| P1 | `superpowers:brainstorming` | `brainstorm`, `explore options`, `design something new`, `before implementation` |
| P1 | `superpowers:writing-plans` | `multi-step`, `implementation plan`, `spec`, `breakdown` |
| P1 | `superpowers:test-driven-development` | `tdd`, `test-driven`, `red-green`, `write tests first` |
| P1 | `superpowers:systematic-debugging` | `bug`, `regression`, `crash`, `unexpected behaviour`, `test failure` |
| P1 | `superpowers:verification-before-completion` | `verify`, `before claiming done`, `acceptance criteria` |
| P1 | `nextjs-best-practices` | `next.js`, `nextjs`, `app router`, `server component`, `route handler`, `middleware.ts` |
| P1 | `shadcn-ui` | `shadcn`, `shadcn/ui`, `components.json`, `cn(`, `clsx` |
| P1 | `shadcn` | `shadcn init`, `--preset`, `add component`, `component registry` |
| P1 | `tailwind-design-system` | `tailwind`, `design tokens`, `design system`, `component library`, `responsive` |
| P1 | `oklch-skill` | `oklch`, `palette`, `contrast ratio`, `gamut`, `hue`, `chroma`, `dark mode colors` |
| P1 | `frontend-design:frontend-design` | `landing page`, `dashboard`, `marketing page`, `polish ui`, `production-grade frontend` |
| P1 | `supabase:supabase` | `supabase`, `supabase-js`, `@supabase/ssr`, `rls`, `pg_graphql`, `pg_cron`, `pg_vector` |
| P1 | `supabase:supabase-postgres-best-practices` | `postgres`, `psql`, `query plan`, `index`, `vacuum`, `analyze`, `partition` |
| P1 | `stripe:stripe-best-practices` | `stripe`, `payment intent`, `checkout`, `subscription`, `webhook signature`, `stripe connect` |
| P1 | `stripe:explain-error` | `stripe error`, `decline_code`, `card_declined`, `requires_action` |
| P1 | `claude-api` | `anthropic sdk`, `claude api`, `prompt caching`, `cache_control`, `tool use api` |
| P1 | `prisma-cli` | `prisma init`, `prisma generate`, `prisma migrate`, `prisma db`, `prisma studio`, `prisma mcp` |
| P1 | `prisma-client-api` | `prisma query`, `findMany`, `findUnique`, `create`, `update`, `delete`, `$transaction` |
| P1 | `prisma-database-setup` | `connect to mysql`, `configure postgres`, `setup mongodb`, `sqlite setup` |
| P1 | `prisma-postgres` | `prisma postgres`, `create-db`, `create-pg`, `create-postgres`, `prisma console`, `management api` |
| P1 | `prisma-postgres-setup` | `set up a database`, `provision a database`, `prisma postgres project`, `connection string` |
| P1 | `prisma-upgrade-v7` | `prisma 7`, `prisma v7`, `upgrade to prisma 7`, `prisma-client generator`, `driver adapter required` |
| P1 | `prisma-driver-adapter-implementation` | `driver adapter`, `SqlDriverAdapter`, `prisma v7 adapter`, `database driver` |
| P1 | `superpowers:executing-plans` | `execute plan`, `implementation plan to execute`, `review checkpoint` |
| P1 | `superpowers:subagent-driven-development` | `subagent`, `parallel implementation`, `delegated subagent work` |
| P1 | `superpowers:dispatching-parallel-agents` | `parallel agents`, `independent tasks`, `concurrent fan-out` |
| P1 | `superpowers:using-git-worktrees` | `git worktree`, `isolated workspace`, `feature isolation` |
| P1 | `superpowers:finishing-a-development-branch` | `finish branch`, `merge or pr`, `branch completion` |
| P1 | `superpowers:requesting-code-review` | `request review`, `code review request`, `before merging` |
| P1 | `superpowers:receiving-code-review` | `received feedback`, `respond to review`, `unclear feedback` |
| P1 | `superpowers:writing-skills` | `create skill`, `edit skill`, `verify skill`, `skill frontmatter` |
| P1 | `pdf` | `.pdf`, `extract from pdf`, `merge pdf`, `pdf form`, `ocr` |
| P1 | `xlsx` | `.xlsx`, `.csv`, `.tsv`, `spreadsheet`, `excel`, `pivot table` |
| P1 | `pptx` | `.pptx`, `slide deck`, `pitch deck`, `presentation` |
| P1 | `docx` | `.docx`, `word doc`, `letterhead`, `report template` |
| P1 | `lark-doc` | `lark`, `feishu`, `docx wiki`, `bytedance doc` |
| P2 | `figma:figma-implement-design` | `figma url`, `figma file`, `figma component`, `1:1 visual fidelity` |
| P2 | `figma:figma-code-connect` | `code connect`, `.figma.ts`, `.figma.js`, `figma component mapping` |
| P2 | `figma:figma-generate-design` | `write to figma`, `create in figma`, `push page to figma`, `build screen in figma` |
| P2 | `huggingface-skills:hf-cli` | `hugging face hub`, `huggingface`, `hf-cli`, `model card`, `dataset card` |
| P2 | `huggingface-skills:transformers-js` | `transformers.js`, `client-side ml`, `webgpu`, `onnx in browser` |
| P2 | `plugin-dev:create-plugin` | `claude code plugin`, `plugin.json`, `${CLAUDE_PLUGIN_ROOT}`, `marketplace.json` |
| P2 | `plugin-dev:skill-development` | `claude code skill`, `skill frontmatter`, `progressive disclosure` |
| P2 | `plugin-dev:agent-development` | `claude code agent`, `subagent`, `agent frontmatter` |
| P2 | `plugin-dev:hook-development` | `claude code hook`, `pretooluse`, `posttooluse`, `sessionstart hook` |
| P2 | `plugin-dev:mcp-integration` | `mcp server`, `.mcp.json`, `model context protocol` |
| P2 | `claude-md-management:claude-md-improver` | `claude.md`, `project memory`, `claude.md audit` |
| P2 | `commit-commands:commit-push-pr` | `commit + push`, `open pr`, `gh pr create` |
| P2 | `code-review:code-review` | `code review`, `review pr`, `review changes` |
| P2 | `pr-review-toolkit:review-pr` | `pr review`, `comprehensive review`, `multi-agent review` |
| P2 | `security-review` | `security review`, `vulnerability`, `injection`, `xss`, `csrf`, `auth bypass` |
| P3 | `superpowers:using-git-worktrees` | `worktree`, `git worktree`, `isolated workspace` |
| P3 | `doc-coauthoring` | `write documentation`, `tech spec`, `decision doc`, `adr` |
| P3 | `playground:playground` | `interactive html`, `single-file explorer`, `playground` |

## Priority semantics

| Tier | Meaning | Picked when |
|---|---|---|
| **P1** | High-signal: skill changes the approach meaningfully (Next.js routing patterns, Stripe webhook handling, OKLCH gamut) | Always included if keyword matches |
| **P2** | Medium-signal: helpful but task may complete without it (Figma → code, plugin development, code review) | Included if top-3 slot remains |
| **P3** | Process / supporting: useful guard-rail but not core (worktree setup, doc-coauthoring scaffold) | Last-resort fill if slot remains |

Cap at **3 skills per dispatch-brief**. More than 3 dilutes the signal; the lane stops invoking past the first few.

## Override surface

The user can override the auto-pick on a per-dispatch basis:

```text
worker-2: skill=figma:figma-implement-design pick BE-P0-AUTH.2
```

When King sees `skill=<name>[,<name>...]` in the user's instruction, it short-circuits `pick_skills_for_task` and uses the user-provided list verbatim. Multiple skills comma-separated. `skill=none` explicitly clears the list (no skills suggested for this dispatch).

## Customising the table

Edit `<workspace>/.kingdom/.setting/reference/skill-routing.md` (the workspace copy, not the plugin source) to add project-specific mappings. The matcher reads the workspace copy at every dispatch, so changes are picked up on the next task without restarting the King.

Common additions for specific projects:

- **Vue/Nuxt project:** add `vue`, `nuxt`, `composition api` keywords pointing to your Vue skill of choice.
- **Rust project:** add `cargo`, `rustc`, `clippy` keywords (no canonical Rust skill in the default registry, so you may want to write one and add it here).
- **Internal DSL:** add your DSL's reserved words pointing to an internal skill you've installed.

## Notes

- The matcher is whole-word, case-insensitive. `nextjs` matches `Next.js`, `NEXTJS`, but NOT `Nextjs2` (different word).
- Keyword phrases (multi-word) match if the full phrase appears with single-space normalisation.
- Skills with namespace prefix (`supabase:supabase`, `stripe:stripe-best-practices`) are global skills; skills without prefix (`nextjs-best-practices`) are session-level. Both invocation forms supported.
- If multiple rows match the same skill (e.g. `supabase:supabase` triggered by both `supabase` and `RLS`), it's de-duplicated to one entry in the brief.

## Auto-discovery fallback (v0.29.3+, per rules.md R41)

If `pick_skills_for_task` returns 0 matches from the table above, the actor (King OR lane) MUST:

1. **List available skills** in the current environment. Skills surface in system reminders at session start (or after marketplace install) as a list with each skill's `name` + `description`. The actor reads this list, NOT just the routing table.

2. **Match by domain keywords in skill descriptions**. The routing table is the canonical fast-path; the system-reminder skill list is the fallback for skills not yet in the table (newly installed, project-specific marketplaces, etc).

3. **Invoke `Skill <name>` for the best match** if confidence is high. If multiple skills could fit, pick the most specific one (e.g. `prisma-postgres-setup` over generic `prisma-cli` when the task is "set up a new Prisma Postgres project").

4. **Skip invocation if no skill fits** rather than picking a vaguely-related one. False-positive skill loads waste context.

**The table is fast lookup; the system-reminder list is the source of truth.** When a new skill family ships (e.g. when `prisma:*` family expanded in v0.29.3), add a row here for fast-path matching, but the auto-discovery fallback already handles it before the table catches up.

**For Kings (orchestration roles):** the planning-side superpowers skills are routinely useful — `superpowers:brainstorming` before designing a new feature, `superpowers:writing-plans` when multi-step work needs structure, `superpowers:dispatching-parallel-agents` when independent work fans out, `superpowers:verification-before-completion` before claiming a task done. King invokes these directly, not via dispatch-brief.

**For lanes (workers):** domain-specific skills land via the dispatch-brief's `${SUGGESTED_SKILLS}` block (per R23). Lane also has authority to invoke additional skills it discovers are relevant mid-task (e.g. mid-implementation realisation that the task needs `prisma-upgrade-v7` — invoke directly, log to task file's Progress notes).
