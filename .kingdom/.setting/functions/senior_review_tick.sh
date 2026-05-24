#!/usr/bin/env bash
# kingdom function: senior_review_tick

senior_review_tick () {
  # Inputs: $1 = senior worktree (story branch), $2 = base (default develop)
  # Outline (the Senior, Opus, executes the judgment):
  #   1. Touched areas:  git -C "$wt" diff --name-only "origin/$base"
  #   2. Fan out Sonnet/Haiku reviewers per area, bounded by _bounded_wait (R42):
  #      coherence across sub-tasks, acceptance criteria, architecture seams, doc cross-check (R45 digest).
  #   3. Synthesize as Opus. For each issue: route a fix-task to the OWNING worker
  #      (guard_senior_dispatch_scope), await its re-merge (senior_merge_worker_into_story), re-review.
  #   4. Cap at kingdom.json.integration.reviewLoopCap. On exhaustion, escalate to the human.
  # Returns: 0 clean (push-eligible) | 1 fixes routed (loop again) | 2 escalate (cap hit / blocked)
  : # see seniors.md § "The review (Tier-3) in detail"
}
