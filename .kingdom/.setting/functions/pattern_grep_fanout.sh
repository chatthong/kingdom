#!/usr/bin/env bash
# kingdom function: pattern_grep_fanout

pattern_grep_fanout () {
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options no_nomatch 2>/dev/null  # zsh: unmatched glob passes literally instead of aborting "no matches found"; auto-reverts on return
  local key_term="$1" project_root="$2"

  # Fan out N Haiku scanners in parallel (capacity is unlimited per v0.15.0)
  # Each scanner reads a slice; aggregate findings.

  # Mandatory checks:
  grep -rln "$key_term" --include='*.{ts,tsx,js,py,sh,yml,yaml,json,md,env,env.example}' "$project_root"

  # Read every .env / .env.example in relevant subtree
  find "$project_root" -name '.env*' -o -name '.env.example' | xargs cat

  # Read all scripts/ files matching the topic
  ls "$project_root"/scripts/*"$key_term"* 2>/dev/null | xargs cat

  # Read lib/*-defaults.* for HOW-TO comments
  find "$project_root" -name '*defaults*.ts' -o -name '*defaults*.py' | xargs head -30

  # Read compose.*.yml for container env contracts
  find "$project_root" -name 'compose.*.yml' -o -name 'docker-compose*.yml' | xargs cat

  # Read project CLAUDE.md
  cat "$project_root/CLAUDE.md" 2>/dev/null
}
