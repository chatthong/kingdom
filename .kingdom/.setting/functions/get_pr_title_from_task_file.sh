#!/usr/bin/env bash
# kingdom function: get_pr_title_from_task_file

# Alias used by carve_and_push_feature; same logic as extract_pr_title_from_task_file.
get_pr_title_from_task_file () { extract_pr_title_from_task_file "$@"; }
