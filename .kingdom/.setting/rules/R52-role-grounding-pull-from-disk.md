### R52. Role-grounding is pull-from-disk, not push-from-prompt — Tier 2 (v0.39.0)

A lane must know its own rules from the **versioned source on disk** (`.kingdom/.setting/`), not from what the King restated in a dispatch brief. The King's memory of the rules is the weakest link — after a long multi-day session or a context compaction it drifts, and a brief written from drifted context silently mis-grounds the lane. The fix: each role re-reads its canonical spec via `/kingdom:self-<role>`.

**At spawn (King's obligation):** the King injects `/kingdom:self-<role>` as the **FIRST** message to each freshly-spawned lane — before any task brief. The lane grounds itself from `index.md → rules/index.md (Tier-1) → roles/<role>.md (+ sub-docs) → reference/` and renders the [`role-grounded`](../cards/role-grounded.md) card. The subsequent dispatch brief then carries only the *task*, not a restatement of the rules. Spawn flow: `spawn_master_workspace` (boot Claude) → `cmux_send "<ws>" "/kingdom:self-<role>"` → (per-task) dispatch brief.

**On demand (anyone):** any role — including the King via `/kingdom:self-king` — may re-run its bootstrap at any time to re-ground. Use it when a role has clearly drifted ("the King forgot kingdom after 7 days"), after a `/compact`, or before a high-stakes action.

The five commands: `/kingdom:self-king`, `/kingdom:self-worker`, `/kingdom:self-co-worker`, `/kingdom:self-watchman`, `/kingdom:self-senior`. They are READ-ONLY (read docs, print a card) — they never edit, dispatch, commit, or push. Shared procedure + per-role read map: [`reference/role-bootstrap.md`](../reference/role-bootstrap.md).

**Runtime complement to:** [R14](R14-king-reads-all-context-at.md) (session-start read — R52 makes it re-invokable mid-session) and [R34](R34-tier-1-rules-override-memory.md) (rules override memory — re-reading the rules is the antidote to drift). Bounded by nothing heavy: a self-ground is a handful of doc reads.

**Why Tier 2 (soft):** skipping the spawn-time inject doesn't lose data or break a gate — a lane can still work off a good brief. But it removes the single most common quality-decay path (drifted-King briefing), so it's a strong default the King should follow on every spawn.
