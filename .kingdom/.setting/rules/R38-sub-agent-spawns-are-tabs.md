### R38. Sub-agent spawns are TABS or LANE DISPATCH — never in-process Agent() — Tier 1 (v0.28.0+)

The cmux native "1 local agent · ctrl+t to hide tasks" indicator (the compressed bottom-of-pane in-process Agent display) is **banned** for kingdom work. Reason: it's invisible to the user, can't be observed without keystroke, can't be paused, and bypasses the kingdom's audit-trail discipline (sub-agents that spawn this way often skip the 4-step closer because their lifecycle is the parent session's lifecycle).

**Allowed sub-agent spawn mechanisms:**

| Pattern | When |
|---|---|
| **Visible tab via `cmux_tab_action new-terminal-right --workspace "<lane-ws>"`** | All Layer-3 fan-out, all sub-agent work that needs visibility, all work that should auto-close on sentinel (5-step closer Step 5) |
| **Lane dispatch via `cmux_send "worker-N" "..."`** | Routing work to an already-running lane Claude session (most common for kingdom-internal work like audit specialists) |

**Banned:** `Agent(subagent_type="general-purpose", ...)` or any in-process Claude Code agent-team spawn in King's main session.

**Config change for v0.28.0:** `kingdom.json.cmux.subAgentSpawnByModel` defaults flip from `{"haiku":"background","sonnet":"background","opus":"tab"}` to **`{"haiku":"tab","sonnet":"tab","opus":"tab"}`**. Background spawns are opt-in (set explicitly to `"background"` per-model) but no longer the default.

**Anti-pattern caught 2026-05-19:** King's session bottom showed `1 local agent · ctrl+t to hide tasks` with `general-purpose Phase B: per-app debug-data + /api/_dev/me proxy` running invisibly. User had no way to monitor the work without keypress-toggling the tasks panel. Per R38, that work should have spawned as a visible cmux tab inside a lane workspace.
