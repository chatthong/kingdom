# Card library (v0.22.0+)

Reusable display templates the kingdom prints to the user in chat. Commands and role docs reference these by path instead of inlining the box-drawn templates. Each card wraps a box-drawn body in a GitHub alert (`> [!NOTE]` / `[!TIP]` / `[!IMPORTANT]` / `[!WARNING]` / `[!CAUTION]`) so it renders with a coloured frame in Claude Code chat.

## Index

| Card | Alert flavour | Fires when |
|---|---|---|
| [`welcome.md`](welcome.md) | `[!TIP]` (varies) | `/kingdom:day` kickoff (varies by time of day) |
| [`daily-status.md`](daily-status.md) | `[!NOTE]` | `/kingdom:day` kickoff after audit |
| [`suggested-task.md`](suggested-task.md) | `[!NOTE]` | `/kingdom:day` kickoff: 1-3 candidates |
| [`dispatch-plan.md`](dispatch-plan.md) | `[!NOTE]` | `/kingdom:day` kickoff: lane assignments |
| [`task-complete.md`](task-complete.md) | `[!TIP]` | Tier-2 gate pass (random pool of 20 lines) |
| [`push-prompt.md`](push-prompt.md) | `[!IMPORTANT]` | Tier-2 pass, asking for "push" word |
| [`gate-fail.md`](gate-fail.md) | `[!CAUTION]` | Tier-1 or Tier-2 gate fails |
| [`end-of-day.md`](end-of-day.md) | `[!TIP]` | `/kingdom:exit` or cap/target hit |
| [`blocked-lane.md`](blocked-lane.md) | `[!WARNING]` | Watchman detects permission prompt |
| [`conflict-detected.md`](conflict-detected.md) | `[!WARNING]` | `git merge-tree` finds drift at push time |
| [`cap-reached.md`](cap-reached.md) | `[!WARNING]` | `cap=N` hit |
| [`pr-merged.md`](pr-merged.md) | `[!NOTE]` | `gh pr view` flips to `MERGED` (triggers R26) |
| [`scaffold-success.md`](scaffold-success.md) | `[!IMPORTANT]` | `/kingdom:init` completes |
| [`spawn-complete.md`](spawn-complete.md) | `[!IMPORTANT]` | `/kingdom:start` completes |
| [`watchman-alert.md`](watchman-alert.md) | varies | Watchman `cmux notify` (4 event variants) |
| [`dispatch-brief.md`](dispatch-brief.md) | (no alert; flow-text) | Internal: King → lane prompt template |
| [`audit-summary.md`](audit-summary.md) | `[!NOTE]` | `/kingdom:update` audit-pass completion |
| [`doctor-report.md`](doctor-report.md) | varies (TIP/IMPORTANT/CAUTION) | `/kingdom:doctor` check completion (3 variants) |

## Alert flavour → colour mapping

| Alert | Colour | Used for |
|---|---|---|
| `[!NOTE]` | blue | Informational cards (status, plan, suggestions, post-merge) |
| `[!TIP]` | green | Success / positive cards (task done, end of day, morning welcome) |
| `[!IMPORTANT]` | purple | High-attention cards (push prompts, scaffold/spawn confirmations) |
| `[!WARNING]` | amber | Recoverable issues (blocked lane, conflict, cap reached) |
| `[!CAUTION]` | red | Failures (gate fail) |

## Variable substitution

Each card defines its variables in a `## Variables` table. Helper `render_card` in [`../_primitives.md`](../_primitives.md) loads the template, substitutes `${VAR}` from the calling shell, then prints. Variables that resolve to empty string are dropped along with their line so cards don't render with hollow rows.

## Width

All user-facing cards target **58 chars internal width** (60 total with `│ │` borders). `dispatch-brief.md` is flow-text (no box). The width is chosen so cards stay readable in narrow terminal panes (split layouts, 80-col cmux defaults).

## Adding a new card

1. Create `<name>.md` in this directory.
2. Use the standard format: `# Card name`, `**Fires when:**` line, `**Used by:**` line, `## Template` (box-drawn body in a fenced block, wrapped in the appropriate alert), `## Variables` table, `## Variants` (if applicable).
3. Add a row to the Index table above.
4. Reference from the calling command/role doc by path.

## Custom branding

You can override any card by editing the copy in your workspace at `.kingdom/.setting/cards/<name>.md` after `/kingdom:init`. The plugin's copy of `cards/` is the template source; your workspace copy is what the King actually reads at session start.
