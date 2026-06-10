### R41. Auto-discover and use the right skill BEFORE any work — Tier 2 (v0.29.3+)

At the START of any task — King's daily ritual kickoff AND every lane's task receipt — the actor MUST resolve a skill set before writing code, designing, or dispatching:

**Resolution order:**

1. **Fast path: routing table.** Run `pick_skills_for_task` against [`skill-routing.md`](../reference/skill-routing.md). If it returns 1-3 matches, use them.
2. **Fallback: system-reminder skill list.** If routing table returns 0 matches, list the skills surfaced in the current session's system reminders (or `Skill` tool catalog), match by description-keyword similarity to the task domain, pick best fit.
3. **No-skill is valid.** If neither path produces a confident match, skip — don't invoke a vaguely-related skill just to invoke something. False-positive loads pollute context.

**Domain → skill quick map (most-used):**

| Task domain | Skills to invoke (priority order) |
|---|---|
| Frontend / Next.js / UI | `nextjs-best-practices`, `shadcn`, `shadcn-ui`, `tailwind-design-system`, `frontend-design`, `oklch-skill` |
| Database / Prisma | `prisma-cli`, `prisma-client-api`, `prisma-database-setup`, `prisma-postgres`, `prisma-postgres-setup`, `prisma-upgrade-v7`, `prisma-driver-adapter-implementation` |
| Supabase / Postgres | `supabase:supabase`, `supabase:supabase-postgres-best-practices` |
| Stripe / Payments | `stripe:stripe-best-practices`, `stripe:explain-error` |
| Figma / Design import | `figma:figma-implement-design`, `figma:figma-code-connect`, `figma:figma-generate-design` |
| Plugin / Skill dev | `plugin-dev:create-plugin`, `plugin-dev:skill-development`, `plugin-dev:agent-development`, `plugin-dev:hook-development`, `plugin-dev:mcp-integration`, `plugin-dev:command-development`, `superpowers:writing-skills` |
| File / Doc formats | `pdf`, `xlsx`, `pptx`, `docx`, `lark-doc` |
| Anthropic SDK / Claude API | `claude-api` |
| Hugging Face | `huggingface-skills:*` family |
| Security review | `security-review` |
| Code review | `code-review:code-review`, `pr-review-toolkit:review-pr`, `superpowers:requesting-code-review`, `superpowers:receiving-code-review` |
| Git workflow | `commit-commands:commit-push-pr`, `commit-commands:commit`, `superpowers:using-git-worktrees`, `superpowers:finishing-a-development-branch` |

**Process skills (King uses these directly, not via dispatch-brief):**

- `superpowers:brainstorming` — BEFORE any creative work (designing a new feature, deciding shape of something not yet built).
- `superpowers:writing-plans` — when multi-step work needs explicit structure before execution.
- `superpowers:executing-plans` — when running a pre-written plan with review checkpoints.
- `superpowers:test-driven-development` — when implementing a feature with tests-first discipline.
- `superpowers:systematic-debugging` — when a bug, regression, or unexpected behaviour appears; BEFORE proposing fixes.
- `superpowers:verification-before-completion` — BEFORE claiming work is done, fixed, or passing; requires running verification commands and confirming output.
- `superpowers:dispatching-parallel-agents` — when facing 2+ independent tasks that can fan out without shared state.
- `superpowers:subagent-driven-development` — when executing a plan via sub-agent fan-out in the current session.
- `superpowers:using-git-worktrees` — when starting feature work that needs worktree isolation.
- `superpowers:finishing-a-development-branch` — when implementation is complete and integration decision is needed.

**Anti-patterns banned:**

- Starting code edits without checking the skill catalog first.
- Invoking 5+ skills "just in case" (cap is 3 per dispatch-brief; King's own planning can invoke up to 2 process skills + 1 domain skill).
- Skipping `superpowers:verification-before-completion` before claiming a task done — R22 closer relies on verification being real.

**For lanes:** dispatch-brief's `${SUGGESTED_SKILLS}` block (rendered by `pick_skills_for_task` per R23) covers the domain skills. Lane may invoke ADDITIONAL skills mid-task if relevant (log the additional invocation to the task file's `## Progress notes`).

**Why Tier 2:** skills exist to encode best practice; ignoring them means re-deriving patterns the community already solved. Cost of one extra `Skill` invocation (~1-2k tokens) is negligible vs cost of a wrong-pattern implementation that gets reviewed-then-rewritten — a strong default, but skipping it produces worse output, not corrupted state, so it's Tier 2 per the v0.31.0 Tier-1-cap legend.
