#!/usr/bin/env bash
# kingdom function: pick_next_task_for

pick_next_task_for () {
  # $1 = lane. Echo the next claimable sub-task id for that lane, or nothing.
  # King judgment, not deterministic bash: King reads the project task-ledger
  # (kingdom.json.taskSource: TODO_*.md / STEP.md / gh issues), skips anything with a
  # claim in <LOGS>/claims/ or an in-flight task file (R33), and echoes one id. No body.
  : # see roles/king.md § Dispatching a task to a lane
}
