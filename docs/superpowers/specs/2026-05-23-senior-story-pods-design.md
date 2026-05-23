# Design: Senior role + story-pod integration branches (Pods v1)

**Date:** 2026-05-23
**Status:** Approved for spec review
**Target version:** v0.32.0
**Scope:** One feature, shipped together: a new `Senior-N` role, a configurable story integration branch, a three-tier gate, and delegated (King + Senior) dispatch.

---

## 1. Goal

Let multiple workers attack one unit of work (a story / milestone / issue) in parallel, get that unit reviewed as a whole, and merge it as a single PR. Optimize for quality AND speed by specializing two orchestration roles so neither bottlenecks the other and no review work is done twice.

Two linked additions:

1. **`Senior-N`**: an Opus per-story sub-orchestrator and reviewer. It owns a pod of workers, assembles their work on a local story branch, reviews it in an autonomous loop, and hands a push-eligible story back to the King.
2. **Story integration branch**: a local branch that collects parallel worker branches via merge, is reviewed in place, and reaches origin only as the final `story/<id> -> develop` PR.

---

## 2. Background: what exists today

- **Roles:** King (Opus, orchestrator + sole pusher + human chat), worker-N (Opus, autonomous lane), co-worker-N (Opus, paired), watchman-N (Sonnet, autonomous `/loop` doing per-lane review + CVE/conflict/hygiene scans + PR backfill), sub-agents.
- **Branch model:** lane branches are local-only (R6); the `kingdom` branch is an ephemeral working-tree overlay (never commits, R4/R29); `feature/<topic>` is byte-for-byte from a worker tip (R9) and is the only thing that reaches origin.
- **Gate:** two tiers. Tier-1 = lane typecheck; Tier-2 = tests/smoke/lint on the kingdom overlay. Push requires Tier-2 pass plus the human's literal "push" (R1).
- **Dispatch:** the King is the sole dispatcher (R30). Work runs only in visible lane workspaces (R31, R36, R37).

### What changes

- The ephemeral `kingdom` overlay is **not** how multi-worker stories integrate anymore. A story uses a real local branch with real merge commits. The solo `worker -> feature/<topic>` path stays for quick one-worker tasks.
- A third gate tier (Senior review) is added.
- Dispatch is delegated: King assigns stories to Seniors; Seniors dispatch sub-tasks to their own pod.

---

## 3. Identity-guardrail check

The 6 kingdom guardrails (from `PLAN.md`) all hold:

1. **In-terminal, no new runtime:** still markdown + bash + Claude Code + git. No daemon.
2. **Human-gated push:** unchanged. Only the King pushes, only on the literal "push" (R1). Seniors mark push-eligible; they never push.
3. **Audit-first:** story branches add real merge history; Senior reviews are greppable `SENIOR_*` reports; sentinels and task files unchanged.
4. **Single-user, opinionated cap:** `sanityCap` now bounds King + Seniors + workers + co-workers + watchmen together.
5. **Claude-Code-native:** Seniors are Claude sessions in cmux/tmux lanes, same as every other role.
6. **Domain-agnostic:** the integration "unit" is configurable text; `gate.*` stays arbitrary bash.

---

## 4. Roles and shape

### Senior-N (new, Opus)

- Role doc: `.kingdom/.setting/seniors.md`.
- A per-story sub-orchestrator and the **sole reviewer of its story's internals**.
- Gets its own cmux workspace (color: Teal) and a worktree at `.worktrees/senior-N/` checked out on its current `story/<id>`.
- Runs a `/loop` scoped to its story (like the watchman, but Opus and story-scoped).
- Counts against `sanityCap` alongside workers, co-workers, and watchmen.

### kingdom.json additions

```jsonc
"shape": {
  "workers": 3,
  "co-workers": 1,
  "watchman": 1,
  "seniors": 1,            // NEW
  "sanityCap": 10
},
"integration": {           // NEW block
  "enabled": true,
  "unit": "story",         // "story" | "milestone" | "issue": the integration granularity
  "branchPattern": "story/<id>",
  "gateOnStory": true,     // run Tier-2 on the story branch
  "reviewLoopCap": 3       // max Senior review->fix->re-review cycles before escalating to human
},
"seniors": [
  { "slug": "senior-1", "model": "opus" }
],
"cmux": { "workspaceColors": { "senior": "Teal" } }
```

---

## 5. Branch model and story lifecycle

### Branches

| Branch | Reaches origin? | Notes |
|---|---|---|
| `worker-N` | no | local lane branch, unchanged (R6) |
| `story/<id>` | only as the final PR | local integration branch, lives in the Senior's worktree, branched off `develop` |
| `feature/<topic>` | yes (PR) | retained for solo one-worker tasks (not everything is a pod) |

### Lifecycle

