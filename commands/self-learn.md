---
description: Ground yourself in THIS project's documentation — a 3-layer doc sweep (orientation → essentials → deep pass) that ends in 1-3 self-learn-summary cards. Any role runs it; the King may inject it as a lane's SECOND message after /kingdom:self-<role> (R52 companion).
argument-hint: "[project]   # omit = basename of $PWD"
---

You are **learning the project** — not the kingdom kit (that's `/kingdom:self-<role>`), but the actual codebase/repo this kingdom is operating on. The goal: in three escalating layers, read enough of the project's own documentation that you can place any task in its true context before touching a file.

READ-ONLY. This command reads docs and renders summary cards. It never edits, dispatches, commits, or pushes.

This is the **R52 companion** to `/kingdom:self-<role>`: the role-bootstrap command grounds you in the *rules + your role*; `/kingdom:self-learn` grounds you in the *project*. The King may inject this as a freshly-spawned lane's SECOND message (after `/kingdom:self-<role>`, before the task brief) so the lane knows both how the kingdom works AND what it's working on.

## How the fan-out works (R51/R53)

Each layer reads many files in parallel. Follow [`.kingdom/.setting/reference/workflow-fanout.md`](../.kingdom/.setting/reference/workflow-fanout.md):

- **Self-detect the Workflow tool.** If `Workflow` is in your toolset, run ONE Workflow per layer (or one for the whole sweep with three `phase()` blocks: Orient → Essentials → Deep) — Haiku for bulk reads, the `/workflows` UI comes for free.
- **No Workflow tool → bounded fallback.** Lane roles fan out bounded parallel `Agent(model=haiku, …)` reads, gated by `_bounded_wait` (R42 — never bare `wait`). The King never uses bare `Agent()` in its own session: it routes the reads to a lane (`cmux_send`, R37) or visible tabs (`cmux_tab_action`, R38).
- **Cap the army.** Honour the R51 soft target (`kingdom.json.subAgents.parallelTarget`, default 10) and, for the watchman, the R40 Haiku hard cap. A small project needs no army at all — scale to the doc count.

## Step 0 — Resolve project + load helpers

```bash
[ -n "${ZSH_VERSION:-}" ] && setopt no_nomatch 2>/dev/null   # zsh: empty doc globs below must not abort the block
# Source the helper loader so render_card / _bounded_wait resolve later.
[ -f "$PWD/.kingdom/.setting/functions/_load.sh" ] && source "$PWD/.kingdom/.setting/functions/_load.sh" && load_feature core

# First positional token is the project; default to the workspace basename.
project=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
[ -z "$project" ] && project="$(basename "$PWD")"

# The PROJECT ROOT is where the real codebase lives. In a kingdom workspace it's $PWD/<project>;
# if that dir doesn't exist (running directly inside a single repo), fall back to $PWD.
PROJ="$PWD/$project"
[ -d "$PROJ" ] || PROJ="$PWD"
echo "Self-learn target: $project  (root: $PROJ)"
```

## Step 1 — Layer 1: orientation (read every README / index / CLAUDE — cap ~30)

The project's wayfinding files. Discover them with a zsh-safe `find` (prune the heavy dirs), cap to the 30 most relevant, and read them ALL via the fan-out above.

```bash
# Exclude build/vendor/VCS + the kingdom's own worktrees + dist/build outputs.
LAYER1_FILES=$(find "$PROJ" \
  -type d \( -name node_modules -o -name .git -o -name .worktrees -o -name .next \
             -o -name dist -o -name build -o -name target -o -name .venv \
             -o -name __pycache__ \) -prune \
  -o -type f \( -iname 'readme.md' -o -iname 'index.md' -o -iname 'claude.md' \
             -o -iname 'contributing.md' -o -iname 'architecture.md' \) -print 2>/dev/null \
  | head -30)

echo "Layer 1 — orientation files:"
printf '%s\n' "$LAYER1_FILES"
L1_COUNT=$(printf '%s\n' "$LAYER1_FILES" | grep -c . || true)
echo "Layer 1 count: $L1_COUNT"
```

**Read every Layer-1 file** (fan-out: one Haiku sub-agent per file, or one Workflow `phase('Orient')`). From each, capture: what the project IS, its stack, top-level flow, and any explicit pointers to deeper docs ("see `docs/auth.md`", "the spec lives in …"). Hold those pointers — Layer 2 consumes them.

## Step 2 — Layer 2: essentials (must-read list from Layer 1 — cap ~25)

From the Layer-1 content, build a **must-read list**: the specs, architecture docs, design notes, schema/config files, and entry points that Layer 1 named or implied as load-bearing. Read those.

```bash
# Seed the essentials with the obvious load-bearing locations, then the King/lane ADDS the
# specific files Layer 1 pointed at (a plain find can't read prose pointers — the reader does).
LAYER2_SEED=$(find "$PROJ" \
  -type d \( -name node_modules -o -name .git -o -name .worktrees -o -name .next \
             -o -name dist -o -name build -o -name target -o -name .venv \
             -o -name __pycache__ \) -prune \
  -o -type f \( -path '*/docs/*.md' -o -iname '*spec*.md' -o -iname '*design*.md' \
             -o -iname '*architecture*.md' -o -iname 'package.json' -o -iname '*.config.*' \
             -o -iname 'schema.prisma' -o -iname 'openapi.*' \) -print 2>/dev/null \
  | head -25)

echo "Layer 2 — essentials seed (augment with files Layer 1 named):"
printf '%s\n' "$LAYER2_SEED"
```

**Build the final Layer-2 list** = the seed above UNION the explicit pointers harvested in Layer 1, deduped and capped at ~25. **Read them all** (fan-out: Haiku per file, or Workflow `phase('Essentials')`). From each, capture where things live (routes, db, auth, config, tests) and flag any file that itself reads as *load-bearing but only summarized here* — those feed Layer 3.

## Step 3 — Layer 3: deep pass (load-bearing docs Layer 2 flagged — cap ~15)

A second, deeper sweep over `docs/` (or the project's equivalent doc home) for the files Layer 2 marked load-bearing — read them in full, not skimmed.

```bash
# Candidate pool for the deep pass: the project's doc home(s). The reader picks ≤15 from here
# based on what Layer 2 flagged — do NOT blindly read all of them.
LAYER3_POOL=$(find "$PROJ" \
  -type d \( -name node_modules -o -name .git -o -name .worktrees -o -name .next \
             -o -name dist -o -name build -o -name target -o -name .venv \
             -o -name __pycache__ \) -prune \
  -o -type f -path '*/docs/*.md' -print 2>/dev/null \
  | head -60)

echo "Layer 3 — deep-pass candidate pool (pick ≤15 that Layer 2 flagged load-bearing):"
printf '%s\n' "$LAYER3_POOL"
```

**Read only the ≤15 Layer-2 flagged** (fan-out: Sonnet for depth here, or Workflow `phase('Deep')`). Capture the precise, non-obvious facts a worker would otherwise get wrong (squashed migrations, a non-default branch model, an auth quirk, a generated file that must not be hand-edited) and any open questions worth resolving before work starts.

## Step 4 — Synthesize + render 1-3 self-learn-summary cards

Total the files actually read across all three layers and synthesize the three content blocks. Then render the [`self-learn-summary`](../.kingdom/.setting/cards/self-learn-summary.md) card 1-3 times.

```bash
# Re-source the loader (state does NOT persist between markdown blocks).
[ -f "$PWD/.kingdom/.setting/functions/_load.sh" ] && source "$PWD/.kingdom/.setting/functions/_load.sh" && load_feature core

# N_FILES_READ = the count the role actually consumed across Layers 1-3 (set it to the real total).
export PROJECT="$project"
export N_FILES_READ="${N_FILES_READ:-0}"   # replace with the true total read across all 3 layers
```

Render the cards (the role fills each `${…}` from what it learned — see the card's variable table):

- **Card 1 — Big picture (always).** `${BIG_PICTURE}` = a 2-5 line synthesis: what the project is, its stack, its top-level flow. Render with `${MAP}` and `${DEEP_NOTES}` left empty (those rows drop out).
  ```bash
  export BIG_PICTURE="<2-5 line synthesis>" MAP="" DEEP_NOTES=""
  render_card "self-learn-summary"
  ```
- **Card 2 — Map (always, when there's a non-trivial map).** `${MAP}` = bulleted "X lives in Y" wayfinding lines (entry points, config, docs index).
  ```bash
  export BIG_PICTURE="" MAP="• routes → …  • db → …  • docs index → …" DEEP_NOTES=""
  render_card "self-learn-summary"
  ```
- **Card 3 — Deep notes (optional).** Only render when Layer 3 surfaced something substantive. `${DEEP_NOTES}` = load-bearing details + open questions to resolve before working.
  ```bash
  export BIG_PICTURE="" MAP="" DEEP_NOTES="• <load-bearing fact>  • Open: <question>"
  render_card "self-learn-summary"
  ```

Each empty `${VAR}` and its line is dropped by `render_card`, so a single-card render collapses cleanly.

## Conventions

- **READ-ONLY.** No edits, dispatches, commits, or pushes — exactly like `/kingdom:self-<role>`.
- **Project, not kit.** This grounds you in the *codebase*; `/kingdom:self-<role>` grounds you in the *rules + role*. Run both when freshly spawned (role first, then learn).
- **Scale the army to the doc count.** Caps (~30 / ~25 / ~15) are ceilings, not targets. A tiny repo may finish all three layers with no fan-out at all; honour the R51 soft target and the watchman's R40 hard cap when you do fan out.
- **Self-detect the Workflow tool.** Present → one run, live `/workflows` UI (R53). Absent → bounded `Agent()` / cmux tabs (R42/R51), King via lanes/tabs only (R37/R38).
- **zsh-safe.** `setopt no_nomatch` guards the empty doc globs; `find … -prune` excludes `node_modules`/`.git`/`.worktrees`/`dist`/`build`.
