# watchman-digest

**Fires when:** once per local day, the watchman renders a fleet-health digest to the user (U9, v0.44.0). It is the watchman's single human-facing "here's the day" summary — distinct from the per-tick `watchman-tick` card (which is for the King).
**Used by:** [`watchman.md`](../roles/watchman.md) → Duty: Daily digest.

## Template

```markdown
> [!${DIGEST_FLAVOUR}]
> ```
> ╭─ 🕵️ Daily digest · ${PROJECT} · ${DIGEST_DATE} ───────╮
> │  Lanes:    ${LANE_HEALTH}                               │
> │  PRs:      ${PR_SUMMARY}                                 │
> │  Develop:  ${DEVELOP_HEALTH}                             │
> │  Inbox:    ${PENDING_QUESTIONS}                          │
> │  Doc drift:${DOC_DRIFT}                                  │
> │                                                         │
> │  👑 King's attention: ${TOP_ACTION}                     │
> │  Full: ${REPORTS_PATH}/WATCH_TICK_${TICK_UTC}.md        │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${DIGEST_FLAVOUR}` | `CAUTION` if any tracked item is severity=urgent (develop RED, stale-lane disconnect, urgent finding); else `NOTE` | `NOTE` |
| `${PROJECT}` | active project | `my-app` |
| `${DIGEST_DATE}` | local date the digest covers | `2026-06-10` |
| `${LANE_HEALTH}` | one-line lane roll-up (alive / idle / blocked / disconnected) | `4 alive, 1 idle, 0 blocked, 1 ⚠ disconnected` |
| `${PR_SUMMARY}` | open / merged-today / red-CI counts | `3 open (2 green, 1 red), 2 merged today` |
| `${DEVELOP_HEALTH}` | develop smoke trend over the day | `green (12 ticks), 1 flaky retry` |
| `${PENDING_QUESTIONS}` | count of `needs-reply` items in king inbox + oldest age | `2 pending (oldest 3 ticks)` |
| `${DOC_DRIFT}` | count of Gap A/B doc-drift flags in `WATCH_DOCS_AUDIT.md` | `1 Gap-A` |
| `${TOP_ACTION}` | the single highest-priority open item for the King (same line as the per-tick "King's next action") | `answer worker-2's auth question (waited 3 ticks)` |
| `${REPORTS_PATH}` | `$LOGS/watch` | `.kingdom/my-app/logs/watch` |
| `${TICK_UTC}` | the tick that produced the digest | `2026-06-10T1800Z` |

## Notes

- Fires **once per local day** — gate on a `last_digest_date` marker in `watchman_state.json` (write today's date after rendering; skip if it already matches). This respects the R40 Haiku cap + change-gating: the digest is a roll-up of already-computed tick state, it spawns no extra Haiku.
- The digest reads from existing state (`watchman_state.json`, the day's `WATCH_*` reports, `inbox_pending_count --to king`) — it does NOT re-run any duty.
- All values are integers / short phrases; never paste raw diffs. Keep it one screen. No ANSI.
