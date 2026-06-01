# update-report

**Fires when:** `/kingdom:update` Step 6 (migration complete).
**Used by:** [`commands/update.md`](../../../commands/update.md) Step 6.

## Template

```markdown
> [!IMPORTANT]
> ```
> ╭─ ⬆️  Kingdom updated · ${CUR_VERSION} → ${NEW_VERSION} ──────────╮
> │  Kit re-synced:   .kingdom/.setting/  (${N_KIT_FILES} files)    │
> │    backup:        ${KIT_BAK}                            │
> │  Configs merged:  ${N_PROJECTS} project(s) — new schema keys    │
> │                   added, your values kept (.bak each)   │
> │                                                         │
> │  Preserved untouched:                                   │
> │    • tasks/ · logs/ · state.json · king-inbox           │
> │    • ~/.claude/.../memory/  (outside the workspace)     │
> │                                                         │
> │  Next:                                                  │
> │    1. /kingdom:self-care   → verify the migrated kit    │
> │    2. /kingdom:work <project>  → resume; in-flight      │
> │       tasks + resume queue (R33) are exactly as left    │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${CUR_VERSION}` | `.kingdom/.setting/.kingdom-version` before update (or "unknown") | `0.34.0` |
| `${NEW_VERSION}` | installed plugin's `plugin.json` version | `0.38.0` |
| `${N_KIT_FILES}` | file count under the freshly-synced `.setting/` | `184` |
| `${N_PROJECTS}` | number of `kingdom.json` files migrated | `1` |
| `${KIT_BAK}` | basename of the `.setting.bak-<ts>` backup dir | `.setting.bak-20260601-143012` |

## Notes

- `[!IMPORTANT]` (purple) — same weight as `scaffold-success`: a structural change the user should register, not a routine status line.
- The "Preserved untouched" block is the point of the whole command — keep it prominent. The memory line reassures the user their accumulated facts/feedback survive a plugin update.
- If the user scoped the update to one project (`/kingdom:update <project>`), `${N_PROJECTS}` is 1 and the kit is still re-synced workspace-wide.
