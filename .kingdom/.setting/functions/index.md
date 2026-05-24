# functions — index

> One bash helper per file. Source `_load.sh` then `load <names>` (or `load_feature <feature>` via `manifest.json`) to pull only what a run calls. 54 functions total.

## core (45)
| function | purpose | file |
|---|---|---|
| `_bounded_wait` | Inputs: | [_bounded_wait.sh](_bounded_wait.sh) |
| `attach_or_create_worktree` | Case A: worktree directory exists → reuse silently | [attach_or_create_worktree.sh](attach_or_create_worktree.sh) |
| `carve_and_push_feature` | CORRECT — fast-forward checkout; no new commits | [carve_and_push_feature.sh](carve_and_push_feature.sh) |
| `cmux_attention_clear` |  | [cmux_attention_clear.sh](cmux_attention_clear.sh) |
| `cmux_attention_override` | Layer 1: badge dot | [cmux_attention_override.sh](cmux_attention_override.sh) |
| `cmux_set_state` |  | [cmux_set_state.sh](cmux_set_state.sh) |
| `compute_gate_duration` | $1 = lane, $2 = id. The King records gate start in $GATE_ELAPSED; this returns a label. | [compute_gate_duration.sh](compute_gate_duration.sh) |
| `compute_ready_for_fresh_work` | true iff every lane in state.lanes has task=null AND uncommitted_files=0 | [compute_ready_for_fresh_work.sh](compute_ready_for_fresh_work.sh) |
| `compute_task_duration` | $1 = lane, $2 = id. Wall-clock = mtime(sentinel) - mtime(task file), as "N min". | [compute_task_duration.sh](compute_task_duration.sh) |
| `curated_path` |  | [curated_path.sh](curated_path.sh) |
| `extract_pr_title_from_task_file` | $1 = lane, $2 = id. PR title = the task file's "# Task: <id> — <title>" first line. | [extract_pr_title_from_task_file.sh](extract_pr_title_from_task_file.sh) |
| `fetch_weather_line` | Opt-out via kingdom.json.welcome.weather = false | [fetch_weather_line.sh](fetch_weather_line.sh) |
| `find_ungated_sentinels` | Already gated? (test report exists) | [find_ungated_sentinels.sh](find_ungated_sentinels.sh) |
| `generate_pr_body_from_task_file` | # Summary | [generate_pr_body_from_task_file.sh](generate_pr_body_from_task_file.sh) |
| `get_pr_title_from_task_file` | Alias used by carve_and_push_feature; same logic as extract_pr_title_from_task_file. | [get_pr_title_from_task_file.sh](get_pr_title_from_task_file.sh) |
| `guard_lane_workspace_exists` | Inputs: | [guard_lane_workspace_exists.sh](guard_lane_workspace_exists.sh) |
| `guard_no_king_session_worktree_cd` | Inputs: | [guard_no_king_session_worktree_cd.sh](guard_no_king_session_worktree_cd.sh) |
| `guard_worker_commit_branch` | Inputs: | [guard_worker_commit_branch.sh](guard_worker_commit_branch.sh) |
| `haiku_read_docs_orientation` | Inputs: | [haiku_read_docs_orientation.sh](haiku_read_docs_orientation.sh) |
| `init_subagent_pool` |  | [init_subagent_pool.sh](init_subagent_pool.sh) |
| `kingdom_discard_overlay` |  | [kingdom_discard_overlay.sh](kingdom_discard_overlay.sh) |
| `kingdom_overlay_lane` | Inputs: | [kingdom_overlay_lane.sh](kingdom_overlay_lane.sh) |
| `kingdom_reset` |  | [kingdom_reset.sh](kingdom_reset.sh) |
| `kingdom_resync_after_merge` | Step 1: clean overlay state on kingdom (drop any uncommitted overlay) | [kingdom_resync_after_merge.sh](kingdom_resync_after_merge.sh) |
| `kingdom_review_surface` |  | [kingdom_review_surface.sh](kingdom_review_surface.sh) |
| `latest_test_report` | $1 = lane, $2 = id. Newest KING_/LANE_ test report matching this lane+id. | [latest_test_report.sh](latest_test_report.sh) |
| `make_artifact_id` |  | [make_artifact_id.sh](make_artifact_id.sh) |
| `parallel_edit_fanout` | Inputs: | [parallel_edit_fanout.sh](parallel_edit_fanout.sh) |
| `pattern_grep_fanout` | Fan out N Haiku scanners in parallel (capacity is unlimited per v0.15.0) | [pattern_grep_fanout.sh](pattern_grep_fanout.sh) |
| `pick_next_task_for` | $1 = lane. Echo the next claimable sub-task id for that lane, or nothing. | [pick_next_task_for.sh](pick_next_task_for.sh) |
| `pick_skills_for_task` | Check for user override first | [pick_skills_for_task.sh](pick_skills_for_task.sh) |
| `poll_for_sentinels` | $1 = name glob under <LOGS>/done (e.g. "audit-*"); $2 = timeout secs (default 180). | [poll_for_sentinels.sh](poll_for_sentinels.sh) |
| `random_task_done_line` | Extract the 20 numbered lines from the pool file | [random_task_done_line.sh](random_task_done_line.sh) |
| `raw_path` |  | [raw_path.sh](raw_path.sh) |
| `read_session_state` | Schema version guard: warn on unknown schema_version | [read_session_state.sh](read_session_state.sh) |
| `render_card` | A "/<variant>" suffix selects a section WITHIN the card; the file is always the part befor | [render_card.sh](render_card.sh) |
| `run_tier1_gate` | $1 = lane, $2 = sub-task id. Runs gate.typecheck inside the lane's worktree (Tier-1, fast) | [run_tier1_gate.sh](run_tier1_gate.sh) |
| `run_tier2_gate` | Runs gate.tests + smoke + lint on the kingdom overlay (primary checkout on the kingdom bra | [run_tier2_gate.sh](run_tier2_gate.sh) |
| `save_session_state` | Build the lanes object by iterating over lanes declared in kingdom.json | [save_session_state.sh](save_session_state.sh) |
| `spawn_master_workspace` | v0.27.0+: respect kingdom.json.cmux.spawnWindow for multi-window users | [spawn_master_workspace.sh](spawn_master_workspace.sh) |
| `spawn_pool_slot` | v0.31.1: read model from config (default sonnet) and pass to claude -p. | [spawn_pool_slot.sh](spawn_pool_slot.sh) |
| `spawn_subagent_from_pool` |  | [spawn_subagent_from_pool.sh](spawn_subagent_from_pool.sh) |
| `spawn_subagent_tab` | $1 = model (default sonnet), $2 = brief. Visible-tab fallback when the pre-warmed pool is  | [spawn_subagent_tab.sh](spawn_subagent_tab.sh) |
| `summarise_gate_failure` | $1 = lane, $2 = id. Last failing lines from the newest test report, or a generic message. | [summarise_gate_failure.sh](summarise_gate_failure.sh) |
| `wait_for_ter_decision` | Interactive: the King pauses and waits for the user's next chat message. Only the literal | [wait_for_ter_decision.sh](wait_for_ter_decision.sh) |

## senior (7)
| function | purpose | file |
|---|---|---|
| `create_story_branch` | Inputs: $1 = PROJ, $2 = story id, $3 = base (default develop), $4 = senior lane (default s | [create_story_branch.sh](create_story_branch.sh) |
| `guard_senior_dispatch_scope` | Inputs: $1 = senior lane, $2 = target worker lane, $3 = space-separated pod members | [guard_senior_dispatch_scope.sh](guard_senior_dispatch_scope.sh) |
| `run_tier2_on_story` | Inputs: $1 = senior worktree (story branch checked out), $2 = kingdom.json path | [run_tier2_on_story.sh](run_tier2_on_story.sh) |
| `senior_merge_worker_into_story` | Inputs: $1 = senior worktree (on story/<id>), $2 = worker branch | [senior_merge_worker_into_story.sh](senior_merge_worker_into_story.sh) |
| `senior_review_tick` | Inputs: $1 = senior worktree (story branch), $2 = base (default develop) | [senior_review_tick.sh](senior_review_tick.sh) |
| `spawn_senior_loop` | Inputs: $1 = senior workspace ref, $2 = story id | [spawn_senior_loop.sh](spawn_senior_loop.sh) |
| `spawn_senior_workspace` | Inputs: $1 = senior lane (senior-1), $2 = story worktree path, $3 = color (default Teal) | [spawn_senior_workspace.sh](spawn_senior_workspace.sh) |

## watchman (2)
| function | purpose | file |
|---|---|---|
| `spawn_watchman_loop` | Inputs: | [spawn_watchman_loop.sh](spawn_watchman_loop.sh) |
| `watchman_cross_story_scan` | Inputs: $1 = PROJ. Pairwise git merge-tree across in-flight story branches. | [watchman_cross_story_scan.sh](watchman_cross_story_scan.sh) |
