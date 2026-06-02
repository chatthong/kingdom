### R53. Sub-agent fan-out runs through the Workflow tool when available — Tier 2 (v0.43.0)

When a role fans heavy work out to parallel sub-agents ([R51](R51-lane-roles-fan-out-sub-agents.md)), the **preferred mechanism is the Claude Code Workflow tool** — *when the session exposes it*. A Workflow run renders a live `/workflows` progress tree (phases, per-agent token/tool/time, optional judge/verify stages), so each task's army is **visible and trackable** — exactly the visibility [R36](R36-visible-workspace-progress-before-any.md)/[R38](R38-sub-agent-spawns-are-tabs.md) aim for, but richer than headless `Agent()`.

**One kingdom task → one Workflow run.** A role still opens its task file ([R23](R23-task-file-step-0-must.md)) and fires the closer ([R22](R22-the-closer-4-step.md)); the Workflow run is the *execution surface* for that task's sub-agent army, **not** a replacement for the artifact protocol. The sentinel flag remains the load-bearing completion signal. Full pattern + script skeleton: [`reference/workflow-fanout.md`](../reference/workflow-fanout.md).

**Self-detect, then fall back (the decision every role makes per task):**

1. **Workflow tool present in the session?** → use it. Encode the fan-out as `phase()` / `parallel()` / `pipeline()` stages, with a judge/verify stage where it adds value.
2. **Not present?** → fall back to the existing bounded fan-out, unchanged:
   - **lane roles** (`worker-N` / `co-worker-N` / `senior-N` / `watchman-N`): bounded `Agent()` ([R42](R42-every-parallel-fan-out-uses.md) + R51) or visible cmux tabs.
   - **King**: visible tabs / lane-dispatch ([R37](R37-heavy-processing-runs-in-lane.md)/R38) — **never** bare `Agent()` in the King's own session.

No hard dependency: the kit is shape-only and MUST keep working where the tool isn't enabled. That is why this is Tier 2, not Tier 1.

**Lanes stay persistent — Workflow governs only the ephemeral army.** Workflow agents are one-shot (spawn → return → gone); kingdom lanes are long-lived cmux/tmux workspaces that survive across tasks ([R36](R36-visible-workspace-progress-before-any.md)). R53 never spawns, replaces, or tears down a lane — it only structures the *within-task* sub-agent fan-out that used to be `Agent()` calls.

**Bounded discipline carries over.** A Workflow's `parallel()`/`pipeline()` stages honour the same concurrency spirit as R42 and the R51 soft target (`kingdom.json.subAgents.parallelTarget`); the watchman's [R40](R40-watchman-haiku-fan-out-cap.md) hard Haiku cap still bounds its own fan-out regardless of mechanism.

**King nuance.** The Workflow tool is the King's sanctioned **in-session, visible** fan-out — the `/workflows` UI satisfies R38's visibility intent without raw `Agent()`. When the tool is unavailable, R37/R38 stand unchanged (route heavy work to lanes / visible tabs; no in-session `Agent()`).

**Why Tier 2 (soft):** it's a *mechanism preference*, capability-gated on the harness exposing the tool — not an irreversible or architecturally-fatal gate. Where the tool exists, using it is the strong default; where it doesn't, the kingdom runs exactly as before.

Related: [R51](R51-lane-roles-fan-out-sub-agents.md) (what to fan out) · [R42](R42-every-parallel-fan-out-uses.md) (bounded) · [R37](R37-heavy-processing-runs-in-lane.md)/[R38](R38-sub-agent-spawns-are-tabs.md) (King visibility + fallback) · [R40](R40-watchman-haiku-fan-out-cap.md) (watchman cap) · [R22](R22-the-closer-4-step.md)/[R23](R23-task-file-step-0-must.md) (artifact protocol) · [R36](R36-visible-workspace-progress-before-any.md) (visibility).
