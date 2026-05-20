# doctor-report

**Fires when:** `/kingdom:self-care` completes its prerequisite-check sweep.
**Used by:** [`commands/self-care.md`](../../../commands/self-care.md) final step.

## Template

The card has 3 variants based on overall result: all-pass, partial-pass (some auto-patched), fail.

### All checks pass

```markdown
> [!TIP]
> ```
> ╭─ ✅ Kingdom doctor · all checks pass ──────────────────╮
> │  Environment: ${OS_VERSION} · ${SHELL}                  │
> │                                                         │
> │  ✓ cmux.app          ${CMUX_VERSION}                    │
> │  ✓ tmux              ${TMUX_VERSION}                    │
> │  ✓ jq                ${JQ_VERSION}                      │
> │  ✓ gh                ${GH_VERSION}                      │
> │  ✓ git               ${GIT_VERSION}                     │
> │  ✓ user settings.json                                   │
> │  ✓ workspace settings.json                              │
> │  ✓ tasks/ writable                                      │
> │  ✓ no orphan audit artifacts                            │
> │  ✓ workspace .kingdom/.setting/ in sync                  │
> │  ✓ git state across ${N_PROJECTS} projects              │
> │                                                         │
> │  Ready to run /kingdom:work <project>.                  │
> ╰────────────────────────────────────────────────────────╯
> ```
```

### Partial pass (auto-patches applied)

```markdown
> [!IMPORTANT]
> ```
> ╭─ ⚙ Kingdom doctor · ${N_PATCHED} auto-patches applied ─╮
> │  Environment: ${OS_VERSION} · ${SHELL}                  │
> │                                                         │
> │  ${CHECK_RESULTS_LIST}                                  │
> │                                                         │
> │  Patched:                                               │
> │    ${PATCHED_LIST}                                      │
> │                                                         │
> │  All checks now passing. Run /kingdom:work to start.    │
> ╰────────────────────────────────────────────────────────╯
> ```
```

### Failed (manual action required)

```markdown
> [!CAUTION]
> ```
> ╭─ ❌ Kingdom doctor · ${N_FAILED} check${PLURAL} failed ─╮
> │  Environment: ${OS_VERSION} · ${SHELL}                  │
> │                                                         │
> │  ${CHECK_RESULTS_LIST}                                  │
> │                                                         │
> │  Action required:                                       │
> │    ${ACTION_LIST}                                       │
> │                                                         │
> │  Re-run /kingdom:self-care after fixing.                │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${OS_VERSION}` | `sw_vers -productVersion` (macOS) / `uname -sr` (Linux) | `macOS 15.4` |
| `${SHELL}` | `$SHELL` basename | `zsh` |
| `${CMUX_VERSION}` | `cmux --version` | `v0.64.6` |
| `${TMUX_VERSION}` | `tmux -V` | `tmux 3.4` |
| `${JQ_VERSION}` | `jq --version` | `jq-1.7.1` |
| `${GH_VERSION}` | `gh --version` first line | `gh version 2.92.0` |
| `${GIT_VERSION}` | `git --version` | `git version 2.45.0` |
| `${N_PROJECTS}` | count of `.kingdom/*/` subdirs | `3` |
| `${N_PATCHED}` / `${N_FAILED}` | counts | `2` / `1` |
| `${CHECK_RESULTS_LIST}` | each line: `✓` or `✗` or `⚙` (patched) + check name + version/note | (multi-line) |
| `${PATCHED_LIST}` | patched item + diff summary, one per line | (multi-line) |
| `${ACTION_LIST}` | what user needs to do, one per failed check | (multi-line) |
| `${PLURAL}` | `s` if `${N_FAILED}` != 1, empty if 1 | `s` |

## Notes

- 9 standard checks (per [`commands/self-care.md`](../../../commands/self-care.md)). Card shows all 9 in `${CHECK_RESULTS_LIST}` regardless of variant.
- Auto-patch happens for `.claude/settings.json` permission entries (Check 6) and for missing `.kingdom/.setting/` files imported from the plugin source (Check 9, v0.30.0+). Binary installs always require user action — the card lists the exact `brew install` or download URL.
