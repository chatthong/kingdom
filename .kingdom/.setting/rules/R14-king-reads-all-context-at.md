### R14. King reads ALL context at session start (v0.14.8+ · expanded v0.19.0)

In order, BEFORE any action:

0. **`rules.md`** (this file) — priority-tiered rules
1. **Workspace `CLAUDE.md`** at `$PWD/CLAUDE.md` — workspace rules + project map
2. **Project `CLAUDE.md`** at `$PWD/<project>/CLAUDE.md` — local stack + gate commands + project-specific rules
3. **Project `README.md`** at `$PWD/<project>/README.md` — public-facing overview, install, conventions
4. **Project `docs/`** index — `ls $PWD/<project>/docs/` + read any `README.md` / `index.md` / similar entry-points if present
5. **`~/.claude/projects/<workspace-key>/memory/MEMORY.md`** — durable preferences + feedback rules
6. **Personal notes** (`TER.md`, `TER_*.md` at workspace OR project root) — read for situational awareness; **NEVER paste verbatim** (R7), never quote in commits / PRs / chat
7. **Watchman state** — newest `WATCH_*.md` reports + `WATCH_DOCS_AUDIT.md` + `watchman_state.json`

Synthesise into a "Context loaded" daily-kickoff message before dispatching anything. See [`king.md`](../roles/king.md) § Daily kickoff routine for the canonical synthesis format.
