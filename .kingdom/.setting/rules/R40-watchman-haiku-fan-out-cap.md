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

1. **Code review** — one Haiku sub-agent per file touched since the last tick (diff review, style, obvious bugs). Each sub-agent writes `WATCH_CR_<file-hash>_<UTC>.md`.
2. **CVE / dependency audit** — one Haiku sub-agent per lockfile changed since last tick (`npm audit` / `pnpm audit` / `pip-audit` / `cargo audit`). Each writes `WATCH_CVE_<lockfile-hash>_<UTC>.md`.
3. **Cross-lane conflict detection** — one Haiku sub-agent scans all active `worker-N` diffs for overlapping file edits. Writes `WATCH_CONFLICT_<UTC>.md`.
4. **Git hygiene scan** — one Haiku sub-agent checks for: stale worktrees (no sentinel activity > 2 hours), orphan branches (no matching task file), broken sentinels (done flag missing for a task file marked `done`), unflushed `.lane` claims. Writes `WATCH_GIT_<UTC>.md`.

**Aggregation:** watchman collects each sub-agent's sentinel, then writes `WATCH_TICK_<UTC>.md` as the per-tick summary. King reads the latest `WATCH_TICK_*.md` at session start (R14, step 7).

**Cap enforcement mechanics:** before spawning each sub-agent, watchman checks its internal `spawned_this_tick` counter. If `spawned_this_tick >= haikuCapPerTick`, remaining work items are queued for the next tick — not dropped.
