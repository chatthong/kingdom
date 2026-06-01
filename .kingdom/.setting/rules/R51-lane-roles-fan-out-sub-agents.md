### R51. Every lane master + King fans heavy work out to parallel sub-agents — Tier 2 (v0.37.0)

A worker, co-worker, senior, or the King that hits heavy work — multi-file reads, pattern greps, doc orientation, independent edits, review fan-outs — SHOULD do it through **parallel sub-agents**, not serially in its own context. This is a strong default, **not a hard gate**: the soft ceiling is `kingdom.json.subAgents.parallelTarget` (default 10) per lane. Aim for it; exceed it only when a task genuinely needs more; for a trivial one-file task, skip it.

**Model by work type** (per the index.md sub-agent chain + `kingdom.json.subAgents.modelByWorkType`):

- **sonnet** — standard task work (the default lane sub-agent)
- **haiku** — bulk reads, greps, doc orientation, log scans (cheap fan-out)
- **opus** — sensitive / high-stakes files (keys, migrations, security-critical)

**Applies to:** `worker-N`, `co-worker-N`, `senior-N` (as lane masters), **and** the King. The King fans out only via its existing visible mechanisms — `cmux_send` to lanes (R37) and visible tabs (R38) — **never** in-process `Agent()` in the King's own session (R38). Lane masters fan out via tabs / the pre-warmed pool per `kingdom.json.cmux.subAgentSpawnByModel`.

**Still bounded by [R42](R42-every-parallel-fan-out-uses.md):** every parallel fan-out uses `_bounded_wait`, never bare `wait`.

**Distinct from [R40](R40-watchman-haiku-fan-out-cap.md):** the watchman keeps its OWN *hard* per-tick cap (`watchman.haikuCapPerTick`); R51's soft target neither applies to nor overrides it.

**Why Tier 2 (soft):** parallelism is what makes the kingdom faster than running solo — a lane that reads 20 files one-by-one in its own context wastes the fleet. But the right degree is task-dependent, so this is a strong default the actor can scale up or skip, not an iron gate.

Related: [R28](R28-parallel-by-default-for-scan.md) · [R37](R37-heavy-processing-runs-in-lane.md) · [R38](R38-sub-agent-spawns-are-tabs.md) · [R45](R45-haiku-army-doc-orientation-before.md).
