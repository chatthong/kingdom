### R40. Watchman Haiku fan-out cap per tick — Tier 2 (v0.29.0+)

`kingdom.json.watchman.haikuCapPerTick` governs how many Haiku sub-agents watchman may spawn in a single `/loop` tick.

**Defaults and hard limits:**

| Setting | Value |
|---|---|
| Default | `5` |
| Hard maximum | `10` |
| Clamp behaviour | If configured value exceeds 10, clamp to 10 + write one warning line to `master_agent.log` (`[UTC] WATCHMAN_CAP_CLAMPED requested=<N> clamped=10`) |

**Rationale:** multiple kingdoms (one per project) may run simultaneously on the same machine and share the same Anthropic API key. Without a per-kingdom cap, a watchman that finds 30 files changed in one tick could saturate the API with 30 Haiku calls — multiplied by the number of live kingdoms. The default of 5 lets each kingdom run 5 parallel scans per tick while leaving headroom for others.

**What watchman uses the fan-out budget for (in priority order):**

1. **Code review** — one Haiku sub-agent per file touched since the last tick (diff review, style, obvious bugs). Each sub-agent writes `WATCH_REVIEW_<UTC>__<lane>.md`.
2. **CVE / dependency audit** — one Haiku sub-agent per lockfile changed since last tick (`npm audit` / `pnpm audit` / `pip-audit` / `cargo audit`). Each writes `WATCH_CVE_<lockfile-hash>_<UTC>.md`.
3. **Cross-lane conflict detection** — one Haiku sub-agent scans all active `worker-N` diffs for overlapping file edits. Writes `WATCH_CONFLICTS_<UTC>.md`.
4. **Git hygiene scan** — one Haiku sub-agent checks for: stale worktrees (no sentinel activity > 2 hours), orphan branches (no matching task file), broken sentinels (done flag missing for a task file marked `done`), unflushed `.lane` claims. Writes `WATCH_GIT_<UTC>.md`.
5. **Cross-story drift** (R50), **sequence-collision** (parallel numbered-file collisions — migrations/ADRs), **config/secret parity** (new key with no home; committed secret), and **missing-tests** (new source, no tests) scans — one Haiku each (v0.32.0 + v0.40.0). See [`watchman.md` § Per-tick duties](../roles/watchman.md) for all eight.

All eight duties share the same `haikuCapPerTick` budget (priority order above; lower-priority duties are deferred to the next tick when the cap is hit). Findings flow through the watchman's cross-tick **findings ledger** (dedup / escalate / auto-resolve / notify-fallback), so a capped-out tick never loses a finding — it's picked up next tick.

**Aggregation:** watchman collects each sub-agent's sentinel, then writes `WATCH_TICK_<UTC>.md` as the per-tick summary. King reads the latest `WATCH_TICK_*.md` at session start (R14, step 7).

**Where these live (K10, v0.37.0):** ALL `WATCH_*` artifacts above are written to `$LOGS/watch/` (= `.kingdom/<project>/logs/watch/`), never `<project>/docs/test-reports/`. Monitoring heartbeats stay OUT of the project git tree; only PR-evidence `SMOKE_*`/`SENIOR_*`/`KING_*` gate reports ride PRs in `docs/test-reports/`.

**Cap enforcement mechanics:** before spawning each sub-agent, watchman checks its internal `spawned_this_tick` counter. If `spawned_this_tick >= haikuCapPerTick`, remaining work items are queued for the next tick — not dropped.
