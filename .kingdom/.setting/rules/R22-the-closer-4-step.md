### R22. The closer (4-step or 5-step) MUST fire on EVERY task completion — Tier 1

Even on `blocked` / `cancelled` / `errored` exit, the worker writes:

1. Raw log    →  `<LOGS>/raw/<UTC>__<sub>-<lane>__<id>.md`
2. Curated    →  `<LOGS>/<UTC>__<lane>__<id>.md` (with `## TL;DR` header)
3. Log line   →  append to `<LOGS>/master_agent.log`
4. Sentinel   →  touch `<LOGS>/done/<UTC>__<sub>-<lane>__<id>.flag`
5. (tab-spawned only) Close own tab — `cmux_tab_action close --surface "$CMUX_SURFACE_ID"`

**No silent exits. No "I didn't finish so I won't write."** King relies on the sentinel to detect completion; if it's absent, King thinks the task is still in-flight forever. Status of the work (`done` / `blocked` / `errored`) goes in the task file's `## Status` checkbox + the curated digest's `## TL;DR.Status` field. Closer artifacts ARE the source of truth for "this work is done."

> NOTE: this is Tier 1 because skipping the closer breaks the kingdom's audit trail — King + watchman + `/kingdom:work` audit phase all rely on sentinel files for "is this task done" detection.
