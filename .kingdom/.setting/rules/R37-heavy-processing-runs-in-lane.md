### R37. Heavy processing runs IN lane workspaces, not in King's session — Tier 1 (v0.28.0+)

Audit fan-outs (the 4 specialists from `/kingdom:work` audit phase), pattern-grep scans (R8 Layer-1 Discovery), doc-digest fan-outs, and any other parallelisable work must dispatch to lane workspaces via `cmux send --workspace worker-N -- "..."`. King's main session never runs the work itself.

**Rationale:** every lane already has its own Claude session running. Using them as parallel compute (instead of spinning new in-process Agent() calls) gives:

- Visible progress (each lane's workspace shows the running command)
- Cancellable per-lane (click the workspace, ctrl-c, no King restart needed)
- No "1 local agent · hidden in compressed indicator" obscurity
- Audit-trail clarity (each lane writes its own sentinel + log line; King aggregates)

**Allowed exceptions (King-only work):**

- Reading task files, log files, watchman state — these are fast, sequential, single-purpose; no need to dispatch.
- Rendering cards to chat (`render_card` calls).
- The dispatch decisions themselves (which lane gets which task).

**Banned in King's main session:** `Agent()` calls for parallel fan-out, `pattern_grep_fanout` invocation, audit specialist spawning. All of these get `cmux send`'d to a worker lane instead.
