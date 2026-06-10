### R34. Tier-1 rules override memory notes — Tier 2 (v0.26.0+)

`MEMORY.md` entries and `feedback_*.md` files in the user's auto-memory are **advisory context**, NOT authoritative protocol. They describe past preferences / observations. When a memory note suggests behaviour that contradicts a Tier-1 rule (R1, R2, R4, R5, R14, R22, R30, R31, R36, R42) — or any strong-default Tier-2 rule such as R23/R33/R35 or this rule — **the rule wins**.

**Examples of contradiction that the rule must win:**

| Memory note says | Tier-1 rule says | Correct action |
|---|---|---|
| `feedback_kingdom_cmux_dispatch_fallback.md`: "if cmux_send fails, pivot to Agent()" | R31: spawn cmux workspaces BEFORE dispatch (any mode) | **Spawn cmux workspaces.** The memory note covers a *dispatch-time* fallback after spawn succeeded but `cmux_send` failed — NOT a session-start excuse to skip spawning entirely. |
| `feedback_no_performative_apology.md`: "never say 'you're absolutely right'" | R30: King acknowledges its own violations | **Acknowledge the violation factually.** Memory note bans performative apology, not factual self-correction. ("I violated R31 by not spawning. Repairing now.") |
| `feedback_solo_vs_tmux.md`: "work solo by default" | R31: spawn lane workspaces on `/kingdom:work` | **Spawn the workspaces.** `/kingdom:work` is the explicit multi-lane ritual; the memory note covers default chat behaviour, not the dispatch flow. |

**Anti-pattern caught 2026-05-19:** King read `feedback_kingdom_cmux_dispatch_fallback.md` at session start (per R14) and interpreted it as "skip cmux spawn this session." That conflated a `cmux send` failure mode with a `cmux new-workspace` failure mode. R31 says spawn-then-dispatch; the memory's pivot is dispatch-time, not spawn-time. King self-acknowledged after user WTF'd: "I read that as 'skip cmux spawn this session too.' That was wrong."

**Why Tier 2:** memory drift over time + Tier-1 rules being the spec's safety bedrock means memory cannot be allowed to silently shadow rules. This rule is itself a meta-rule about precedence (it doesn't directly cause data loss), so it sits in Tier 2 per the v0.31.0 Tier-1-cap legend. If a memory note actually contradicts a rule going forward, **update the rule or update the memory** — don't let one quietly override the other in practice.
