### R45. Haiku-army doc orientation before big-picture work — Tier 2 (v0.31.1+)

**Every role** (King, worker-N, co-worker-N, watchman-N) MUST call `haiku_read_docs_orientation` (in [`_primitives.md`](_primitives.md) § Orientation) when it needs the project's big picture — not piecemeal, not "just grep what I need." The fan-out is cheap (Haiku tokens, parallel) and the cost of acting on a stale mental model of the project is high (drift PRs, contradicted conventions, doc-mismatched commits).

**The unified protocol — 4 phases:**

1. **Discover wayfinding files.** Recursively scan the project (excluding `node_modules`, `.git`, `.next`, `dist`, `build`, `target`, `.venv`, `__pycache__`) for `readme.md`, `index.md`, `todo*.md` (case-insensitive). These exist for a reason — they're the project's "you are here" signs.
2. **Phase 1 fan-out — read wayfinding first.** Spawn up to **10 Haiku** sub-agents in parallel, one per wayfinding file. Each writes a 5-bullet digest. Bounded by `_bounded_wait 45` (R42).
3. **Phase 2 fan-out — full doc landscape.** Subtract Phase 1 files from the full `*.md` list (also excluding `docs/test-reports/`); take the 20 newest by mtime. Spawn up to 10 Haiku in parallel for these too. Bounded by `_bounded_wait 60`.
4. **Consolidate.** Helper writes a single `<LOGS>/.<role>_<UTC>_doc_context.md`. Caller reads THAT file, not the originals — keeps the calling role's context window clean.

**When each role calls it:**

| Caller | Trigger |
|---|---|
| **King** | At `/kingdom:work` session start, immediately after the R14 context read |
| **worker-N / co-worker-N** | At task-brief receipt, BEFORE any code edit (Layer 1 Discovery in the 4-layer worker flow) |
| **watchman-N** | Once at spawn; refreshed every 10 `/loop` ticks OR when any root/docs/ `*.md` mtime changes |
| **Any role, mid-task** | When the role is "not sure" — can't confirm a pattern, convention, or decision from current context |

**Sub-agent model defaults (locked by R45):**

| Use case | Model | Why |
|---|---|---|
| Doc-orientation fan-out (R45 itself) | **Haiku** | Many short reads, cheap, parallel — Haiku 4.5 is sufficient |
| Lane sub-agents (worker-N spawning helpers) | **Sonnet** | One logical chunk each; Sonnet 4.6 is the cost/quality sweet spot |
| Sensitive design review | **Opus** | When the lane explicitly needs the heavier model — call out in the brief |
| Lane masters themselves | **Opus** (worker/co-worker), **Sonnet** (watchman) | Already established in `workers.md` / `watchmans.md` |

**Cap:** `HAIKU_CAP=10` hard ceiling per call. The helper enforces it; callers cannot raise it past 10 without splitting into multiple calls.

**Anti-patterns:**

- ❌ A worker grep-spelunking project files to figure out conventions, ignoring the docs — wasted context window, often wrong because docs override code patterns
- ❌ King writing dispatch briefs from training-prior on a project name without an orientation pass — leads to "fix X using popular React pattern" when the project's docs say "we do X via custom hook factory"
- ❌ Multiple Phase 2 calls in one session that re-read the same files — call once at session start; the consolidated file is the cache
- ❌ Raising `HAIKU_CAP` past 10 — instead, raise the Phase 2 file budget if needed, but keep parallel fan-out bounded

**Why Tier 2 (not Tier 1):** advisory orientation. Skipping it produces *worse* output, not corrupted state — so demoting an iron-clad signature isn't warranted. But the cost of skipping is high enough across all roles that it earns the strong-default tier.

**Cross-references:** R8 (pattern grep before implementation — R45 is the documentation analogue), R14 (King's session-start context read — R45 extends this to ALL roles), R28 (parallel by default for scans — Haiku fan-out IS the canonical implementation), R40 (Haiku cap is shared with watchman's per-tick cap; R45's cap is per-call, not per-tick), R42 (bounded wait around every fan-out).
