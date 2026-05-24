# functions — index

> One bash helper per file. Source `_load.sh` and `load <names>` to pull only what a run calls.

| function | purpose | file |
|---|---|---|
| `attach_or_create_worktree` | silent idempotent worktree setup | [attach_or_create_worktree.sh](attach_or_create_worktree.sh) |
| `cmux_attention_override` | 3-layer state override (badge + description + notify) | [cmux_attention_override.sh](cmux_attention_override.sh) |
| `cmux_set_state` | update workspace description (live status line) | [cmux_set_state.sh](cmux_set_state.sh) |
| `compute_ready_for_fresh_work` | returns "true" or "false" | [compute_ready_for_fresh_work.sh](compute_ready_for_fresh_work.sh) |
| `create_story_branch` | open a local story integration branch + the Senior's worktree (R46) | [create_story_branch.sh](create_story_branch.sh) |
| `fetch_weather_line` | weather slot for welcome card | [fetch_weather_line.sh](fetch_weather_line.sh) |
| `guard_lane_workspace_exists` | block dispatch if lane workspace not visible in cmux (R31 + R36) | [guard_lane_workspace_exists.sh](guard_lane_workspace_exists.sh) |
| `guard_no_king_session_worktree_cd` | block King's main session from cd-ing into a lane worktree (R30 + R37) | [guard_no_king_session_worktree_cd.sh](guard_no_king_session_worktree_cd.sh) |
| `guard_senior_dispatch_scope` | hard gate: Senior dispatches in-pod + visible only (R30 amendment) | [guard_senior_dispatch_scope.sh](guard_senior_dispatch_scope.sh) |
| `guard_worker_commit_branch` | block commits on wrong branch from worker worktrees (R4 + R9) | [guard_worker_commit_branch.sh](guard_worker_commit_branch.sh) |
| `haiku_read_docs_orientation` | parallel doc digest | [haiku_read_docs_orientation.sh](haiku_read_docs_orientation.sh) |
| `kingdom_overlay_lane` | auto-overlay a worker's diff onto kingdom as dirty (R15 enforcement) | [kingdom_overlay_lane.sh](kingdom_overlay_lane.sh) |
| `kingdom_resync_after_merge` | restore truth after a PR squash-merges (v0.19.0+, R26) | [kingdom_resync_after_merge.sh](kingdom_resync_after_merge.sh) |
| `pick_skills_for_task` | per-task skill picker (v0.23.0+) | [pick_skills_for_task.sh](pick_skills_for_task.sh) |
| `random_task_done_line` | pick a random line from cards/task-complete.md pool | [random_task_done_line.sh](random_task_done_line.sh) |
| `read_session_state` | called by /kingdom:work Step 0.6 (resume scan) | [read_session_state.sh](read_session_state.sh) |
| `render_card` | load a card, substitute variables, print | [render_card.sh](render_card.sh) |
| `run_tier2_on_story` | Tier-2 gate on the assembled story branch (R47) | [run_tier2_on_story.sh](run_tier2_on_story.sh) |
| `save_session_state` | called by /kingdom:save | [save_session_state.sh](save_session_state.sh) |
| `senior_merge_worker_into_story` | merge a pod worker into the story branch (R49) | [senior_merge_worker_into_story.sh](senior_merge_worker_into_story.sh) |
| `senior_review_tick` | the Tier-3 review loop (R48, Senior judgment) | [senior_review_tick.sh](senior_review_tick.sh) |
| `spawn_watchman_loop` | auto-dispatch /loop to a watchman workspace (R39) | [spawn_watchman_loop.sh](spawn_watchman_loop.sh) |
| `watchman_cross_story_scan` | cross-story drift signal for the King (R50, watchman duty) | [watchman_cross_story_scan.sh](watchman_cross_story_scan.sh) |
