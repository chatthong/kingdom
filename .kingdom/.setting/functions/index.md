# functions — index

> One bash helper per file (the `tmux/` backend is a single cohesive module). Source `_load.sh` then `load <names>` (or `load_feature <feature>` via `manifest.json`). `load` finds a bare name whether it sits flat here or in a backend subfolder.

> Layout: flat files = backend-agnostic mechanics, all in feature **core**; **`cmux/`** = the cmux.app PRIMARY backend (one wrapper per `cmux` subcommand + the `browser_*` wrappers); **`tmux/`** = the FALLBACK backend (v0.41.0; one wrapper per file, like `cmux/`; `kingdom_use_tmux_backend` routes `cmux_*` calls to tmux when `KINGDOM_BACKEND=tmux`). Function NAMES are action-based, not role-based — any role loads any helper. Features group by BACKEND/CAPABILITY only: **core** (always) deps **cmux** (always); **tmux** + **browser** load on demand.

## core (57)
| function | purpose | file |
|---|---|---|
| `_bounded_wait` | — | [_bounded_wait.sh](_bounded_wait.sh) |
| `attach_or_create_worktree` | — | [attach_or_create_worktree.sh](attach_or_create_worktree.sh) |
| `carve_and_push_feature` | Carve `feature/<topic>` from a lane tip, push, open a **draft** PR (`gh pr create --draft`), and discard the overlay (R29). `gh pr create` exit code is checked — a failed create surfaces as rc=1 and the overlay is NOT discarded. | [carve_and_push_feature.sh](carve_and_push_feature.sh) |
| `compute_gate_duration` | — | [compute_gate_duration.sh](compute_gate_duration.sh) |
| `compute_ready_for_fresh_work` | — | [compute_ready_for_fresh_work.sh](compute_ready_for_fresh_work.sh) |
| `compute_task_duration` | — | [compute_task_duration.sh](compute_task_duration.sh) |
| `create_story_branch` | — | [create_story_branch.sh](create_story_branch.sh) |
| `cross_story_scan` | — | [cross_story_scan.sh](cross_story_scan.sh) |
| `curated_path` | — | [curated_path.sh](curated_path.sh) |
| `extract_pr_title_from_task_file` | — | [extract_pr_title_from_task_file.sh](extract_pr_title_from_task_file.sh) |
| `fetch_weather_line` | — | [fetch_weather_line.sh](fetch_weather_line.sh) |
| `find_ungated_sentinels` | — | [find_ungated_sentinels.sh](find_ungated_sentinels.sh) |
| `generate_pr_body_from_task_file` | — | [generate_pr_body_from_task_file.sh](generate_pr_body_from_task_file.sh) |
| `get_pr_title_from_task_file` | — | [get_pr_title_from_task_file.sh](get_pr_title_from_task_file.sh) |
| `guard_commit_branch` | — | [guard_commit_branch.sh](guard_commit_branch.sh) |
| `guard_dispatch_scope` | — | [guard_dispatch_scope.sh](guard_dispatch_scope.sh) |
| `guard_lane_workspace_exists` | — | [guard_lane_workspace_exists.sh](guard_lane_workspace_exists.sh) |
| `guard_no_worktree_cd` | — | [guard_no_worktree_cd.sh](guard_no_worktree_cd.sh) |
| `haiku_read_docs_orientation` | — | [haiku_read_docs_orientation.sh](haiku_read_docs_orientation.sh) |
| `inbox_list` | List the shared broker inbox, oldest-first. No args = whole pending feed. `--to <me>` = only messages where `to==me` or `to==all`. `--from <who>` = filter by sender. Prints one path per line; rc=0 with empty output when none (R55). | [inbox_list.sh](inbox_list.sh) |
| `inbox_pending_count` | Echo integer count of pending messages (whole feed, or `--to <me>` for addressed+broadcast). Never errors — echoes 0 on any failure (R55). | [inbox_pending_count.sh](inbox_pending_count.sh) |
| `inbox_read` | Print an inbox message. `--consume` moves it to `inbox/.archive/` so the feed cannot regrow into a pile (R55). | [inbox_read.sh](inbox_read.sh) |
| `inbox_reply` | Sugar for `inbox_send <to> info <task_id> no <message...>` — post a no-reply-needed `info` response to the sender (R55). | [inbox_reply.sh](inbox_reply.sh) |
| `inbox_send` | Write one file `<UTC>__<from>__<to>__<type>.md` into the single `inbox/` feed with YAML front matter (`from/to/type/task/needs-reply`), then best-effort `cmux_notify` the addressed workspace. File is source of truth; notify failure is non-fatal. `from` = `${LANE:-${KINGDOM_ROLE:-king}}` (R55). | [inbox_send.sh](inbox_send.sh) |
| `init_subagent_pool` | — | [init_subagent_pool.sh](init_subagent_pool.sh) |
| `kingdom_backend_init` | Detect cmux.app vs other, export KINGDOM_BACKEND, activate the backend (v0.41.0). | [kingdom_backend_init.sh](kingdom_backend_init.sh) |
| `kingdom_detect_backend` | Echo `cmux`/`tmux`/`standalone` from the host terminal (v0.41.0). | [kingdom_detect_backend.sh](kingdom_detect_backend.sh) |
| `kingdom_discard_overlay` | — | [kingdom_discard_overlay.sh](kingdom_discard_overlay.sh) |
| `kingdom_overlay_lane` | — | [kingdom_overlay_lane.sh](kingdom_overlay_lane.sh) |
| `kingdom_repair_stale_lanes` | Detect/`--repair` the workspace↔worktree disconnect a rebase/merge leaves behind (U11). | [kingdom_repair_stale_lanes.sh](kingdom_repair_stale_lanes.sh) |
| `kingdom_reset` | — | [kingdom_reset.sh](kingdom_reset.sh) |
| `kingdom_resync_after_merge` | — | [kingdom_resync_after_merge.sh](kingdom_resync_after_merge.sh) |
| `kingdom_review_surface` | — | [kingdom_review_surface.sh](kingdom_review_surface.sh) |
| `latest_test_report` | — | [latest_test_report.sh](latest_test_report.sh) |
| `make_artifact_id` | — | [make_artifact_id.sh](make_artifact_id.sh) |
| `merge_into_story` | — | [merge_into_story.sh](merge_into_story.sh) |
| `parallel_edit_fanout` | — | [parallel_edit_fanout.sh](parallel_edit_fanout.sh) |
| `pattern_grep_fanout` | — | [pattern_grep_fanout.sh](pattern_grep_fanout.sh) |
| `pick_next_task_for` | — | [pick_next_task_for.sh](pick_next_task_for.sh) |
| `pick_skills_for_task` | — | [pick_skills_for_task.sh](pick_skills_for_task.sh) |
| `poll_for_sentinels` | — | [poll_for_sentinels.sh](poll_for_sentinels.sh) |
| `random_task_done_line` | — | [random_task_done_line.sh](random_task_done_line.sh) |
| `raw_path` | — | [raw_path.sh](raw_path.sh) |
| `read_session_state` | — | [read_session_state.sh](read_session_state.sh) |
| `render_card` | — | [render_card.sh](render_card.sh) |
| `review_tick` | — | [review_tick.sh](review_tick.sh) |
| `run_tier1_gate` | — | [run_tier1_gate.sh](run_tier1_gate.sh) |
| `run_tier2_gate` | — | [run_tier2_gate.sh](run_tier2_gate.sh) |
| `run_tier2_on_story` | — | [run_tier2_on_story.sh](run_tier2_on_story.sh) |
| `save_session_state` | — | [save_session_state.sh](save_session_state.sh) |
| `spawn_loop` | — | [spawn_loop.sh](spawn_loop.sh) |
| `spawn_master_workspace` | — | [spawn_master_workspace.sh](spawn_master_workspace.sh) |
| `spawn_pool_slot` | — | [spawn_pool_slot.sh](spawn_pool_slot.sh) |
| `spawn_subagent_from_pool` | — | [spawn_subagent_from_pool.sh](spawn_subagent_from_pool.sh) |
| `spawn_subagent_tab` | — | [spawn_subagent_tab.sh](spawn_subagent_tab.sh) |
| `summarise_gate_failure` | — | [summarise_gate_failure.sh](summarise_gate_failure.sh) |
| `wait_for_ter_decision` | — | [wait_for_ter_decision.sh](wait_for_ter_decision.sh) |

