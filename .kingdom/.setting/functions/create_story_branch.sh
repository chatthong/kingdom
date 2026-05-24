#!/usr/bin/env bash
# kingdom function: create_story_branch

create_story_branch () {
  # Inputs: $1 = PROJ, $2 = story id, $3 = base (default develop), $4 = senior lane (default senior-1)
  # Output: the branch name (story/<id>). The Senior's worktree is left checked out on it.
  local proj="$1" id="$2" base="${3:-develop}" senior="${4:-senior-1}"
  local branch="story/$id" wt="$proj/.worktrees/$senior"
  git -C "$proj" fetch origin "$base" >/dev/null 2>&1
  if [ -d "$wt" ]; then
    git -C "$wt" checkout -B "$branch" "origin/$base" >/dev/null 2>&1
  else
    git -C "$proj" worktree add -B "$branch" "$wt" "origin/$base" >/dev/null 2>&1
  fi
  echo "$branch"
}
