# watchman-tick

**Fires when:** Watchman `/loop` tick completes its fan-out duty run and surfaces findings worth user attention.
**Used by:** [`watchman.md`](../roles/watchman.md) `/loop` body — rendered to King's chat after all Haiku sub-agents report back.

## Template

```markdown
> [!${TICK_FLAVOUR}]
> ```
> ╭─ 🕵️ Watchman tick · ${PROJECT} · ${TICK_UTC} ──────────╮
> │  Duties run: ${DUTIES_LIST}                             │
> │  Haiku sub-agents spawned: ${N_HAIKUS} (cap=${CAP})     │
> │                                                         │
> │  Findings:                                              │
> │  ${FINDINGS_LIST}                                       │
> │                                                         │
> │  Details: ${REPORTS_PATH}/WATCH_TICK_${TICK_UTC}.md     │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${TICK_FLAVOUR}` | `CAUTION` if any finding is severity=urgent; otherwise `NOTE` (see Variant logic below) | `NOTE` |
| `${PROJECT}` | active project | `bfg-swt` |
| `${TICK_UTC}` | tick timestamp (ISO 8601, compact) | `2026-05-19T06:30Z` |
| `${DUTIES_LIST}` | comma-separated list of enabled duties this tick | `code-review · cve-scan · conflict-scan · git-hygiene` |
| `${N_HAIKUS}` | count of Haiku sub-agents spawned this tick | `4` |
| `${CAP}` | configured Haiku cap for this watchman | `6` |
| `${FINDINGS_LIST}` | multi-line bullets, one per duty with non-zero findings (see format below) | (multi-line) |
| `${REPORTS_PATH}` | path to watchman reports dir | `.kingdom/bfg-swt/reports` |

## `${DUTIES_LIST}` format

Comma-separated, only duties that were enabled in the watchman config this tick:

```text
code-review · cve-scan · conflict-scan · git-hygiene
```

If a duty is disabled in config, omit it entirely (do not render `code-review (disabled)`).

## `${FINDINGS_LIST}` format

One bullet per duty that returned at least one finding. Duties with zero findings are skipped entirely.

```text
  • ${N_REVIEW_FLAGS} code review flags (WATCH_REVIEW_*)
  • ${N_CVE} CVE findings (WATCH_CVE_*)
  • ${N_CONFLICTS} cross-lane conflicts (WATCH_CONFLICTS_*)
  • ${N_HYGIENE} git hygiene issues (WATCH_GIT_*)
```

Sub-variables:

| Sub-var | Meaning | Example |
|---|---|---|
| `${N_REVIEW_FLAGS}` | count of code review flags raised | `3` |
| `${N_CVE}` | count of CVE findings | `1` |
| `${N_CONFLICTS}` | count of cross-lane file conflicts | `2` |
| `${N_HYGIENE}` | count of git hygiene issues | `0` (→ line dropped) |

If all four duties return zero findings, render a single line instead of an empty block:
```text
  • No findings this tick.
```

## Variant logic — `[!NOTE]` vs `[!CAUTION]`

| Condition | `${TICK_FLAVOUR}` | Alert colour |
|---|---|---|
| Any finding carries `severity=urgent` (e.g. high-severity CVE, conflict on a critical/auth/prod-secrets file, gate-breaking code issue) | `CAUTION` | red |
| All findings are informational / low severity, OR no findings at all | `NOTE` | blue |

The Watchman determines urgency per-finding when it writes `WATCH_TICK_${TICK_UTC}.md`. The card picks `CAUTION` if the report contains at least one `severity: urgent` entry.

## Example rendering — quiet tick (NOTE)

```text
> [!NOTE]
> ```
> ╭─ 🕵️ Watchman tick · bfg-swt · 2026-05-19T06:30Z ──────╮
> │  Duties run: code-review · cve-scan · git-hygiene       │
> │  Haiku sub-agents spawned: 3 (cap=6)                    │
> │                                                         │
> │  Findings:                                              │
> │  • 2 code review flags (WATCH_REVIEW_*)                 │
> │  • 1 git hygiene issues (WATCH_GIT_*)                   │
> │                                                         │
> │  Details: .kingdom/bfg-swt/reports/                     │
> │           WATCH_TICK_2026-05-19T06:30Z.md               │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Example rendering — urgent tick (CAUTION)

```text
> [!CAUTION]
> ```
> ╭─ 🕵️ Watchman tick · bfg-swt · 2026-05-19T10:15Z ──────╮
> │  Duties run: code-review · cve-scan · conflict-scan     │
> │             · git-hygiene                               │
> │  Haiku sub-agents spawned: 4 (cap=6)                    │
> │                                                         │
> │  Findings:                                              │
> │  • 1 code review flags (WATCH_REVIEW_*)                 │
> │  • 2 CVE findings (WATCH_CVE_*) ← urgent               │
> │  • 1 cross-lane conflicts (WATCH_CONFLICTS_*)           │
> │                                                         │
> │  Details: .kingdom/bfg-swt/reports/                     │
> │           WATCH_TICK_2026-05-19T10:15Z.md               │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## No-findings tick behaviour

If all duties return zero findings, the card still renders (tick proof-of-life), but `${FINDINGS_LIST}` collapses to `• No findings this tick.`. Flavour is always `[!NOTE]` for a clean tick.

## Relationship to `watchman-alert.md`

- `watchman-alert` fires for **individual events** (one card per event, e.g. `dev_red`, `lane_blocked`). It is real-time.
- `watchman-tick` fires **once per loop tick** as a batch summary after all Haiku sub-agents complete. It is periodic.
- Both can fire in the same tick: `watchman-alert` cards appear inline as events occur; `watchman-tick` appears at the end of the tick as a consolidated summary.

## Notes

- The Haiku sub-agents write individual `WATCH_<DUTY>_*.md` files; the Watchman then writes the merged `WATCH_TICK_${TICK_UTC}.md` summary. The card links to the merged file only.
- `${N_HAIKUS}` may be less than the number of duties if some duties were combined into a single sub-agent (e.g., `conflict-scan` + `git-hygiene` handled by one agent when the branch diff is small).
- Long `${DUTIES_LIST}` strings that exceed 58 chars wrap to the next `│`-prefixed line (indented 13 spaces to align after `Duties run: `).
