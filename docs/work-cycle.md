# 🔁 Work cycle

> Part of the [kingdom](../README.md) docs.

## First time (~90s, once per workspace)

```bash
mkdir -p ~/code/my-workspace && cd ~/code/my-workspace
claude
```

Then in the Claude session:

```bash
/kingdom:init my-app
```

Done. Edit `.kingdom/my-app/kingdom.json` once to fill in your `gate.*` commands (your project's typecheck/tests/etc, or any bash you want gated). Then never edit it again.

Detail on shape choices: [`configuration.md`](configuration.md).

## Every day, your Monday-morning ritual

```bash
/kingdom:work my-app                        # the one command, every morning
/kingdom:work my-app pr-limit=5             # stop after 5 PRs today
/kingdom:work my-app lane=8 pod-limit=3     # King composes 8 lanes; stop after 3 pods (stories)
```

Monday morning. One command. Kingdom runs an audit (refresh project state), spawns the lanes (idempotent, resumes if already running), prints a kickoff brief with your local date+time and a Suggested next task synthesised from in-flight work + open PRs + the project task-ledger, then enters the auto-gate-poll loop. King only stops to ask for **review approval** (Tier-2 passed, please check the live diff) and **push approval** (per PR, single-shot per [rules.md R1](../.kingdom/.setting/rules.md#r1-push-approval-is-single-shot--pr-specific)).

Tuesday morning. Same command. The audit re-runs (cheap, parallel fan-out). The kickoff brief reflects yesterday's progress against your limits. Nothing to remember.

End of session: `/kingdom:save my-app` snapshots state and closes lanes gracefully; your conversation stays alive.

That's the whole routine. **It replaces the daily overhead of "what was I doing", "did anyone push", "is develop green", "is PR #234 reviewed".** The King knows. Watchman knows. Ask the King.

## Skill-aware execution (R41, v0.29.3+)

Before dispatch, King + lanes resolve a skill set via `pick_skills_for_task` against [`.kingdom/.setting/skill-routing.md`](../.kingdom/.setting/skill-routing.md). Domain-routed: Next.js work invokes `nextjs-best-practices`, Prisma work invokes `prisma-cli`/`prisma-client-api`/etc, Supabase work invokes `supabase:supabase`. Process skills (`superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`) invoke directly when relevant. Per [R41](../.kingdom/.setting/rules.md#r41-auto-discover-and-use-the-right-skill-before-any-work-tier-1-v0293).

## `pr-limit` and `pod-limit` (v0.33.0)

Two independent hard ceilings; pass either or both. Dispatch stops when the first one is reached, and idle lanes wait.

| Param | Counts | Example |
|---|---|---|
| `pr-limit=N` | PRs opened today (a solo task or a whole story pod each = 1; a follow-up cleanup PR adds 1) | `pr-limit=5` → stop after 5 PRs |
| `pod-limit=N` | pods today (one unit of work: story / task / milestone / issue, regardless of how many workers or sub-tasks) | `pod-limit=3` → stop after 3 pods |

Neither counts sub-tasks, and neither counts milestones as a whole. A 3-worker pod that ships one story PR counts as **1** toward each. (`cap` and `target` from earlier versions are gone — `cap` became `pr-limit`; `target`'s soft-budget auto-split was removed in favour of these two plain ceilings.)

Parsing is forgiving and echoed back before the loop fires, so you can correct typos.

## Per-session shape overrides

`/kingdom:work` accepts per-session lane count overrides without touching `kingdom.json`:

```bash
/kingdom:work my-app worker=2              # run with 2 workers this session (json default stays 3)
/kingdom:work my-app co-worker=0           # no paired lanes today
/kingdom:work my-app watchman=2            # spin up a second watchman for heavy monitoring
```

These are **session-only** overrides. The next `/kingdom:work` reverts to `kingdom.json.shape` values.

## Saving state with `/kingdom:save`

```bash
/kingdom:save my-app
```

Writes current lane + task state to `.kingdom/my-app/state.json`, then closes lane workspaces. Does **not** commit or push — those go through the normal push-approval gate (R1). Use this at end-of-day or before a planned context switch.

Full detail: [`commands/save.md`](../commands/save.md).

## Updating the plugin

Two layers, different routines:

```bash
/plugin update kingdom    # 1. pull new plugin code (slash commands + templates)
/kingdom:self-care        # 2. (optional) check for new env requirements
/kingdom:init             # 3. (optional) re-sync workspace role docs from new templates
```

| Asset | Survives plugin update? |
|---|---|
| Slash commands | replaced by new version (immediate) |
| Role doc templates (in plugin) | replaced by new version |
| Workspace `.kingdom/.setting/*.md` | ✅ untouched; re-run `/kingdom:init` to sync |
| Your `kingdom.json` configs | ✅ untouched |
| `tasks/` + `logs/` audit trail | ✅ untouched (your work is safe) |
| `.claude/settings.json` permissions | ✅ untouched |

If a release changes the `kingdom.json` schema (e.g., v0.5.0 dropped `focus`+`ownsPaths`), the [CHANGELOG entry](../CHANGELOG.md) for that version tells you what to edit. Schema migrations are manual edits right now; a future `/kingdom:migrate` command may automate this.

## See also

- [`configuration.md`](configuration.md): pick the right shape for your project
- [`branch-model.md`](branch-model.md): what happens to git during the day
- [`faq.md`](faq.md): "What if a lane crashes?" + other common questions
