# ⚙️ Configuration

> Part of the [kingdom](../README.md) docs.

## Pick your shape, at `/kingdom:work` (not `init`)

`/kingdom:init <project>` takes **no shape flags** (v0.33.0): it just scaffolds `kingdom.json` with defaults. You choose the shape **per session** at `/kingdom:work`, or change the persistent default by editing `kingdom.json.shape`. Two ways to set it on a run:

- **per-role:** `worker=N co-worker=N watchman=N senior=N` (singular shown; plural like `workers=` is also accepted)
- **total budget:** `lane=N` — the King auto-composes the split (workers + 1 watchman; story pods when `senior=K` is pinned)

### 🏢 Mid-size project, the default

```bash
/kingdom:work my-app
```

Uses the `kingdom.json` defaults (`worker=3 co-worker=1 watchman=1 senior=1`). One worker per component (backend / frontend / ops), one paired lane reserved for you, one watchman over everything, one Senior available to lead a story pod. **Start here unless you have a specific reason not to.**

### 🏭 Large project, more lanes

```bash
/kingdom:work my-app worker=5 co-worker=2 watchman=1
```

Five autonomous workers (e.g., backend / frontend / mobile / infra / docs), two paired tracks, one watchman. Useful when one developer is steering many concurrent threads.

### 🚀 Solo side-project, single autonomous lane

```bash
/kingdom:work my-app worker=1 co-worker=0 watchman=0
```

One worker, no monitoring, no paired track. Best for rapid prototypes or one-person repos.

### 🎨 UI-heavy day, everything paired

```bash
/kingdom:work my-app worker=0 co-worker=2 watchman=1
```

No autonomous work. Every lane is paired with you. One watchman keeps you informed of anything moving on `develop`.

### 🎓 Parallel story pods, let the King compose

```bash
/kingdom:work my-app lane=12 senior=2
```

A total budget of 12 lanes; the King pins 2 Seniors (2 story pods) and fills the rest with workers. Each pod's story is reviewed as a unit and ships as one PR. (`/kingdom:work my-app lane=8` with no pins lets the King pick everything.)

## What each shape parameter does

| Param | Role | Default | What it spawns |
|---|---|---|---|
| `worker=N` | Autonomous task lanes | `3` | `worker-1` … `worker-N`, each picks a sub-task and works it without your involvement |
| `co-worker=N` | Paired lanes for hands-on work | `1` | `co-worker-1` … , dormant by default; activate with *"pair on co-worker-1"* |
| `watchman=N` | Continuous monitors | `1` | `watchman-1` … , each runs `/loop` to track `origin/develop` + babysit open PRs |
| `senior=N` | Per-story sub-orchestrator + reviewer | `1` | `senior-1` … , each owns a worker pod on one `story/<id>` branch and reviews it as a unit |
| `lane=N` | Total-lane budget | — | the King auto-composes worker/co-worker/watchman/senior to fill N, honoring any pin |

Plural forms (`workers=`, `seniors=`, …) are accepted; the docs show singular. Soft cap: total lanes ≤ `sanityCap` (default `10`). To make a shape the persistent default, edit `kingdom.json.shape`.

## What happens when you run `/kingdom:init <project>`

1. **Creates** `.kingdom/<project>/kingdom.json` from the template, with default shape (no flags, v0.33.0).
2. **Creates** `.kingdom/<project>/{logs,tasks}/` directories, the audit-trail homes.
3. **Prints** the resulting JSON for you to review.

**Scaffold ≠ launch.** `/kingdom:init <project>` only scaffolds; it never reads tasks or spawns lanes. Before running `/kingdom:work my-app`, open the generated `kingdom.json` and customise:

- `gate.*` command lists: what King runs before every push. Keys are arbitrary. Dev stacks use `typecheck`/`tests`/`smoke`/`lint`; finance work might use `validate`/`audit`; science work might use `reproduce`/`peer-review`. Rename / add / remove freely.
- `git.base`: your PR target branch (default `develop`; many repos use `main`).

