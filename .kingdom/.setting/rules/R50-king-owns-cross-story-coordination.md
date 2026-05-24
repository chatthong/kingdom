### R50. King owns cross-story coordination — Tier 2 (v0.32.0+)

The King owns everything a Senior structurally cannot see (one Senior knows only its own story). Three duties, no path-locks:

1. **Prevent at assignment:** scope stories so their likely file-areas do not overlap; serialize two stories that must touch the same area (one pod there at a time); sequence dependent stories.
2. **Detect continuously:** consume the watchman's per-tick cross-story `git merge-tree` drift signal (the watchman scans across in-flight story branches, not just per-lane).
3. **Resolve at push:** when a Senior hands back a push-eligible story, check the drift signal and coordinate a rebase / re-merge of the story branch before opening the PR.
