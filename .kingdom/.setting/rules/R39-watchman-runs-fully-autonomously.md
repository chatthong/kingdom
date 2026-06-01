### R39. Watchman runs fully autonomously — Tier 1 (v0.29.0+)

Watchman is a self-scheduling agent. King NEVER blocks waiting on watchman, never dispatches work to watchman, and never sends watchman briefs via `cmux send`.

**Spawn-time exception (R52 + spawn flow):** the one-time boot sequence — `/kingdom:self-watchman` self-ground plus the `/loop` kickoff via `spawn_loop` — is the watchman's boot, not ongoing task dispatch. After spawn the watchman is fully autonomous and the King never dispatches tasks to it again.

**Watchman's scheduling is pull-based, not push-based:**

- Watchman owns its own `/loop` with dynamic pacing of 5-15 minutes per tick, calibrated at runtime based on lane activity, PR volume, and prior-tick findings.
- Watchman's duties (polling `develop`, open PRs, lane state, git hygiene) are self-initiated. Nothing needs to trigger them from King.
- King reads `watchman_state.json` + `WATCH_*.md` reports at session start (per R14, step 7) for situational awareness — that is the ONLY sanctioned King→watchman interaction, and it is read-only.

**Fan-out capacity:**

- Watchman may spawn up to N Haiku sub-agents per tick, where N = `kingdom.json.watchman.haikuCapPerTick` (default 5, hard max 10 — see R40 for capping rules).
- Spawning, scheduling, and closing those sub-agents is watchman's own responsibility. King plays no role in this.

**What "autonomous" means in practice:**

| King's allowed actions toward watchman | King's BANNED actions toward watchman |
|---|---|
| Read `watchman_state.json` + `WATCH_*.md` at session start | Send a dispatch brief (`cmux_send "watchman-N" "..."`) |
| Include watchman's latest report in the daily-kickoff synthesis | Block or gate until watchman produces a report |
| Surface a watchman finding to the user as an FYI | Ask watchman to check something specific (watchman decides what to check) |

**Incident reference:** this was implicit pre-v0.29.0 but never codified. In several sessions, King treated watchman like a worker lane — sending it scan requests via `cmux send` or waiting on its output before proceeding. This created bidirectional coupling that broke watchman's autonomous `/loop` pacing (watchman would be mid-tick when King interrupted; King would stall waiting for a watchman reply that never came because watchman was already in a new tick). The autonomy boundary is now explicit and enforceable.
