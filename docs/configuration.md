# ⚙️ Configuration

> Part of the [kingdom](../README.md) docs.

## `/kingdom:init <project>`, pick your shape

```bash
/kingdom:init <project> [workers=N] [co-workers=M] [watchman=K]
```

Each parameter is independent. Set what you need, the rest fall to defaults.

### 🏢 Mid-size project, the default

```bash
/kingdom:init my-app
```

Equivalent to `workers=3 co-workers=1 watchman=1`. One worker per component (backend / frontend / ops), one paired lane reserved for you, one watchman over everything. **Start here unless you have a specific reason not to.**

### 🏭 Large project, specialised workers

```bash
/kingdom:init my-app workers=5 co-workers=2 watchman=1
```

Five autonomous workers (e.g., backend / frontend / mobile / infra / docs), two paired tracks (e.g., design exploration + content review), one watchman. Useful when one developer is steering many concurrent threads.

### 🚀 Solo side-project, single autonomous lane

```bash
/kingdom:init my-app workers=1 co-workers=0 watchman=0
```

One worker, no monitoring, no paired track. Best for rapid prototypes or one-person repos where parallelism + audit overhead isn't worth it.

### 🎨 UI-heavy day, everything paired

```bash
/kingdom:init my-app workers=0 co-workers=2 watchman=1
```

No autonomous work. Every lane is paired with you (e.g., redesigning the navbar in `co-worker-1` while iterating on the checkout flow in `co-worker-2`). One watchman keeps you informed of anything moving on `develop`.

### 🌙 Unattended overnight, autonomous + heavy monitoring

```bash
/kingdom:init my-app workers=3 co-workers=0 watchman=2
```

Three workers grinding a sub-task queue; two watchmen (one on backend smoke, one on frontend smoke). No paired track, you're not at the keyboard. `WATCH_*.md` reports give you the morning recap.

## What each parameter does

| Param | Role | Default | What it spawns |
|---|---|---|---|
| `workers=N` | Autonomous task lanes | `3` | `worker-1` … `worker-N`, each picks a sub-task and works it without your involvement |
| `co-workers=M` | Paired lanes for hands-on work | `1` | `co-worker-1` … `co-worker-M`, dormant by default; activate with *"pair on co-worker-1"* |
| `watchman=K` | Continuous monitors | `1` | `watchman-1` … `watchman-K`, each runs `/loop` to track `origin/develop` + babysit open PRs |

Soft cap: total lanes ≤ `sanityCap` (default `10`). Past 10 the UI gets cramped and the King has too much to juggle. Override in `kingdom.json`.

## What happens when you run `/kingdom:init <project>`

1. **Creates** `.kingdom/<project>/kingdom.json` from the template, shape pre-filled.
2. **Creates** `.kingdom/<project>/{logs,tasks}/` directories, the audit-trail homes.
3. **Prints** the resulting JSON for you to review.

**Declare ≠ launch.** `/kingdom:init <project>` only *declares* the shape. Before running `/kingdom:work my-app`, open the generated `kingdom.json` and customise:

- `gate.*` command lists: what King runs before every push. Keys are arbitrary. Dev stacks use `typecheck`/`tests`/`smoke`/`lint`; finance work might use `validate`/`audit`; science work might use `reproduce`/`peer-review`. Rename / add / remove freely.
- `git.base`: your PR target branch (default `develop`; many repos use `main`).

That's the entire customisation surface. **Workers are generic capacity**, no preset focus or path locks. The King assigns each task at dispatch time (see [`kings.md`](../.kingdom/.setting/kings.md) → "Dispatch brief schema"), so `worker-1` and `worker-2` are interchangeable. Same worker can do backend today, frontend tomorrow, financial-model audit the day after.

> **Re-running `/kingdom:init <project>` on an existing project** shows the existing config and asks before overwriting. Re-running replaces the whole file, back up your `gate.*` customisations first if you've filled them in.

## Configure your project

`/kingdom:init <project>` creates `.kingdom/<project>/kingdom.json`. Edit it before running `/kingdom:work`:

```json
{
  "shape": { "workers": 3, "co-workers": 1, "watchman": 1, "sanityCap": 10 },
  "git":   { "base": "develop", "integrationBranch": "kingdom", "pushPolicy": "always-ask" },
  "workers":   [ { "slug": "worker-1", "model": "opus" },
                 { "slug": "worker-2", "model": "opus" },
                 { "slug": "worker-3", "model": "opus" } ],
  "coworkers": [ { "slug": "co-worker-1", "model": "opus" } ],
  "watchmen":  [ { "slug": "watchman-1", "model": "sonnet", "docsAudit": true } ],
  "gate": {
    "typecheck": ["pnpm -r typecheck"],
    "tests":     ["pnpm -r test", "pytest -q"],
    "smoke":     ["bash scripts/smoke.sh"],
    "lint":      ["pnpm -r lint", "ruff check ."]
  }
}
```

The King reads this at spawn-time (invoked by `/kingdom:work`) to:

- Spawn the right number of lanes (`shape` counts)
- Pick a model per lane (Opus for masters, Sonnet for watchman, override if you want cheaper)
- Run YOUR exact gate commands inside each lane's worktree before any PR

> **Workers are generic.** No per-worker `focus` or `ownsPaths`. The King assigns scope at dispatch time (any worker can do any task; same worker does backend today, frontend tomorrow). `gate.*` keys are arbitrary, rename for non-dev domains (`validate`/`audit` for finance, `reproduce`/`peer-review` for science).

## Watchman config

Watchman behaviour is controlled by the `watchman` block inside `kingdom.json`:

```json
{
  "watchman": {
    "haikuCapPerTick": 5,
    "duties": {
      "codeReview":    true,
      "cveScan":       true,
      "conflictScan":  true,
      "gitHygiene":    true
    }
  }
}
```

### `haikuCapPerTick`

Maximum number of Haiku sub-agents a single watchman tick may spawn. Default: `5`. Max: `10`. Prevents runaway fan-out on large repos with many open PRs. Raise it for overnight unattended runs; lower it if you want tighter token spend.

### `duties.*` toggles

Each duty is `true` (enabled) by default. Set to `false` to disable for a project:

| Key | What the watchman does when enabled |
|---|---|
| `codeReview` | Babysits open PRs: posts a nudge comment if a PR has been waiting > 24 h with no review activity |
| `cveScan` | Scans `package.json` / `requirements.txt` / `go.mod` for known CVEs via `npm audit` / `pip-audit` / `govulncheck` |
| `conflictScan` | Checks whether any in-flight worker branch has diverged enough from `develop` to risk a conflict on merge |
| `gitHygiene` | Flags stale branches (no commit in > 7 days), orphan worktrees, and missing sentinel flags |

## See also

- [`work-cycle.md`](work-cycle.md): how the shape gets exercised every morning
- [`roles.md`](roles.md): what each lane actually does
- [`branch-model.md`](branch-model.md): how `gate.*` runs in the two-tier model
