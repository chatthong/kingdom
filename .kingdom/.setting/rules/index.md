# rules — index

> One rule per file in this folder. This index is the registry: read it first, then open only the rule files you need. Tier 1 is the authoritative iron-clad set (exactly 10).

# rules.md — Priority-tiered kingdom rules

> **Read this FIRST at session start, before everything else.**
> Three tiers; each tier dominates lower tiers when they conflict.
> When in doubt, default to the most conservative interpretation —
> the user would rather you ask 10 times than violate Tier 1 once.

---

## 🔒 Tier 1 cap — exactly 10 rules, no more (v0.31.0+)

Tier 1 is reserved for rules whose violation is **irreversible** (data loss / force-push / destructive op), **architecturally fatal** (the kingdom doesn't work as designed without them), or a **gateway** (without it, no other rule loads). To stay disciplined, **Tier 1 holds exactly 10 rules**. New iron-clad candidates must displace an existing Tier 1 rule, not add to the count.

| # | Rule | Why Tier 1 |
|---|---|---|
| **R1** | Push approval is single-shot + PR-specific | Irreversible remote action |
| **R2** | Never force-push to `main` / `develop` | Irreversible data loss |
| **R4** | Never edit or commit on `kingdom` branch | Overlay-model integrity; silent fatal if broken |
| **R5** | Destructive ops require explicit target confirmation | Irreversible data loss |
| **R14** | Reads ALL context at session start (rules → CLAUDE → memory → watchman) | Gateway — without it, no other rule actually loads |
| **R22** | Closer fires on EVERY task completion | Audit-trail integrity |
| **R30** | King is orchestrator-only — never executes task work | Architectural — whole kingdom assumes this |
| **R31** | Lane infrastructure spawned + verified BEFORE any dispatch | Dispatch fails silently without it |
| **R36** | Visible workspace progress within ~10s of `/kingdom:work` | User trust contract — prevents "stuck on fan-out" failure mode |
| **R42** | Every parallel fan-out uses `_bounded_wait`, never bare `wait` | Prevents kingdom-frozen failure mode |

**Demoted to Tier 2 in v0.31.0 (were Tier 1 prior):** R3, R6, R7, R8, R9, R10, R11, R12, R13, R15, R16, R23, R33, R34, R35, R37, R38, R39, R41. Their per-rule headings still carry their old `— Tier 1` suffix from prior versions; **this legend is authoritative** until those headings are swept in a future release.

Tier 1 = 10. Tier 2 ≈ 33. Tier 3 = 5. Total = 48 rules (R46-R50 added in v0.32.0 for story pods).

---

## 🔴 Tier 1 — IRON-CLAD (never violate, ever, no override)

Violating Tier 1 = kingdom is worse than running solo.


## Registry

| ID | Tier | Rule | File |
|---|---|---|---|
| R01 | 1 | Push approval is single-shot + PR-specific | [R01-push-approval-is-single-shot.md](R01-push-approval-is-single-shot.md) |
| R02 | 1 | Never force-push to `main` or `develop` | [R02-never-force-push-to-main.md](R02-never-force-push-to-main.md) |
| R03 | 2 | Never `--no-verify` to skip hooks | [R03-never-no-verify-to-skip.md](R03-never-no-verify-to-skip.md) |
| R04 | 1 | Never edit or commit on `kingdom` branch | [R04-never-edit-or-commit.md](R04-never-edit-or-commit.md) |
| R05 | 1 | Destructive ops require explicit confirmation | [R05-destructive-ops-require-explicit-confirmation.md](R05-destructive-ops-require-explicit-confirmation.md) |
| R06 | 2 | Never push local-only branches | [R06-never-push-local-only-branches.md](R06-never-push-local-only-branches.md) |
| R07 | 2 | Never paste personal notes verbatim | [R07-never-paste-personal-notes-verbatim.md](R07-never-paste-personal-notes-verbatim.md) |
| R08 | 2 | Pattern grep before implementation | [R08-pattern-grep-before-implementation.md](R08-pattern-grep-before-implementation.md) |
| R09 | 2 | `feature/<topic>` = `worker-N` tip byte-for-byte | [R09-feature-topic-worker-n-tip.md](R09-feature-topic-worker-n-tip.md) |
| R10 | 2 | Big work auto-delegated | [R10-big-work-auto-delegated.md](R10-big-work-auto-delegated.md) |
| R11 | 2 | Watchman is read-only on project source | [R11-watchman-is-read-only.md](R11-watchman-is-read-only.md) |
| R12 | 2 | Every per-task artifact carries the lane in segment 2 | [R12-every-per-task-artifact-carries.md](R12-every-per-task-artifact-carries.md) |
| R13 | 2 | Two-tier gate | [R13-two-tier-gate.md](R13-two-tier-gate.md) |
| R14 | 1 | King reads ALL context at session start | [R14-king-reads-all-context-at.md](R14-king-reads-all-context-at.md) |
| R15 | 2 | Mandatory kingdom merge before push prompt | [R15-mandatory-kingdom-merge-before-push.md](R15-mandatory-kingdom-merge-before-push.md) |
| R16 | 2 | King never sits on un-gated sentinels | [R16-king-never-sits-on-un.md](R16-king-never-sits-on-un.md) |
| R17 | 3 | Role emoji vocabulary | [R17-role-emoji-vocabulary.md](R17-role-emoji-vocabulary.md) |
| R18 | 3 | Workspace colours | [R18-workspace-colours.md](R18-workspace-colours.md) |
| R19 | 3 | Description glyphs (live workspace state) | [R19-description-glyphs-live-workspace-state.md](R19-description-glyphs-live-workspace-state.md) |
| R20 | 3 | Slash command names | [R20-slash-command-names.md](R20-slash-command-names.md) |
| R21 | 3 | Branch namespace (reserved) | [R21-branch-namespace-reserved.md](R21-branch-namespace-reserved.md) |
| R22 | 1 | The closer (4-step or 5-step) MUST fire on EVERY task completion | [R22-the-closer-4-step.md](R22-the-closer-4-step.md) |
| R23 | 2 | Task file (Step 0) MUST exist BEFORE any sub-agent dispatch or code edit | [R23-task-file-step-0-must.md](R23-task-file-step-0-must.md) |
| R24 | 2 | Task file is continuously updated, NEVER write-once | [R24-task-file-is-continuously-updated.md](R24-task-file-is-continuously-updated.md) |
| R25 | 2 | Update BOTH kingdom task file AND project task-ledger | [R25-update-both-kingdom-task-file.md](R25-update-both-kingdom-task-file.md) |
| R26 | 2 | After every PR merge, King resyncs kingdom from base | [R26-after-every-pr-merge-king.md](R26-after-every-pr-merge-king.md) |
| R27 | 2 | Watchman owns PR-number backfill + close-suffix maintenance | [R27-watchman-owns-pr-number-backfill.md](R27-watchman-owns-pr-number-backfill.md) |
| R28 | 2 | Parallel by default for scan + non-conflicting edit | [R28-parallel-by-default-for-scan.md](R28-parallel-by-default-for-scan.md) |
| R29 | 2 | After every successful push, kingdom MUST be reset to `origin/develop` tip | [R29-after-every-successful-push-kingdom.md](R29-after-every-successful-push-kingdom.md) |
| R30 | 1 | King is ORCHESTRATOR ONLY — never executes task work itself | [R30-king-is-orchestrator-only-never.md](R30-king-is-orchestrator-only-never.md) |
| R31 | 1 | Lane infrastructure MUST be spawned + verified BEFORE any dispatch | [R31-lane-infrastructure-must-be-spawned.md](R31-lane-infrastructure-must-be-spawned.md) |
| R32 | 2 | "Staged / waiting / dormant" is co-worker-ONLY — workers auto-claim | [R32-staged-waiting-dormant-is-co.md](R32-staged-waiting-dormant-is-co.md) |
| R33 | 2 | King MUST read existing task state BEFORE dispatching new tasks | [R33-king-must-read-existing-task.md](R33-king-must-read-existing-task.md) |
| R34 | 2 | Tier-1 rules override memory notes | [R34-tier-1-rules-override-memory.md](R34-tier-1-rules-override-memory.md) |
| R35 | 2 | King never copies uncommitted changes between worktrees | [R35-king-never-copies-uncommitted-changes.md](R35-king-never-copies-uncommitted-changes.md) |
| R36 | 1 | Visible workspace progress BEFORE any processing | [R36-visible-workspace-progress-before-any.md](R36-visible-workspace-progress-before-any.md) |
| R37 | 2 | Heavy processing runs IN lane workspaces, not in King's session | [R37-heavy-processing-runs-in-lane.md](R37-heavy-processing-runs-in-lane.md) |
| R38 | 2 | Sub-agent spawns are TABS or LANE DISPATCH — never in-process Agent() | [R38-sub-agent-spawns-are-tabs.md](R38-sub-agent-spawns-are-tabs.md) |
| R39 | 2 | Watchman runs fully autonomously | [R39-watchman-runs-fully-autonomously.md](R39-watchman-runs-fully-autonomously.md) |
| R40 | 2 | Watchman Haiku fan-out cap per tick | [R40-watchman-haiku-fan-out-cap.md](R40-watchman-haiku-fan-out-cap.md) |
| R41 | 2 | Auto-discover and use the right skill BEFORE any work | [R41-auto-discover-and-use.md](R41-auto-discover-and-use.md) |
| R42 | 1 | Every parallel fan-out uses `_bounded_wait`, never bare `wait` | [R42-every-parallel-fan-out-uses.md](R42-every-parallel-fan-out-uses.md) |
| R43 | 2 | Job-done closing actions are agent-owned | [R43-job-done-closing-actions-are.md](R43-job-done-closing-actions-are.md) |
| R44 | 2 | After user `go`, King executes — no further mode questions | [R44-after-user-go-king-executes.md](R44-after-user-go-king-executes.md) |
| R45 | 2 | Haiku-army doc orientation before big-picture work | [R45-haiku-army-doc-orientation-before.md](R45-haiku-army-doc-orientation-before.md) |
| R46 | 2 | Story integration branch | [R46-story-integration-branch.md](R46-story-integration-branch.md) |
| R47 | 2 | Three-tier gate | [R47-three-tier-gate.md](R47-three-tier-gate.md) |
| R48 | 2 | Senior is the SOLE within-story reviewer; King never re-reviews story internals | [R48-senior-is-the-sole-within.md](R48-senior-is-the-sole-within.md) |
| R49 | 2 | Senior owns within-story integration-conflict resolution | [R49-senior-owns-within-story-integration.md](R49-senior-owns-within-story-integration.md) |
| R50 | 2 | King owns cross-story coordination | [R50-king-owns-cross-story-coordination.md](R50-king-owns-cross-story-coordination.md) |

## Conflict resolution

When tiers conflict, **higher tier wins**:

| Tier | Beats |
|---|---|
| Tier 1 | Tier 2 + Tier 3 |
| Tier 2 | Tier 3 |
| Tier 3 | (nothing — lowest priority) |

Within a tier, the more-specific rule wins (e.g., R1 push specifics over a generic auth confirmation rule).

When in doubt: **default to the most conservative interpretation.** the user would rather you ask 10 times than violate Tier 1 once.

---

## Versioning

This document is part of the kingdom plugin. New rules earn a number; old rule numbers are never reused even if the rule is retired (mark `[RETIRED]` instead). Each tier's numbering is global so cross-references stay stable: `see R1` always means R1, regardless of file location.
