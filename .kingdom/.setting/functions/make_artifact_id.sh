#!/usr/bin/env bash
# kingdom function: make_artifact_id

make_artifact_id() {     # usage: make_artifact_id <task-type> <sub-agent> <slug>
  printf '%s__%s__%s__%s' \
    "$(date -u +%Y-%m-%dT%H%MZ)" "$1" "$2" "$3"
}
