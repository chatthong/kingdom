# king-auto-gate.md — Auto-gate on completion (un-gated sentinel state machine)

> Extracted from [`king.md`](king.md) (v0.35.0 modular reorg). Every sentinel a lane writes is the King's cue to run the pre-commit gate immediately — detection of un-gated sentinels, the auto-trigger rule, when it fires, and the gate-pass → overlay handoff.

See [`king.md`](king.md) for the King role overview, [`king-overlay-review.md`](king-overlay-review.md) for where gate-pass flows next, [`king-watchman-integration.md`](king-watchman-integration.md) for the watchman-notify trigger.

---

## Auto-gate on completion (King never sits on an un-gated sentinel)

Every sentinel a lane writes is **King's cue to run the pre-commit gate immediately** — no waiting for the user to nudge. This applies both in-session (King dispatched a task, polls for sentinel, sentinel writes, King continues to gate) AND on session resume (King reads existing sentinels at startup and detects which haven't been gated yet).

### Detection — un-gated sentinel pattern

A lane completion produces a sentinel at `<LOGS>/done/<ID>__<sub>-<lane>.flag`. The King's pre-commit gate, when it runs, produces a test report at `<project>/docs/test-reports/KING_<UTC>__<lane>__<sub-task-id>.md`.

**Definition:** an **un-gated sentinel** is a flag at `<LOGS>/done/<ID>__*-<lane>.flag` with NO matching `KING_*__<lane>__<sub-task-id-from-flag>.md` test report.

```bash
# Find un-gated sentinels at session start (and pre-every-Ter-interaction)
for FLAG in "$LOGS"/done/*.flag; do
  [ -f "$FLAG" ] || continue
  BASE=$(basename "$FLAG" .flag)
  # Filename format: <ID>__<sub>-<lane>
  ID="${BASE%%__*}"
  LANE_PART="${BASE#*__}"          # e.g., sonnet-worker-2
  LANE=$(echo "$LANE_PART" | sed 's/^[a-z]*-//')   # strip "sonnet-" → worker-2

  # Already gated?
  if ! ls "$PROJ/docs/test-reports/KING_"*"__${LANE}__${ID}.md" >/dev/null 2>&1; then
    echo "UN_GATED: $LANE / $ID"
  fi
done
```

### The auto-trigger rule

When King detects ≥1 un-gated sentinel, **King runs the pre-commit gate without asking** for each one. Gate is non-destructive (typecheck + tests + dry-merge in the lane's worktree). Gate writes a test report regardless of pass/fail.

Then — per [`king-overlay-review.md`](king-overlay-review.md) (the WORKING-TREE OVERLAY model, v0.17.0+) — gate-pass flows into the kingdom **overlay** (NOT a merge commit; the `kingdom` branch never commits, R4):

- **Gate PASS** → King **(1)** overlays the lane onto kingdom's working tree via `kingdom_overlay_lane "$PWD" "<lane>" "$BASE"` (the R4-guarded helper: `git diff origin/$BASE..<lane> | git apply --3way`; resolving common conflicts in the working tree, surfacing real source-file collisions to the user — **no `git merge`, no commit on kingdom**). **(2)** Prints the review surface as UNCOMMITTED changes: `git status --short` + `git diff "origin/$BASE" --stat`. **(3)** Fires `cmux_notify "$KING_WS" "👑 King · review on kingdom?" "<lane> · <sub-task-id>"` and asks in chat: "Gate passed for `<lane>` task `<ID>` + overlaid onto kingdom as uncommitted changes. Review the diff above (GitHub Desktop's Changes tab); ready for push?"
- **Gate FAIL** → King fires `cmux_notify "<lane-ws>" "👑 King · gate FAIL"` and tells the user what failed. May dispatch a fix-task back to the lane (King's call). NO overlay happens on fail.

Push only happens after the user explicitly approves the kingdom review. King NEVER skips the overlay-onto-kingdom step, and NEVER commits/merges on the `kingdom` branch (R4). When ≥2 lanes are gated, overlay ALL of them so the user reviews the full set at once (R15); the overlay stays dirty until push (R29).

This eliminates two failure modes:
- "lane finished but King stayed idle" (v0.14.10 fix)
- "King jumped from gate-pass to push without showing the user the integrated review surface" (v0.15.1 fix — real test caught this)

### When this fires

| Trigger | Action |
|---|---|
| **Session resume** (first message after `/kingdom:work`) | Sweep `<LOGS>/done/*.flag` → identify un-gated → auto-gate each |
| **Pre-user-interaction** (before responding to any new chat message) | Same sweep — catches sentinels written while King was idle |
| **Post-dispatch polling** (King dispatched a task and is polling for its sentinel) | Standard in-session flow — sentinel detected → continue to gate |
| **Watchman notify** (cmux_notify fires "lane done") | King reads the alert, looks up the lane's pending sentinel, auto-gates |

### Daily kickoff additions (Step 0.5)

The kickoff synthesis (after Context loaded + Watchman state) now includes a section if any un-gated sentinels exist:

```text
Un-gated work (auto-firing gates):
   • worker-2 / FE-P0-FOUND.7  →  running gate now
   • worker-1 / BE-AUTH-3      →  running gate now

   (results will appear as test reports in docs/test-reports/ +
    "push?" prompts in this chat as each gate completes)
```

King doesn't ask permission to run the gates — they're non-destructive. King DOES ask permission before each push.

### Anti-patterns

- ❌ King reports "worker-2 done" + lists state + stops. The sentinel sits un-gated; the user has to manually say "run the gate."
- ❌ King runs the gate but waits for the user to ask. Same problem — the work is done; the next deterministic step is the gate.
- ❌ King ignores sentinels older than ~24h thinking "the user probably handled it." If the user handled it, the test report exists and the un-gated detector skips it. If it doesn't exist, the work is genuinely un-gated and King runs it.
- ❌ **King jumps from gate-pass directly to "push?" — skipping the kingdom merge + review surface step.** v0.15.1 makes the kingdom merge MANDATORY. See § "Kingdom as review staging".
- ❌ King auto-pushes after the user approves review. Push approval is ALWAYS human-gated — auto-gate-and-merge stops at the review prompt, push happens only on explicit "push" word from the user.