That's the entire customisation surface. **Workers are generic capacity**, no preset focus or path locks. The King assigns each task at dispatch time (see [`king.md`](../.kingdom/.setting/roles/king.md) → "Dispatch brief schema"), so `worker-1` and `worker-2` are interchangeable. Same worker can do backend today, frontend tomorrow, financial-model audit the day after.

> **Updating an existing project's config:** prefer **`/kingdom:update`** — it additively merges any new schema keys into your `kingdom.json` while keeping every value you set (and preserves all runtime + memory). Re-running **`/kingdom:init <project>`** instead offers a `merge` / `overwrite` / `keep` prompt (default `merge`, which also preserves your values; `overwrite` writes a timestamped `.bak` first). Either way your `gate.*` customisations are safe — no need to back them up manually.

## Configure your project

`/kingdom:init <project>` creates `.kingdom/<project>/kingdom.json`. Edit it before running `/kingdom:work`:

```json
{
  "shape": { "workers": 3, "co-workers": 1, "watchman": 1, "seniors": 1, "sanityCap": 10 },
  "welcome": { "userName": "", "weather": true },
  "subAgents": { "parallelTarget": 10 },
  "git":   { "base": "develop", "integrationBranch": "kingdom", "pushPolicy": "always-ask", "branchNamingPattern": "feature/<topic>" },
  "integration": { "enabled": true, "unit": "pod", "branchPattern": "story/<id>", "gateOnStory": true, "reviewLoopCap": 3 },
  "workers":   [ { "slug": "worker-1", "model": "opus" },
                 { "slug": "worker-2", "model": "opus" },
                 { "slug": "worker-3", "model": "opus" } ],
  "coworkers": [ { "slug": "co-worker-1", "model": "opus" } ],
  "watchmen":  [ { "slug": "watchman-1", "model": "sonnet", "cadence": "dynamic", "docsAudit": true } ],
  "seniors":   [ { "slug": "senior-1", "model": "opus" } ],
  "gate": {
    "typecheck": ["pnpm -r typecheck"],
    "tests":     ["pnpm -r test", "pytest -q"],
    "smoke":     ["bash scripts/smoke.sh"],
    "lint":      ["pnpm -r lint", "ruff check ."]
  }
}
```

The full template also carries a `cmux` block (sidebar colours, watchman split, and the pre-warmed sub-agent pool — `cmux.subAgentPool.model` is a single model string, e.g. `"sonnet"`, read by `spawn_pool_slot`) and a `watchman` block (shown below). See [`.kingdom/templates/kingdom.json.template`](../.kingdom/templates/kingdom.json.template) for every key with inline comments.

The King reads this at spawn-time (invoked by `/kingdom:work`) to:

- Spawn the right number of lanes (`shape` counts)
- Pick a model per lane (Opus for masters, Sonnet for watchman, override if you want cheaper)
- Run YOUR exact gate commands inside each lane's worktree before any PR

> **Workers are generic.** No per-worker `focus` or `ownsPaths`. The King assigns scope at dispatch time (any worker can do any task; same worker does backend today, frontend tomorrow). `gate.*` keys are arbitrary, rename for non-dev domains (`validate`/`audit` for finance, `reproduce`/`peer-review` for science).

### Skill routing

**Skill routing.** The workspace copy of [`.kingdom/.setting/reference/skill-routing.md`](../.kingdom/.setting/reference/skill-routing.md) is the canonical keyword → skill mapping table. Add project-specific entries (Vue/Nuxt keywords pointing to your Vue skill, internal DSL keywords pointing to org-specific skills, etc). Matcher reads workspace copy at every dispatch — no King restart needed.

## Watchman config

Watchman behaviour is controlled by the `watchman` block inside `kingdom.json`:

```json
{
  "watchman": {
    "haikuCapPerTick": 5,
    "retentionDays": 7,
    "cadence": { "churnMin": 5, "quietMin": 15, "deepQuietMin": 30, "deepQuietStreak": 3 },
    "duties": {
      "codeReview":     true,
      "cveScan":        true,
      "conflictScan":   true,
      "gitHygiene":     true,
      "crossStoryScan": true,
      "seqCollision":   true,
      "configParity":   true,
      "missingTests":   true
    }
  }
}
```