1. King reads the task-ledger, picks stories, **partitions** their file-scopes to avoid overlap, **sequences** dependencies, and allocates a pod (Senior + N workers) within `sanityCap`.
2. King creates `story/<id>` off `develop`, assigns it to a Senior, and passes any cross-cutting conventions.
3. Senior splits the story into sub-tasks and dispatches one per worker (visible `cmux send`, in-pod only).
4. Each worker does its sub-task on `worker-N`, passes **Tier-1** (lane typecheck), signals done.
5. Senior **merges** that worker branch into `story/<id>`, resolving within-story integration conflicts.
6. When all sub-tasks are merged, Senior runs **Tier-2** (tests/smoke/lint) on `story/<id>`.
7. Senior runs the **deep review loop** (sole reviewer of internals): fan out Sonnet/Haiku reviewers per touched area, Opus-synthesize. Issues route a fix-task back to the owning worker, which re-merges; Senior re-reviews. Loop up to `reviewLoopCap`, then escalate to the human if still failing.
8. Clean: Senior writes `SENIOR_<UTC>__story-<id>.md` plus a push-eligible sentinel, hands the story back to the King.
9. King runs a cross-story conflict check (not a code re-review), then offers the push-prompt.
10. On the human's "push": King carves the PR `story/<id> -> develop`, pushes, opens the PR. Post-merge R26-style resync.

### Gate becomes three tiers

`worker Tier-1` -> `story-branch Tier-2` -> `Senior review loop` -> `human push (R1)`.

---

## 6. King vs Senior division (quality + speed via specialization)

The two roles own **different, non-overlapping** quality concerns. No review is done twice; no concern is unowned.

| Concern | King (Opus, human chat, sole pusher) | Senior-N (Opus, per story) |
|---|---|---|
| Scope | all stories, the spaces between pods | one story, end-to-end |
| Plan | pick stories, partition scopes, sequence dependencies, allocate pods within `sanityCap` | split its story into sub-tasks |
| Dispatch | assign story to Senior (+ cross-cutting conventions) | dispatch sub-tasks to its own workers (visible, in-pod only) |
| Integration | none | merge worker branches into `story/<id>`, resolve within-story conflicts |
| Review | never re-reviews story code | sole reviewer of story internals (deep loop) |
| Cross-story | resolve drift between pods at push, fed by watchman scan | none (cannot see other stories) |
| Release | cross-story check, push-prompt, human-gated PR | mark push-eligible, hand back |

The only serial bottleneck left is the human push, which is intentionally serial.

---

## 7. Delegated dispatch and the R30 amendment

R30 today: "King is the sole dispatcher." This relaxes to:

> **R30 (amended):** The King and Seniors dispatch. A Senior dispatches only to the workers in its own pod, and only through a visible lane workspace (`cmux send` to a real worker workspace). Workers never dispatch. The King assigns workers to pods; a worker belongs to at most one pod at a time.

**Safety:** the reason R30 existed (work happening invisibly outside lanes) is preserved by `guard_senior_dispatch_scope`, a hard gate that refuses a Senior dispatch unless (a) the target worker is in the Senior's pod and (b) the target has a live, visible workspace. This keeps the audit trail and visibility guarantees of R31/R36/R37 intact while allowing the delegation. The Tier-1 rule count stays at 10 (R30 is amended in place, no new Tier-1 rules).

---

## 8. Cross-story conflict handling (hybrid)

No path-locks (kingdom keeps workers as generic capacity). Three points of defense:

1. **Prevent at assignment:** the King scopes stories so their likely file-areas do not overlap, and serializes two stories that must touch the same area (one pod at a time there).
2. **Detect continuously:** the watchman gains one duty: a per-tick `git merge-tree` scan **across in-flight story branches** (not just per-lane), feeding the King a cross-story drift signal.
3. **Resolve at push:** when a Senior hands back a push-eligible story, the King checks the drift signal and coordinates a rebase / re-merge of the story branch before opening the PR.

---

## 9. Components: file manifest

### New files

| File | Purpose |
|---|---|
| `.kingdom/.setting/seniors.md` | Senior role spec: pod ownership, story-branch create + merge-in, review loop, in-pod dispatch, conflict resolution, gate authority, `SENIOR_*` closer/sentinel conventions |
| `docs/story-pods.md` | Long-form doc: the pod model, three-tier gate, branch lifecycle, pod-vs-solo guidance |
| `.kingdom/.setting/cards/senior-verdict.md` | Card for the Senior review result (clean / fixes-routed, loop iteration) |
| `.kingdom/.setting/cards/story-assembled.md` | Card for "all sub-tasks merged + Tier-2 result" |

### Edited files: role specs and rules

| File | Change |
|---|---|
| `rules.md` | Add R46 (story integration branch), R47 (three-tier gate), R48 (Senior sole within-story reviewer; King never re-reviews), R49 (Senior owns within-story conflict resolution), R50 (King owns cross-story: partition, sequence, resolve-at-push). **Amend R30** (delegated dispatch). Refresh the Tier-1 cap legend (count stays 10) |
| `_primitives.md` | New helpers: `create_story_branch`, `spawn_senior_workspace`, `spawn_senior_loop`, `senior_merge_worker_into_story`, `run_tier2_on_story`, `senior_review_tick`, `guard_senior_dispatch_scope`, `watchman_cross_story_scan` |
| `kings.md` | King assigns stories to Seniors, partitions/sequences, resolves cross-story drift, owns the story-PR push; stops directly orchestrating story workers |
| `workers.md` | Workers can belong to a pod: receive sub-tasks + fix-tasks from a Senior, signal done (Senior merges), no longer always report to King |
| `watchmans.md` | New duty: per-tick cross-story `git merge-tree` scan. Clarify watchman (per-lane mechanical) vs Senior (story review) boundary |
| `git.md` | Document `story/<id>` in the branch model |
| `cmux.md` | Senior workspace color + story worktree layout |
| `index.md` | Add `seniors.md` to the role router |

