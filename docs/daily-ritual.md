# 🔁 Daily ritual

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
/kingdom:day my-app                        # the one command, every morning
/kingdom:day my-app cap=5                  # cap today's task-completions at 5
/kingdom:day my-app target=30-50/week      # soft weekly budget; auto-splits to daily/monthly
```

Monday morning. One command. Kingdom runs `/kingdom:update` (refresh project state), spawns the lanes (idempotent, resumes if already running), prints a kickoff brief with your local date+time and a Suggested next task synthesised from in-flight work + open PRs + the project task-ledger, then enters the auto-gate-poll loop. King only stops to ask for **review approval** (Tier-2 passed, please check the live diff) and **push approval** (per PR, single-shot per [rules.md R1](../.kingdom/.setting/rules.md#r1-push-approval-is-single-shot--pr-specific)).

Tuesday morning. Same command. The audit re-runs (cheap, parallel fan-out). The kickoff brief reflects yesterday's progress against your target. Nothing to remember.

End of day: `/kingdom:exit my-app` closes lanes gracefully; your conversation stays alive.

That's the whole routine. **It replaces the daily overhead of "what was I doing", "did anyone push", "is develop green", "is PR #234 reviewed".** The King knows. Watchman knows. Ask the King.

## `target=` and `cap=` argument surface

`target=N-M/<period>` is a soft budget; King paces dispatch to hit the daily band. Auto-splits across timeframes (assumes 5 working days per week, 4 weeks per month):

| You pass | Daily view | Weekly view | Monthly view |
|---|---|---|---|
| `target=30-50/week` | ~6-10/day | 30-50/week | ~120-200/month |
| `target=5-10/day` | 5-10/day | ~25-50/week | ~100-200/month |
| `target=120-200/month` | ~6-10/day | ~30-50/week | 120-200/month |

`cap=N` is a hard daily ceiling. King stops dispatching after `N` task-completions today; idle lanes wait. Overrides `target` for the day.

Parsing is forgiving and echoed back before the loop fires, so you can correct typos.

## Standalone building-block commands (power users)

Most don't need these. Both are invoked automatically by `/kingdom:day`. Reach for them only when you want the standalone phase:

- [`/kingdom:update my-app`](../commands/update.md): audit-only pass; useful mid-day after watchman flags fresh findings.
- [`/kingdom:start my-app`](../commands/start.md): spawn lanes only, no audit, no poll loop; useful for resume-after-crash.

## Updating the plugin

Two layers, different routines:

```bash
/plugin update kingdom    # 1. pull new plugin code (slash commands + templates)
/kingdom:doctor           # 2. (optional) check for new env requirements
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
