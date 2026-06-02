# workflow-fanout.md — fan out a task's sub-agent army through the Workflow tool

> **Canonical pattern for [R53](../rules/R53-fan-out-via-workflow-tool.md).** Every role reads this when it needs to fan heavy work out to parallel sub-agents ([R51](../rules/R51-lane-roles-fan-out-sub-agents.md)). The Workflow tool is the preferred mechanism *when the session exposes it*; otherwise fall back to bounded `Agent()` / cmux tabs.

The `/workflows` view (phases, per-agent token/tool/time, judge stages) is a **Claude Code harness feature** — the kingdom does not ship it. The kingdom just *uses* the Workflow tool, and the UI comes for free. One kingdom task = one Workflow run = one entry in that view.

---

## The decision (per task, every role)

```text
Heavy fan-out needed (R51)?
   │
   ├─ Workflow tool in my toolset?  ──► YES ──► call Workflow({script})        → /workflows UI
   │                                                                              (one run per task)
   └─                               ──► NO  ──► bounded fallback:
                                                  • lane roles → Agent() (R42) or visible cmux tabs
                                                  • King       → cmux tabs / lane-dispatch (R37/R38),
                                                                 never bare Agent() in King's session
```

**Self-detect** = check whether `Workflow` appears in your available tools (named in the tool list / system reminders). Don't assume — many sessions won't have it. The kit is shape-only; the fallback path is a first-class citizen, not an error.

---

## What stays the same (the Workflow run does NOT replace these)

- **Task file ([R23](../rules/R23-task-file-step-0-must.md))** — still opened BEFORE the fan-out; Status / Brief / Plan / Progress / Final summary.
- **The closer ([R22](../rules/R22-the-closer-4-step.md))** — still fires on completion: raw → curated → `master_agent.log` line → sentinel flag. The sentinel is the load-bearing signal; the Workflow run is just how the army executed.
- **Lanes ([R36](../rules/R36-visible-workspace-progress-before-any.md))** — the lane is a persistent cmux/tmux workspace. The Workflow runs *inside* the lane's session and structures the ephemeral army for one task. It never spawns/replaces the lane.
- **Bounds** — R42 (no unbounded waits), the R51 soft target (`kingdom.json.subAgents.parallelTarget`), and the watchman's R40 hard cap all still apply; encode them as the Workflow's concurrency.

---

## Script skeleton (a role grinding one task)

```js
// Called by a worker/co-worker/senior lane (or the King) IN ITS OWN SESSION.
// meta MUST be a pure literal. Phases mirror the task's plan layers.
export const meta = {
  name: 'worker-1-task-<sub-task-id>',
  description: 'Fan out <task> across parallel sub-agents',
  phases: [
    { title: 'Discover', detail: 'parallel reads/greps' },
    { title: 'Execute',  detail: 'independent edits' },
    { title: 'Verify',   detail: 'adversarial check of each change' },
  ],
}

phase('Discover')
// Haiku for bulk reads/greps (cheap), Sonnet for standard work, Opus for sensitive files
// — the R51 model-by-work-type chain. parallel() is a barrier; pipeline() has no barrier.
const findings = await parallel(TARGETS.map(t => () =>
  agent(`Read ${t} and report <what>`, { label: `read:${t}`, model: 'haiku', schema: FINDING })))

phase('Execute')
const edits = await parallel(findings.filter(Boolean).map(f => () =>
  agent(`Apply <change> to ${f.file}`, { label: `edit:${f.file}`, model: 'sonnet' })))

phase('Verify')                       // judge/verify stage — catches plausible-but-wrong work
const verdicts = await parallel(edits.filter(Boolean).map(e => () =>
  agent(`Adversarially verify: ${e}. Default to rejected if uncertain.`, { schema: VERDICT })))

return { edits, verdicts }
```

After the Workflow returns, the role writes its Final summary into the task file and fires the closer (R22). The user watches the army live in `/workflows`; the lane's cmux sidebar still shows the lane itself.

---

## Per-role shape (same pattern, different work)

| Role | What it fans out | Typical phases |
|---|---|---|
| 👑 **King** | session audit, doc-orientation, cross-story drift scans (R45/R50) — its *sanctioned in-session visible fan-out*; replaces routing-to-tabs when Workflow is present | Scan → Synthesize |
| 🎓 **Senior** | within-story review across the pod's lane tips (R48), conflict scan (R49) | Review → Verify |
| 👷 **Worker** | the task's own discover/execute/verify army (skeleton above) | Discover → Execute → Verify |
| 🧑‍💼 **Co-worker** | same as worker, on user-dictated scope (the army runs; the user still drives the brief) | Discover → Execute → Verify |
| 🕵️ **Watchman** | the per-tick duty fan-out — **but bounded by the R40 hard Haiku cap**, not just the R51 soft target | Duties → Reconcile |

---

## Fallback idiom (no Workflow tool present)

Unchanged from R42 + R51 — bounded parallel `Agent()` (lane roles) or visible cmux tabs:

```bash
# lane role, fallback: bounded parallel sub-agents (illustrative)
PIDS=""
for T in $TARGETS; do
  ( Agent model=haiku "read $T ..." ) &     # in practice: the lane's Agent()/tab spawn
  PIDS="$PIDS $!"
done
_bounded_wait 45 $PIDS                       # R42 — never bare wait
```

The King's fallback never uses bare `Agent()` in its own session — it routes to lanes (`cmux_send`, R37) or visible tabs (`cmux_tab_action`, R38).

---

## Notes

- **Opt-in:** the Workflow tool may require the session to have opted into multi-agent orchestration. Where the kingdom session is configured for it, roles use it; where not, they fall back. Treat presence-in-toolset as the signal.
- **Nesting:** a Workflow agent cannot itself open another Workflow (one level only). A lane *session* calling Workflow is a top-level call and is fine; a sub-agent *inside* a Workflow is not.
- **Cost:** a Workflow can spawn many agents and spend real tokens — the same caution as any R51 fan-out. Scale phases to the task; a one-file change needs no army at all.
