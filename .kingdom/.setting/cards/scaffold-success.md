# scaffold-success

**Fires when:** `/kingdom:init <project>` Step 5 (project-mode completion).
**Used by:** [`commands/init.md`](../../../commands/init.md) Step 5.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ 🎉 Kingdom scaffolded · ${PROJECT} ───────────────────╮
> │  Files created:                                         │
> │    .kingdom/.setting/  (${N_ROLE_DOCS} role docs + cards/)
> │    .kingdom/${PROJECT}/kingdom.json                     │
> │    .kingdom/${PROJECT}/{tasks,logs}/                    │
> │    .claude/settings.json  (permissions patched)         │
> │                                                         │
> │  Shape: kingdom.json defaults (tune at /kingdom:work)   │
> │                                                         │
> │  Next:                                                  │
> │    1. Edit .kingdom/${PROJECT}/kingdom.json → gate.*    │
> │       (and git.base if your repo isn't 'develop')       │
> │    2. Run /kingdom:self-care to verify deps             │
> │    3. Run /kingdom:work ${PROJECT} to start your day    │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | first positional arg | `bfg-swt` |
| `${N_ROLE_DOCS}` | count of `.md` files in `.kingdom/.setting/` excluding `cards/` | `8` |

`init` no longer takes shape flags (v0.33.0): the project is scaffolded with `kingdom.json` defaults. Shape is chosen per-session at `/kingdom:work` (`worker=N`, `lane=N`, `senior=N`, …) or by editing `kingdom.json`.

## Workspace-only variant

When `/kingdom:init` runs without a `project` arg (workspace-only mode), use this slimmer variant:

```markdown
> [!IMPORTANT]
> ```
> ╭─ 🎉 Workspace scaffolded ──────────────────────────────╮
> │  Files created:                                         │
> │    .kingdom/.setting/  (${N_ROLE_DOCS} role docs + cards/)
> │    .claude/settings.json  (permissions patched)         │
> │                                                         │
> │  Next: run /kingdom:init <project> to scaffold a        │
> │        kingdom.json for one of your projects.           │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Notes

- Card replaces the previous "Kingdom ready for `<project>`" plain-text block in `commands/init.md` Step 5.
- If the user opted out of the `.claude/settings.json` patch (Step 3 answered `N`), append a warning line: `⚠ Skipped settings.json patch — sub-agents may stall on permission prompts.`