### Edited files: commands

| File | Change |
|---|---|
| `commands/work.md` | Spawn Seniors in Step 0.4; resolve stories from the task-ledger unit; assign stories to Seniors + create story branches; Senior-driven pod dispatch; three-tier gate poll loop; push story PRs |
| `commands/init.md` | Add `seniors.md` to the `.setting` copy list; scaffold the `seniors` / `integration` blocks; senior color |
| `commands/save.md` | Snapshot Senior pods + story-branch state to `state.json`; close senior workspaces |
| `commands/self-care.md` | Check senior / integration config presence |

### Edited files: config, cards, top-level

| File | Change |
|---|---|
| `.kingdom/templates/kingdom.json.template` | Add `shape.seniors`, the `integration` block, `seniors[]`, senior color |
| `cards/spawn-complete.md`, `daily-status.md`, `dispatch-plan.md`, `dispatch-brief.md`, `scaffold-success.md`, `doctor-report.md` | Render the Senior role / story unit / three-tier gate where roles/shape/gate appear |
| `.claude-plugin/plugin.json` + `marketplace.json` | Version bump to v0.32.0 |
| `README.md` | Roles table + architecture: add Senior, story pods, three-tier gate (dash-free) |
| `CHANGELOG.md` | v0.32.0 entry |
| `CLAUDE.md` | New architectural decisions (story pods, delegated dispatch, three-tier gate), role roster, directory layout, open threads |

---

## 10. Data flow and artifacts

- **Story task file:** `.kingdom/<project>/tasks/<UTC>__senior-N__<story-id>.md`, tracking the pod's sub-tasks and the review loop. Workers keep their own per-sub-task files (`worker-N`).
- **Senior review report:** `<project>/docs/test-reports/SENIOR_<UTC>__story-<id>.md` (follows the `LANE_/WATCH_/KING_` prefix convention; segment-2 = role).
- **Push-eligible sentinel:** `<LOGS>/done/<UTC>__senior-N__<story-id>.flag`.
- **state.json (for `/kingdom:save`):** records each pod (Senior, its workers, the story branch + its merged sub-tasks, review-loop iteration) so the next `/kingdom:work` respawns pods intact.

---

## 11. Error handling and edge cases

- **Senior stalls / crashes:** King detects no progress within a budget; reassigns the story to a fresh Senior (the story branch + merged work survive on disk) or surfaces to the human.
- **Worker stalls in a pod:** Senior detects, re-dispatches once, then flags the sub-task blocked to the King.
- **Unresolvable merge conflict on the story branch:** Senior marks the story blocked, writes the conflict detail, escalates to the King/human; no silent skip.
- **Review loop does not converge:** capped at `reviewLoopCap` (default 3); on exhaustion the Senior escalates the story to the human with the outstanding findings rather than looping forever.
- **`sanityCap` exhausted:** King cannot allocate all desired pods; it queues stories and runs as many pods as fit, starting more when lanes free up.
- **Story dependency:** King sequences dependent stories; a dependent pod starts only after its prerequisite story merges.
- **Cross-story drift found late:** King coordinates a rebase / re-merge of the later story branch before its PR.

---

## 12. Testing and verification

The plugin ships specs, not runtime code, so verification is behavioral plus consistency:

1. **`/kingdom:self-care`** passes with the new `seniors` / `integration` config keys.
2. **`/kingdom:init`** scaffolds the new `kingdom.json` blocks and copies `seniors.md`.
3. **Consumer dry-run:** `/kingdom:work` on a test project with `seniors=1` and a story carrying 2 sub-tasks. Verify, in order: story branch created off develop; Senior dispatches 2 workers in visible workspaces; worker branches merge into the story branch; Tier-2 runs on the story branch; the Senior review loop runs and routes at least one fix; push-eligible sentinel + `SENIOR_*` report written; King offers the push; PR `story/<id> -> develop` opens on the human's "push".
4. **Negative checks:** `guard_senior_dispatch_scope` refuses a Senior dispatch to a non-pod worker and to a worker without a live workspace.
5. **Rule consistency:** Tier-1 cap legend still lists exactly 10; all cross-references to R30 updated.
6. **Pre-ship audit:** the kingdom's own 10-Haiku-army audit pass before tagging v0.32.0.

---

## 13. Out of scope (YAGNI)

- Nested integration hierarchy (issue -> story -> milestone branches). One configurable level only.
- Shared worker pool across pods (a worker belongs to one pod at a time).
- Pushing story branches to origin for remote review (review stays in-place; only the final PR reaches origin).
- King re-reviewing story internals (explicitly rejected: that is redundant review).
- Senior auto-pushing (never; push is King + human only).
