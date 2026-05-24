#!/usr/bin/env bash
# kingdom function: raw_path

raw_path() {             # usage: raw_path <logs_dir> <ID> <sub-agent> <worker-slug>
  printf '%s/raw/%s__%s-%s.md' "$1" "$2" "$3" "$4"
}
