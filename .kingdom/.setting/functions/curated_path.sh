#!/usr/bin/env bash
# kingdom function: curated_path

curated_path() {         # usage: curated_path <logs_dir> <ID>
  printf '%s/%s.md' "$1" "$2"
}
