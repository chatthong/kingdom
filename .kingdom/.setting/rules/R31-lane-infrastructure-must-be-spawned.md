### R31. Lane infrastructure MUST be spawned + verified BEFORE any dispatch — Tier 1 (v0.24.0+, expanded v0.25.0)

The kingdom can run in **three modes** for lane dispatch (per memory `feedback_kingdom_cmux_dispatch_fallback.md`):

| Mode | Lane backing | Verification source-of-truth |
|---|---|---|
| **PRIMARY** (cmux.app) | `cmux new-workspace` per lane | `workspace-refs.env` + `cmux tree --all` shows alive |
| **FALLBACK** (tmux) | `tmux new-session -d -s kingdom-<project>` + windows | `tmux ls` shows the session |
| **AGENT** (in-process) | `Agent(subagent_type=...)` sub-agents inside King's session | `.worktrees/<lane>/` directories exist + lane branches exist |

**In ALL modes, the `.worktrees/<lane>/` directories MUST exist BEFORE dispatch.** That's the universal truth: worktrees = lanes exist for git purposes. The cmux refs / tmux session / Agent calls are mode-specific dispatch mechanisms ON TOP of worktrees.

**Verification sequence (in this order):**

1. **`.worktrees/<lane>/` directories exist** for every lane in `kingdom.json.shape` — `ls .worktrees/worker-1 .worktrees/worker-2 ...`. If missing, run `git worktree add` (idempotent).
2. **Mode-specific dispatch mechanism is alive:**
   - PRIMARY: `workspace-refs.env` lists every lane + `cmux tree --all` shows them.
   - FALLBACK: `tmux ls | grep kingdom-<project>` matches.
   - AGENT: no extra check (in-process, always available; just confirm worktrees from step 1).
3. **Render `spawn-complete` card** so the user visually confirms shape (cmux sidebar for PRIMARY, tmux session list for FALLBACK, "Agent fallback mode" notice for AGENT) BEFORE dispatch begins.
4. Only after Step 3 does any dispatch fire.

**Silent-failure pattern this prevents:** King writes a beautiful dispatch brief, sends to a target that doesn't exist (missing workspace ref, dead tmux session, missing worktree). Dispatch returns success. No lane ever receives the brief. King polls for a sentinel that will never appear. Hours wasted.

**Mode detection:** if PRIMARY checks fail but worktrees exist, fall back to AGENT mode (King uses `Agent(subagent_type=general-purpose, prompt="cd .worktrees/<lane> && ...")` — same brief, no cmux required). Don't insist on cmux when worktrees already exist; that's the gap that wasted ~5 minutes of "lanes not spawned" investigation when worktrees were sitting there the whole time.

**Incident sequence (2026-05-19):**
- Session A (early): King session ran without ever spawning lane workspaces. Sidebar had ONE pane. All "dispatches" landed in the void. User: "since morning still 0 job."
- Session B (later same day, after v0.24.0): K31 fired (workspace-refs.env missing) and triggered a spawn flow — but `.worktrees/` already had all 5 lanes from a prior PRIMARY session. King could have used AGENT-mode dispatch immediately; instead it considered spawning 5 fresh cmux workspaces, ran ~5m of investigation, then printed a manual kickoff brief. User: "it not even seek for kingdom latest job."

The fix: R31 now treats `.worktrees/` as the canonical "lanes exist" check; cmux refs are the PRIMARY-mode overlay, not the only valid form.
