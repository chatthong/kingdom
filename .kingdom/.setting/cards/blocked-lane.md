# blocked-lane

**Fires when:** Watchman's `/loop` body detects a lane stuck on a permission prompt (per [watchmans.md § Blocked-lane scan](../watchmans.md#blocked-lane-scan)).
**Used by:** [`watchmans.md`](../watchmans.md) `/loop` body.

## Template

```markdown
> [!WARNING]
> ```
> ╭─ ⚠ Lane blocked · ${LANE} ─────────────────────────────╮
> │  Stuck on: ${PROMPT_KIND}                               │
> │            "${PROMPT_PREVIEW}"                          │
> │  Last activity: ${IDLE_DURATION} ago                    │
> │  Task: ${TASK_ID} · layer ${LAYER}                      │
> │                                                         │
> │  Click the ${LANE} workspace in the sidebar and         │
> │  approve (or deny) the prompt.                          │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${LANE}` | lane name from `capture-pane` source | `worker-1` |
| `${PROMPT_KIND}` | detected prompt category | `permission prompt` / `interactive y/N` / `auth login` / `Press Enter` |
| `${PROMPT_PREVIEW}` | first ~60 chars of the prompt text from capture-pane | `allow .git/ during this session?` |
| `${IDLE_DURATION}` | wall-clock since last pane state change | `14 min` |
| `${TASK_ID}` | lane's current task ID from its task file | `BE-P0-AUTH.2` |
| `${LAYER}` | lane's current layer (`L1` / `L2` / `L3` / `L4`) | `3/4` |

## Prompt pattern matchers

The watchman matches against capture-pane output using these regexes (full list in [watchmans.md](../watchmans.md)):

| Regex | Maps to `${PROMPT_KIND}` |
|---|---|
| `Do you want to proceed\?` | `permission prompt` |
| `Esc to cancel` | `permission prompt` |
| `\[y/N\]` | `interactive y/N` |
| `allow .* during this session` | `permission prompt` |
| `Press Enter` | `interactive Press Enter` |
| `gh auth login` | `auth login` |
| `Login Required` | `auth login` |

## Notes

- The card fires once per blocked detection (not every tick). Watchman tracks `blocked_lanes` in `watchman_state.json` to avoid spam.
- If the prompt is still there 30 min later, watchman re-fires the card with `${IDLE_DURATION}` updated (one re-fire only, then silent until state changes).