### `haikuCapPerTick`

Maximum number of Haiku sub-agents a single watchman tick may spawn. Default: `5`. Max: `10`. Prevents runaway fan-out on large repos with many open PRs. Raise it for overnight unattended runs; lower it if you want tighter token spend.

### `retentionDays`

Sweep window (in days) for the watchman's `WATCH_*` artifacts (per-tick digests and notes). Anything older than this is pruned at the start of each tick, so the audit trail self-trims instead of growing without bound. Default: `7`. Lower it for tighter disk use; raise it to keep a longer history.

### `cadence.*`

Dynamic tick pacing (minutes between ticks). The watchman speeds up when the repo is churning and backs off when it's quiet:

| Key | Default | When it applies |
|---|---|---|
| `churnMin` | `5` | `develop` / open PRs are actively moving — tick frequently |
| `quietMin` | `15` | calm repo — tick less often |
| `deepQuietMin` | `30` | longer interval reserved for the heavier change-gated duties so they don't re-run every tick on a still repo |
| `deepQuietStreak` | `3` | consecutive zero-finding, no-change ticks required before the watchman drops to the `deepQuietMin` cadence; the first sign of life resets the streak |

### `duties.*` toggles

Each duty is `true` (enabled) by default. Set to `false` to disable for a project. The CVE, git-hygiene, sequence-collision, config-parity, and missing-tests duties are **change-gated** — they only re-run when their inputs (manifests, branches, config, test files) actually changed since the last tick, so they cost nothing on a still repo:

| Key | What the watchman does when enabled |
|---|---|
| `codeReview` | Babysits open PRs: posts a nudge comment if a PR has been waiting > 24 h with no review activity |
| `cveScan` | Scans `package.json` / `requirements.txt` / `go.mod` for known CVEs via `npm audit` / `pip-audit` / `govulncheck` (change-gated) |
| `conflictScan` | Checks whether any in-flight worker branch has diverged enough from `develop` to risk a conflict on merge |
| `gitHygiene` | Flags stale branches (no commit in > 7 days), orphan worktrees, and missing sentinel flags (change-gated) |
| `crossStoryScan` | Feeds the King's cross-story coordination (R50): flags drift or overlap between parallel story pods |
| `seqCollision` | Detects two lanes about to touch the same sequence point / ordered resource (change-gated) |
| `configParity` | Cross-checks that each project's `kingdom.json` matches the plugin's current schema and flags drift (change-gated) |
| `missingTests` | Flags changed source files that ship without a corresponding test (change-gated) |

## Sub-agent fan-out

The `subAgents` block tunes parallel sub-agent fan-out:

```json
{
  "subAgents": { "parallelTarget": 10 }
}
```

### `parallelTarget`

Per-project soft ceiling for how many sub-agents any single fan-out spawns in parallel (R51). Default: `10`. Model-by-work-type (Sonnet for standard reads, Haiku for bulk, Opus for sensitive) is a fixed default baked into R51 — not a per-project knob — so this is the only sub-agent dial you set here. Lower it to cap token burn on big repos; raise it if your machine and rate limits comfortably handle more concurrency.

## Backend: cmux (default) or tmux (fallback)

The kingdom runs lanes through **cmux.app** by default (`cmux.enabled: true`). When cmux isn't available, it falls back to a raw **tmux** backend, auto-detected at runtime — no `kingdom.json` switch is required, and the cmux-specific keys (`cmux.workspaceColors`, `watchmanLayout`, `subAgentPool`, etc.) simply become irrelevant under tmux. See `TMUX-Guide.md` for the fallback layout and how the same roles map onto tmux windows/panes.

## See also

- [`work-cycle.md`](work-cycle.md): how the shape gets exercised every morning
- [`roles.md`](roles.md): what each lane actually does
- [`branch-model.md`](branch-model.md): how `gate.*` runs in the two-tier model