## cmux (23)
| function | purpose | file |
|---|---|---|
| `cmux_attention_clear` | Resolve an attention override: clear the unread badge and restore the active-state description. | [cmux/cmux_attention_clear.sh](cmux/cmux_attention_clear.sh) |
| `cmux_attention_override` | Three-signal override when cmux's auto-state is wrong: mark the lane unread, rewrite its | [cmux/cmux_attention_override.sh](cmux/cmux_attention_override.sh) |
| `cmux_capture_pane` | Capture the last N lines a pane is showing (default 30). Optional 3rd arg = a surface ref for | [cmux/cmux_capture_pane.sh](cmux/cmux_capture_pane.sh) |
| `cmux_close_surface` | Close a single surface (tab/pane). See reference/cmux.md § Teardown. | [cmux/cmux_close_surface.sh](cmux/cmux_close_surface.sh) |
| `cmux_close_window` | Close an entire native cmux.app window (rare). See reference/cmux.md § Teardown. | [cmux/cmux_close_window.sh](cmux/cmux_close_window.sh) |
| `cmux_close_workspace` | Close a whole workspace (lane teardown, /kingdom:save). NOT tab-action close. See reference/… | [cmux/cmux_close_workspace.sh](cmux/cmux_close_workspace.sh) |
| `cmux_first_surface` | Resolve the first surface ref in a workspace, robust to the wrapped `{workspaces:[…]}` schema… | [cmux/cmux_first_surface.sh](cmux/cmux_first_surface.sh) |
| `cmux_identify` | Return the caller's cmux context as JSON (caller/focused workspace_ref + surface_ref, socket… | [cmux/cmux_identify.sh](cmux/cmux_identify.sh) |
| `cmux_list_pane_surfaces` | List the surface refs of the current/target panes (e.g. to grab a freshly-spawned tab's surf… | [cmux/cmux_list_pane_surfaces.sh](cmux/cmux_list_pane_surfaces.sh) |
| `cmux_list_panes` | List a workspace's panes as JSON. See reference/cmux.md § Inspect topology. | [cmux/cmux_list_panes.sh](cmux/cmux_list_panes.sh) |
| `cmux_list_workspaces` | List all workspaces (labels + refs). Used by guard_lane_workspace_exists to confirm a lane's | [cmux/cmux_list_workspaces.sh](cmux/cmux_list_workspaces.sh) |
| `cmux_new_split` | Add a split pane to a workspace. dir=left|right|up|down. Optional type (e.g. "browser") | [cmux/cmux_new_split.sh](cmux/cmux_new_split.sh) |
| `cmux_new_window` | Open a fresh cmux.app window; echo its UUID. Used by spawnWindow="new". See reference/cmux.m… | [cmux/cmux_new_window.sh](cmux/cmux_new_window.sh) |
| `cmux_new_workspace` | Create a workspace and echo its ref (workspace:N). Primitive — no rename/color/claude-launch | [cmux/cmux_new_workspace.sh](cmux/cmux_new_workspace.sh) |
| `cmux_notify` | Fire a cmux notification. Positional: ws title subtitle body [surface]. | [cmux/cmux_notify.sh](cmux/cmux_notify.sh) |
| `cmux_read_screen` | Read a workspace's current visible viewport (no scrollback). See reference/cmux.md § Read pa… | [cmux/cmux_read_screen.sh](cmux/cmux_read_screen.sh) |
| `cmux_rpc` | Low-level passthrough to cmux's documented RPC surface (e.g. surface.send_text, workspace.li… | [cmux/cmux_rpc.sh](cmux/cmux_rpc.sh) |
| `cmux_send` | Send text to a target AND submit it. Two calls: the text via `cmux send … -- "$text"`, | [cmux/cmux_send.sh](cmux/cmux_send.sh) |
| `cmux_send_key` | Press a real key/chord (Enter, C-l, C-c, …). Uses `cmux send-key`, NOT `cmux send`: | [cmux/cmux_send_key.sh](cmux/cmux_send_key.sh) |
| `cmux_set_state` | Live status-line update: set a workspace's sidebar description to "<emoji> <text>". | [cmux/cmux_set_state.sh](cmux/cmux_set_state.sh) |
| `cmux_tab_action` | Single wrapper for `cmux tab-action` — pass the action + its flags. Targets a surface, not a… | [cmux/cmux_tab_action.sh](cmux/cmux_tab_action.sh) |
| `cmux_tree` | Enumerate the full cmux topology (all windows/workspaces/panes). Extra args pass through. | [cmux/cmux_tree.sh](cmux/cmux_tree.sh) |
| `cmux_workspace_action` | Single wrapper for `cmux workspace-action` — pass the action + its flags. | [cmux/cmux_workspace_action.sh](cmux/cmux_workspace_action.sh) |

## browser (8)
| function | purpose | file |
|---|---|---|
| `browser_click` | Click an element by ref (from browser_snapshot). browser_click <ref> [surface]. | [cmux/browser_click.sh](cmux/browser_click.sh) |
| `browser_close` | Close a browser pane when done. browser_close <surface>. | [cmux/browser_close.sh](cmux/browser_close.sh) |
| `browser_eval` | Evaluate JS in the page and return the result — the escape hatch (screenshot via canvas, | [cmux/browser_eval.sh](cmux/browser_eval.sh) |
| `browser_fill` | Fill a form field by ref. browser_fill <ref> <value> [surface]. | [cmux/browser_fill.sh](cmux/browser_fill.sh) |
| `browser_open` | Open a built-in browser split pane in a workspace, navigate to <url>, echo its surface ref. | [cmux/browser_open.sh](cmux/browser_open.sh) |
| `browser_screenshot` | Best-effort PNG capture for review evidence. browser_screenshot <surface> <out_path>. | [cmux/browser_screenshot.sh](cmux/browser_screenshot.sh) |
| `browser_snapshot` | Snapshot the page's interactive accessibility tree (JSON with element refs) — the basis for | [cmux/browser_snapshot.sh](cmux/browser_snapshot.sh) |
| `browser_verify` | Composite UI smoke check any role can call: open <url>, wait, assert <expect> (text or | [cmux/browser_verify.sh](cmux/browser_verify.sh) |


## tmux (17) — FALLBACK backend (v0.41.0)
One micro-wrapper per tmux op (mirrors `cmux/`). `load_feature tmux` + `KINGDOM_BACKEND=tmux` routes `cmux_*`/`spawn_*` calls here. This table is the in-workspace catalog; the full prose cmux→tmux mapping lives in the kingdom repo's `TMUX-Guide.md` (a repo reading guide, not shipped into the workspace).

| function | purpose | file |
|---|---|---|
| `tmux_target` | Shared resolver: `tmux_session` (session name) + `tmux_target` (ref → `<session>:<slug>`). | [tmux/tmux_target.sh](tmux/tmux_target.sh) |
| `tmux_setup_session` | Create the kingdom session + cmux-like sidebar styling (status-bar window list). | [tmux/tmux_setup_session.sh](tmux/tmux_setup_session.sh) |
| `tmux_new_workspace` | New lane window; slug name + @emoji/@rolecolor/@state options. Mirror of cmux_new_workspace. | [tmux/tmux_new_workspace.sh](tmux/tmux_new_workspace.sh) |
| `tmux_send` | Send text + submit (`send-keys -l` + Enter). Mirror of cmux_send. | [tmux/tmux_send.sh](tmux/tmux_send.sh) |
| `tmux_send_key` | Send a raw key/chord. Mirror of cmux_send_key. | [tmux/tmux_send_key.sh](tmux/tmux_send_key.sh) |
| `tmux_set_state` | Set @state glyph WITHOUT renaming (stable target). Mirror of cmux_set_state. | [tmux/tmux_set_state.sh](tmux/tmux_set_state.sh) |
| `tmux_notify` | display-message + ⚠ glyph + durable king-inbox fallback. Mirror of cmux_notify. | [tmux/tmux_notify.sh](tmux/tmux_notify.sh) |
| `tmux_read_screen` | Visible viewport (`capture-pane -p`). Mirror of cmux_read_screen. | [tmux/tmux_read_screen.sh](tmux/tmux_read_screen.sh) |
| `tmux_capture_pane` | Last N lines incl. scrollback. Mirror of cmux_capture_pane. | [tmux/tmux_capture_pane.sh](tmux/tmux_capture_pane.sh) |
| `tmux_list_workspaces` | List lanes (the sidebar). Mirror of cmux_list_workspaces. | [tmux/tmux_list_workspaces.sh](tmux/tmux_list_workspaces.sh) |
| `tmux_close_workspace` | Teardown one lane (`kill-window`). Mirror of cmux_close_workspace. | [tmux/tmux_close_workspace.sh](tmux/tmux_close_workspace.sh) |
| `tmux_new_split` | Split a lane into a pane. Mirror of cmux_new_split. | [tmux/tmux_new_split.sh](tmux/tmux_new_split.sh) |
| `tmux_identify` | Caller context (`<session>:<window>.<pane>`). Mirror of cmux_identify. | [tmux/tmux_identify.sh](tmux/tmux_identify.sh) |
| `tmux_tab_action` | new-terminal-right → split pane; close → kill-pane (FALLBACK for cmux_tab_action). | [tmux/tmux_tab_action.sh](tmux/tmux_tab_action.sh) |
| `tmux_tree` | Window→pane topology for the R31 lane-readiness check (FALLBACK for cmux_tree). | [tmux/tmux_tree.sh](tmux/tmux_tree.sh) |
| `tmux_workspace_action` | set-color→@rolecolor, set-description→@statetext; rename/pin→no-op (FALLBACK for cmux_workspace_action). | [tmux/tmux_workspace_action.sh](tmux/tmux_workspace_action.sh) |
| `kingdom_use_tmux_backend` | Activator: redefines `cmux_*`/`spawn_*` to route to the tmux wrappers (auto-runs when KINGDOM_BACKEND=tmux). | [tmux/kingdom_use_tmux_backend.sh](tmux/kingdom_use_tmux_backend.sh) |
