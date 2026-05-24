### R47. Three-tier gate — Tier 2 (v0.32.0+)

With story pods, the gate has three tiers before the human push (R1):

1. **Tier 1 (worker):** lane typecheck inside each worker's worktree (`gate.typecheck`), unchanged.
2. **Tier 2 (story):** `gate.tests + smoke + lint` run on the assembled `story/<id>` branch when `integration.gateOnStory` is true (replaces the ephemeral kingdom-overlay Tier-2 for pod work).
3. **Tier 3 (Senior review loop):** the Senior's deep review of the assembled story (see R48).

Only after all three pass does the King offer the push-prompt. The human push (R1) remains the final, single, irreversible gate.
