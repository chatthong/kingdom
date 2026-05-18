<!--
kingdom — Multi-agent orchestration kit for Claude Code (a Claude Code plugin).
Parallel AI coding with git worktrees, native cmux.app integration, audit-first
design, and human-in-the-loop push gates.

Keywords: claude code plugin, multi-agent orchestration, ai agent fleet,
parallel ai coding, git worktree, claude sub-agents, claude code teammates,
cmux integration, ai code review, autonomous coding agent, agent orchestrator,
claude opus sonnet haiku, ai pair programming, claude code teams alternative,
composio agent-orchestrator alternative, anthropic claude plugin.
-->

<div align="center">

# 👑 kingdom

### Multi-agent orchestration kit for Claude Code — parallel AI coding with Git worktrees + native cmux.app

**One King. N workers. Auditable parallel work — any domain you version with git.**

![Version](https://img.shields.io/badge/version-0.14.8-success)
![License](https://img.shields.io/badge/license-see%20LICENSE-blue)
![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-purple)
![macOS](https://img.shields.io/badge/macOS-primary-black)
![Linux](https://img.shields.io/badge/Linux-tmux%20fallback-333333)
![git worktrees](https://img.shields.io/badge/git%20worktrees-built--in-orange)
![Multi-Agent](https://img.shields.io/badge/multi--agent-orchestration-9333ea)
![cmux.app](https://img.shields.io/badge/cmux.app-native-f59e0b)

[Quick start](#-quick-start) · [Install](#-install) · [Every day](#-every-day--your-monday-morning-ritual) · [Roles](#-meet-the-king----and-the-masters-that-work-for-it) · [FAQ](#-faq)

</div>

---

## ⚡ Quick start

```bash
# 1. Install (in any Claude Code session)
/plugin marketplace add chatthong/kingdom
/plugin install kingdom@kingdom

# 2. Scaffold a workspace — 90s, once per workspace
/kingdom:init my-app

# 3. Spawn your kingdom — your daily ritual
/kingdom:start my-app
```

You now have **5 AI agents** in cmux.app's sidebar — 👑 King, 3× 👷 workers, 1× 🧑‍💼 co-worker, 1× 🕵️ watchman — each in its own colour-coded workspace, all coordinated through your one chat with the King.

> **Need details?** [Install](#-install) · [First time](#-first-time-90s-once-per-workspace) · [Every day](#-every-day--your-monday-morning-ritual) · [The contract](#-the-contract-what-kingdom-wont-touch) · [How it works](#-how-it-works)

```mermaid
graph TB
    K([👑 King · Opus<br/>your conversation, your gates])

    K ==>|cmux send| W1([👷 worker-1 · Opus<br/>backend])
    K ==>|cmux send| W2([👷 worker-2 · Opus<br/>frontend])
    K ==>|tmux send-keys| W3([👷 worker-3 · Opus<br/>ops])
    K ==>|tmux send-keys| CW([🧑‍💼 co-worker-1 · Opus<br/>you-paired])
    K ==>|claude -p| WM([🕵️ watchman-1 · Sonnet<br/>/loop monitor])

    W1 -->|Agent| SA1([🐱 sub · Sonnet<br/>code])
    W1 -->|Agent| SA2([🐱 sub · Haiku<br/>doc digest])
    W1 -->|Agent| SA3([🐱 sub · Sonnet<br/>test])
    W2 -->|Agent| SA4([🐱 sub · Sonnet<br/>code])
    W2 -->|Agent| SA5([🐱 sub · Sonnet<br/>storybook])
    CW -->|Agent| SA6([🐱 sub · Opus<br/>auth review])

    SA1 & SA2 & SA3 & SA4 & SA5 & SA6 & W3 & WM -.->|"4-step closer"| LOG[(.kingdom/project/logs/)]
    W1 & W2 & W3 & CW -.->|"task file"| TSK[(.kingdom/project/tasks/)]

    classDef king fill:#fef3c7,stroke:#f59e0b,stroke-width:3px,color:#78350f
    classDef opus stroke:#a78bfa,stroke-width:2px
    classDef sonnet stroke:#60a5fa,stroke-width:1.5px
    classDef haiku stroke:#34d399,stroke-width:1.5px
    classDef monitor stroke:#fb7185,stroke-width:1.5px
    classDef store fill:none,stroke:#94a3b8,stroke-width:1px

    class K king
    class W1,W2,W3,CW opus
    class SA1,SA3,SA4,SA5 sonnet
    class SA2 haiku
    class SA6 opus
    class WM monitor
    class LOG,TSK store
```

A Claude Code plugin that turns one Claude session into a coordinated team — each lane in its own git worktree on its own branch. **You stay in one chat with the King.** The King runs gates, asks before every push, and writes audit artifacts you can grep next month. No new runtime, no daemons. Just Claude + git worktrees + a clean discipline.

**Domain-agnostic by design.** Code, research, finance models, scientific notebooks, manuscripts — anything you version in git, the kingdom can orchestrate. Workers are generic capacity; `gate.*` commands are arbitrary bash. Same kit works whether your "tests" run `pytest`, `Rscript`, or `pandoc --validate`.

---

## ✨ Why kingdom?

- **Real parallelism** — 3–10 lanes editing different branches simultaneously, isolated by `git worktree`
- **One conversation** — you talk to the King; the King talks to the lanes; you never juggle panes
- **Native cmux.app feel** — every role gets its own colour-coded workspace in the sidebar; notifications fire as blue rings, badges, and bell-panel entries; nothing tab-multiplexed or hidden behind a custom UI
- **Full audit trail** — every task leaves a 4-step closer artifact: raw log → curated digest → master log line → sentinel flag
- **Zero new runtime** — cmux + tmux + jq + gh are standard dev tooling; the protocol is plain text

---

## 🪟 What it looks like in cmux.app

The kingdom is built for **manaflow/cmux.app** as the PRIMARY mode (raw tmux + headless `claude -p` are graceful fallbacks). When you run `/kingdom:start my-app`, cmux.app's sidebar fills with one **workspace per role** — each in its own colour, each with its own Claude session, each notify-able independently.

```text
cmux.app sidebar (vertical tabs)

╔══════════════════════════════════╗
║ 📌 👑 King · my-app          🔔1 ║  ← amber · pinned · "push?" prompt waiting
║    Your conversation · pinned    ║
╟──────────────────────────────────╢
║    👷 worker-1                   ║  ← violet · BE-AUTH-3 in flight
║    Kingdom lane · 2026-05-18T03Z ║
║    BE-AUTH-3 · layer 3/4         ║
╟──────────────────────────────────╢
║    👷 worker-2          ●        ║  ← violet · 🔵 blue ring = task just finished
║    Kingdom lane · 2026-05-18T03Z ║
║    OPS-DB-7 done · pushed PR#236 ║
╟──────────────────────────────────╢
║    🧑‍💼 co-worker-1               ║  ← blue · paired with you
║    Kingdom lane · 2026-05-18T03Z ║
║    UI-CHK-12 · Ter active        ║
╟──────────────────────────────────╢
║    🕵️ watchman-1         🔔1     ║  ← rose · alerted "develop RED"
║    Kingdom monitor · running     ║
║    [split: claude top / gh bot.] ║
╚══════════════════════════════════╝
```

### Three visible cmux notification surfaces — all wired in

| Visual | When | Where |
|---|---|---|
| 🔵 **Blue ring on pane** | Worker finishes a task, sub-agent closer fires, gate fails | The pane that needs attention NOW |
| 🔔 **Sidebar badge** | Watchman alerts, push-ready prompts, cross-workspace events | The workspace card that has news |
| 📋 **Bell-icon panel** | Auto-aggregated | Scrollable list at top of sidebar — jump-to-most-recent |

cmux fires native macOS notifications too — the kingdom always passes role-emoji-prefixed titles (`👷 worker-1 done`, `🕵️ watchman-1 · develop RED`, `👑 King · push?`) so the bell panel stays scan-able. Notifications fire on **8 canonical events**; full schema in [`cmux.md`](.kingdom/.setting/cmux.md) → § Notification system.

### Three-tier visual hierarchy

```mermaid
graph TB
    W[🪟 cmux.app window]

    W --> K[🏢 Workspace · 👑 King<br/>amber · pinned · your conversation]
    W --> M1[🏢 Workspace · 👷 worker-1<br/>violet · long-lived autonomous lane]
    W --> M2[🏢 Workspace · 👷 worker-2<br/>violet]
    W --> CW[🏢 Workspace · 🧑‍💼 co-worker-1<br/>blue · paired with you]
    W --> WM[🏢 Workspace · 🕵️ watchman-1<br/>rose · vertical split inside]

    M1 -.spawn.-> T1[📑 Tab · 🐱 sub · Sonnet · code<br/>auto-close on sentinel]
    M1 -.spawn.-> T2[📑 Tab · 🐱 sub · Haiku · digest]
    WM --> S1[🪟 Split top · claude /loop]
    WM --> S2[🪟 Split bottom · gh pr list --watch]

    classDef king fill:#fef3c7,stroke:#f59e0b,stroke-width:3px
    classDef opus stroke:#a78bfa,stroke-width:2px
    classDef blue stroke:#60a5fa,stroke-width:2px
    classDef rose stroke:#fb7185,stroke-width:2px
    classDef tab stroke:#34d399,stroke-width:1.5px,stroke-dasharray:5 5
    classDef split stroke:#fb7185,stroke-width:1.5px

    class K king
    class M1,M2 opus
    class CW blue
    class WM rose
    class T1,T2 tab
    class S1,S2 split
```

| Tier | Used for | cmux command | Auto-closes? |
|---|---|---|---|
| 🏢 **Workspace** | One per master (King + every worker + co-worker + watchman) | `cmux new-workspace --name --cwd --command "claude"` + `cmux workspace-action --action set-color` | No — survives across sessions |
| 📑 **Tab** | Visible sub-agent spawn (default: headless `Agent(...)`; tab only when visibility wanted) | `cmux tab-action --action new-terminal-right` | ✅ Auto-closes on sentinel via 5-step closer Step 5 |
| 🪟 **Split** | Watchman dual-view (claude + `gh pr watch`); optional paired-coworker editor | `cmux new-workspace --layout '{…}'` OR `cmux new-split` post-creation | No — same lifetime as parent workspace |

### Other cmux features the kingdom uses

- **Workspace colours** — applied per role from `kingdom.json.cmux.workspaceColors` (defaults: King=amber, Worker=violet, Co-worker=blue, Watchman=rose). Left-edge colour bars in the sidebar make roles distinguishable at 2 metres.
- **Workspace pinning** — `kingdom.json.cmux.pinKingWorkspace: true` keeps the King's workspace at the top of the sidebar even when you spawn more lanes.
- **Workspace descriptions** — set per spawn (`Kingdom lane · <name> · <UTC>`); shows as smaller text under the workspace name. King's description gets updated each session: `Your conversation · pinned · <UTC>`.
- **Layout JSON** — watchman workspaces ship a pre-defined vertical split (top: claude `/loop`, bottom: `gh pr list --watch --interval 30`). Set `kingdom.json.cmux.watchmanLayout` to `null` for a single-pane watchman.
- **`cmux send --workspace <ref>`** — King dispatches task briefs by workspace ref (stable across the session, persisted to `<LOGS>/workspace-refs.env`). No tab-name guessing, no escaping fights.
- **`cmux tree --all`** — King's introspection tool for verifying the layout after spawn or resume.

### What `/kingdom:start` does in PRIMARY mode (one call, all of the above)

```bash
/kingdom:start my-app
```

Behind the scenes:

1. Reads shape from `.kingdom/my-app/kingdom.json` (workers / co-workers / watchman counts)
2. Renames + recolours + pins your current workspace → `👑 King · my-app` (amber, pinned)
3. For each worker / co-worker / watchman: spawns a workspace via `cmux new-workspace --command "claude"` with the right colour
4. For the watchman: applies the dual-view split layout
5. Persists all workspace refs to `<LOGS>/workspace-refs.env`
6. Reports the resulting sidebar layout

Everything below — task dispatch, gates, audit, push approval, exit — uses those workspace refs. No `cmux claude-teams` (broken anyway), no manual tab juggling.

---

## 🚀 Install

```
/plugin marketplace add chatthong/kingdom
/plugin install kingdom@kingdom
/kingdom:doctor
```

`/kingdom:doctor` tells you what's missing (cmux.app, tmux, jq, gh, settings.json keys) and offers to fix it.

---

## 🏗 First time (90s, once per workspace)

```bash
mkdir -p ~/code/my-workspace && cd ~/code/my-workspace
claude
```

```
/kingdom:init my-app
```

Done. Edit `.kingdom/my-app/kingdom.json` once to fill in your `gate.*` commands (your project's typecheck/tests/etc, or any bash you want gated). Then never edit it again.

---

## 🔁 Every day — your Monday-morning ritual

```
/kingdom:start my-app
```

Monday morning. Kingdom spins back up — workers, co-worker, watchman, all in the cmux.app sidebar with colours, notifications, and the conversation state from last week.

Tuesday morning. Same command. **Idempotent** — re-running resumes; never recreates.

After a vacation: `/kingdom:update my-app` first (surfaces gaps between project docs and kingdom logs), then `/kingdom:start`.

End of day: `/kingdom:exit my-app` — closes lanes gracefully, keeps your conversation alive.

That's the whole routine. **It replaces the daily overhead of "what was I doing", "did anyone push", "is develop green", "is PR #234 reviewed".** The King knows. Watchman knows. Ask the King.

---

## 🛡 The contract (what kingdom won't touch)

- ❌ Your project files outside `.worktrees/<lane>/` — main checkout untouched until you say "push"
- ❌ `develop` and `main` — read-only; only `feature/<topic>` reaches origin
- ❌ Pushes — never without your explicit "push?" approval
- ❌ Your `~/.zshrc`, `~/.gitconfig`, PATH, shell hooks — zero modifications
- ❌ Your `.gitignore` — kingdom adds ONE line (`.worktrees/`) and stops there
- ✅ `rm -rf .kingdom/ .worktrees/` removes the kingdom; your project, git history, branches survive intact

---

## `/kingdom:init <project>` — pick your shape

```
/kingdom:init <project> [workers=N] [co-workers=M] [watchman=K]
```

Each parameter is independent — set what you need, the rest fall to defaults.

#### 🏢 Mid-size project — the default

```
/kingdom:init my-app
```

Equivalent to `workers=3 co-workers=1 watchman=1`. One worker per component (backend / frontend / ops), one paired lane reserved for you, one watchman over everything. **Start here unless you have a specific reason not to.**

#### 🏭 Large project — specialized workers

```
/kingdom:init my-app workers=5 co-workers=2 watchman=1
```

Five autonomous workers (e.g., backend / frontend / mobile / infra / docs), two paired tracks (e.g., design exploration + content review), one watchman. Useful when one developer is steering many concurrent threads.

#### 🚀 Solo side-project — single autonomous lane

```
/kingdom:init my-app workers=1 co-workers=0 watchman=0
```

One worker, no monitoring, no paired track. Best for rapid prototypes or one-person repos where parallelism + audit overhead isn't worth it.

#### 🎨 UI-heavy day — everything paired

```
/kingdom:init my-app workers=0 co-workers=2 watchman=1
```

No autonomous work — every lane is paired with you (e.g., redesigning the navbar in `co-worker-1` while iterating on the checkout flow in `co-worker-2`). One watchman keeps you informed of anything moving on `develop`.

#### 🌙 Unattended overnight — autonomous + heavy monitoring

```
/kingdom:init my-app workers=3 co-workers=0 watchman=2
```

Three workers grinding a sub-task queue; two watchmen (one on backend smoke, one on frontend smoke). No paired track — you're not at the keyboard. `WATCH_*.md` reports give you the morning recap.

---

### What each parameter does

| Param | Role | Default | What it spawns |
|---|---|---|---|
| `workers=N` | Autonomous task lanes | `3` | `worker-1` … `worker-N` — each picks a sub-task and works it without your involvement |
| `co-workers=M` | Paired lanes for hands-on work | `1` | `co-worker-1` … `co-worker-M` — dormant by default; activate with *"pair on co-worker-1"* |
| `watchman=K` | Continuous monitors | `1` | `watchman-1` … `watchman-K` — each runs `/loop` to track `origin/develop` + babysit open PRs |

Soft cap: total lanes ≤ `sanityCap` (default `10`). Past 10 the UI gets cramped and the King has too much to juggle. Override in `kingdom.json`.

---

### What happens when you run `/kingdom:init <project>`

1. **Creates** `.kingdom/<project>/kingdom.json` from the template, shape pre-filled.
2. **Creates** `.kingdom/<project>/{logs,tasks}/` directories — the audit-trail homes.
3. **Prints** the resulting JSON for you to review.

**Declare ≠ launch.** `/kingdom:init <project>` only *declares* the shape. Before running `/kingdom:start my-app`, open the generated `kingdom.json` and customise:

- `gate.*` command lists — what King runs before every push. Keys are arbitrary — dev stacks use `typecheck`/`tests`/`smoke`/`lint`; finance work might use `validate`/`audit`; science work might use `reproduce`/`peer-review`. Rename / add / remove freely.
- `git.base` — your PR target branch (default `develop`; many repos use `main`)

That's the entire customisation surface. **Workers are generic capacity** — no preset focus or path locks. The King assigns each task at dispatch time (see [`kings.md`](.kingdom/.setting/kings.md) → "Dispatch brief schema"), so `worker-1` and `worker-2` are interchangeable. Same worker can do backend today, frontend tomorrow, financial-model audit the day after.

> **Re-running `/kingdom:init <project>` on an existing project** shows the existing config and asks before overwriting. Re-running replaces the whole file — back up your `gate.*` customisations first if you've filled them in.

---

## 👋 Meet the King — and the masters that work for it

One King, N masters. You talk to the King; the King talks to the masters; the masters do the work. Each is a real Claude Code session — no daemons, no orchestrator runtime, no magic. Just role discipline.

### 👑 The King — Opus

Lives in your primary checkout on a local-only `kingdom` branch. **Holds your conversation.** Plans. Gates. Pushes. **Never edits files directly.** When you say "King, plan today's work," the King spawns parallel planning agents (Haiku to scan tasks, Sonnet to triage), writes its own task file with the multi-layer plan, then dispatches sub-tasks to the masters. Before any `git push`, the King runs the pre-commit gate (typecheck + tests + dry-merge + cross-lane overlap), reports back to you, and waits for explicit approval. **It's the only role with push authority — and only after you say "push."**

### 👷 Workers — Opus, autonomous masters

Three (or N) parallel lanes, each a long-lived Claude Code session inside its own `git worktree` on its own local-only `worker-N` branch. Workers pick claimable sub-tasks from your task source (`TODO_Master.csv`, GitHub issues — whatever you configure), then **plan first**: every assignment begins with a task file capturing the multi-layer plan (Discovery → Strategy → Execution → Verification) before any code change happens. Inside each layer, workers spawn their own sub-agent fleet (Sonnet for edits, Haiku for bulk reads, Opus for sensitive files) with no eco-mode cap — N is chosen for best result, not for parallelism's sake. When done, the worker signals the King via a 4-step closer.

### 🧑‍💼 Co-workers — Opus, paired with you

The lanes you drive yourself. Dormant by default; activate when you say *"pair on co-worker-1 — I'll redesign the checkout flow."* Inside that pane you type the brief, the co-worker assists interactively, you make the calls. Same task file convention. Same pre-commit gate. Same push approval. The difference: **you** set the scope, **you** set the pace.

### 🕵️ Watchmen — Sonnet, always-on monitors

Passive. Continuous. Each watchman runs `/loop` in dynamic-pacing mode (5–15 min). It watches `origin/develop` tip, runs your smoke tests on every advance, babysits open PRs (CI rollup, review state, mergeability), and writes `WATCH_*.md` reports + sidebar notifications. **Read-only + test-runner + alerter.** Never edits, never pushes.

### 🐱 Sub-agents — Sonnet / Haiku / Opus, one-shot

The leaves of the tree. Spawned by the King (for planning) or by any master (for execution). `Agent(model=…)` calls — short-lived, single-task. Each runs its own 4-step closer. Model picked per task: Sonnet for standard work (P1), Haiku for bulk reads (P2), Opus for sensitive files (P3). Lane masters fan them out in parallel and synthesise the outputs.

---

**The pattern in one sentence:** the King reasons about WHAT, the masters reason about HOW, and the sub-agents do the doing. You stay in one chat. Everything else is the kingdom.

---

## 🎭 Roles at a glance

| Role | Model | What it does | Spec |
|---|---|---|---|
| 👑 **King** | Opus | Orchestrator. Holds your conversation. Sole pusher. Never edits files. | [`kings.md`](.kingdom/.setting/kings.md) |
| 👷 **Worker** | Opus | Autonomous lane. Picks + executes sub-tasks. Spawns own sub-agents (no eco cap). | [`workers.md`](.kingdom/.setting/workers.md) |
| 🧑‍💼 **Co-worker** | Opus | Paired with you. Dormant until you signal. | [`co-workers.md`](.kingdom/.setting/co-workers.md) |
| 🕵️ **Watchman** | Sonnet | Passive monitor (`/loop`, 5–15 min). Smoke + PR babysitting. Never edits, never pushes. | [`watchmans.md`](.kingdom/.setting/watchmans.md) |
| 🐱 **Sub-agent** | Sonnet/Haiku/Opus | One-shot via `Agent(model=…)`. Spawned by King or a lane. | [`workers.md`](.kingdom/.setting/workers.md) |

---

## 🌳 Branch model

Five 🖥️ LOCAL-only branches never leave your laptop. Only `feature/<topic>` ever reaches origin. The King is the **sole pusher** — lanes are private workshops, features are the public surface.

### Worked example — 3 lanes in flight

```mermaid
graph TB
    subgraph ONLINE ["☁️ ONLINE — origin, visible to your team"]
        direction TB
        MAIN([main<br/>🔒 protected · production])
        DEV([develop<br/>👥 lead-controlled · PR target])
        F1([feature/auth-refactor<br/>📤 from 👷 worker-1])
        F2([feature/checkout-flow<br/>📤 from 🧑‍💼 co-worker-1])
        F3([feature/db-migrate<br/>📤 from 👷 worker-2])
    end

    subgraph LOCAL ["🖥️ LOCAL — laptop only, never pushed"]
        direction TB
        K([👑 kingdom<br/>integration view<br/>develop ⊕ all lane tips])
        W1([👷 worker-1<br/>BE-AUTH-3])
        W2([👷 worker-2<br/>OPS-DB-7])
        W3([👷 worker-3<br/>idle])
        CW1([🧑‍💼 co-worker-1<br/>UI-CHK-12 · paired])
        WM1([🕵️ watchman-1<br/>tracks origin/develop])
    end

    DEV -.->|"git fetch + merge<br/>(/kingdom:start, /kingdom:update)"| K
    K -.->|"git worktree add<br/>from origin/develop"| W1 & W2 & W3 & CW1 & WM1

    W1 ==>|"👑 King carves<br/>git push + gh pr create"| F1
    CW1 ==>|"same flow"| F2
    W2 ==>|"same flow"| F3

    F1 & F2 & F3 ==>|"PR review →<br/>squash merge"| DEV
    DEV ==>|"release cycle"| MAIN

    classDef online stroke:#6366f1,stroke-width:2px,fill:#eef2ff,color:#1e1b4b
    classDef local stroke:#10b981,stroke-width:2px,fill:#ecfdf5,color:#064e3b
    classDef protected stroke:#dc2626,stroke-width:3px,fill:#fef2f2,color:#7f1d1d
    classDef feature stroke:#f59e0b,stroke-width:1.5px,fill:#fffbeb,color:#78350f

    class MAIN protected
    class DEV online
    class F1,F2,F3 feature
    class K,W1,W2,W3,CW1,WM1 local
```

### What lives where

| Branch | Lives | Lifetime | Touched by | Reaches origin? |
|---|---|---|---|---|
| `main` | online (protected) | permanent | release manager | ✅ origin/main |
| `develop` | online | permanent | lead via PR merge | ✅ origin/develop |
| `feature/<topic>` | online | one PR, then deleted | 👑 King (carve + push + PR) | ✅ origin/feature/* |
| `kingdom` | local only | permanent | 👑 King (fetch + merge from origin/develop) | ❌ never |
| `worker-N` | local only | slot identity — reset per PR | 👷 worker-N | ❌ never |
| `co-worker-N` | local only | slot identity — reset per PR | 🧑‍💼 co-worker-N | ❌ never |
| `watchman-N` | local only | reset every `/loop` tick to `origin/develop` | 🕵️ watchman-N (read-only) | ❌ never |

### The two-surface decoupling

**Work surface** (`worker-N`, `co-worker-N`) — long-lived local slots. They get hard-reset to a fresh tip per PR, but the slot itself persists across many tasks. Same `worker-1` does BE-AUTH-3 this week and FE-ICONS-9 next week.

**PR surface** (`feature/<topic>`) — one PR, one branch. Carved fresh at push time, deleted after merge. The branch name is descriptive (`feature/auth-refactor`, not `feature/worker-1-week-15`) so reviewers see what they're reviewing, not who.

This decoupling means lane numbers are **operational identifiers** (which tmux pane, which worktree directory) — not **content identifiers**. The repo history stays clean because no `worker-N` ever leaves the laptop.

Full commit flow + push gate + FINAL conflict check: [`git.md`](.kingdom/.setting/git.md).

---

## ⚙️ Configure your project

`/kingdom:init <project>` creates `.kingdom/<project>/kingdom.json`. Edit it before running `/kingdom:start`:

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

The King reads this at `/kingdom:start` to:
- Spawn the right number of lanes (`shape` counts)
- Pick a model per lane (Opus for masters, Sonnet for watchman — override if you want cheaper)
- Run YOUR exact gate commands inside each lane's worktree before any PR

> **Workers are generic.** No per-worker `focus` or `ownsPaths` — the King assigns scope at dispatch time (any worker can do any task; same worker does backend today, frontend tomorrow). `gate.*` keys are arbitrary — rename for non-dev domains (`validate`/`audit` for finance, `reproduce`/`peer-review` for science).

---

## 🔧 Slash commands

| Command | What it does |
|---|---|
| `/kingdom:doctor` | Check prerequisites — `cmux.app`, `tmux`, `jq`, `gh`, `git ≥ 2.5`, user-global + workspace `settings.json` (auto-patches both with diff + ask), `tasks/` writable, orphan audit artifacts, git state across projects. 10 checks. Re-run anytime. |
| `/kingdom:init` | Workspace scaffold only — `.kingdom/.setting/` role docs + `.claude/settings.json` permissions. |
| `/kingdom:init <project> [workers=N] [co-workers=M] [watchman=K] [base=<branch>]` | Workspace scaffold (if missing) + project scaffold — `.kingdom/<project>/kingdom.json` + `tasks/` + `logs/`. |
| `/kingdom:start <project>` | Spawn the lanes for `<project>` — git worktrees + cmux/tmux/headless dispatch + sidebar tags + watchman `/loop`. Reads shape from `kingdom.json` (no override args — change shape via `kingdom.json` or `/kingdom:init`). Idempotent — re-running resumes existing worktrees. |
| `/kingdom:update [project=<name>] [--force]` | Audit sweep — auto-switches to `kingdom` branch + spawns 4 parallel specialists + Haiku scanner fan-out. Surfaces gaps between project doc claims and kingdom logs. Idempotent. Current project only. |
| `/kingdom:exit [project=<name>] [--force] [--include-king] [--audit]` | Graceful teardown — checks in-flight work (asks before force-closing), notifies each lane, gracefully exits Claude in each workspace, closes lane workspaces, writes session-end log line. Keeps King's workspace by default. |

---

## 🔄 Updating the plugin

Two layers, different routines:

```bash
/plugin update kingdom    # 1. pull new plugin code (slash commands + templates)
/kingdom:doctor           # 2. (optional) check for new env requirements
/kingdom:init             # 3. (optional) re-sync workspace role docs from new templates
```

| Asset | Survives plugin update? |
|---|---|
| Slash commands | replaced by new version (immediate) |
| Role doc templates (in plugin) | replaced by new version |
| Workspace `.kingdom/.setting/*.md` | ✅ untouched — re-run `/kingdom:init` to sync |
| Your `kingdom.json` configs | ✅ untouched |
| `tasks/` + `logs/` audit trail | ✅ untouched (your work is safe) |
| `.claude/settings.json` permissions | ✅ untouched |

If a release changes the `kingdom.json` schema (e.g., v0.5.0 dropped `focus`+`ownsPaths`), the CHANGELOG entry for that version tells you what to edit. Schema migrations are manual edits right now — a future `/kingdom:migrate` command may automate this.

---

## 🧠 How it works

The King is a long-lived Claude Opus session in your project's primary checkout, on a local-only `kingdom` branch (an integration view: `develop` ⊕ every lane's tip). It **never edits files** — its job is orchestration: read `kingdom.json`, pick sub-tasks, dispatch via `cmux send` (primary), `tmux send-keys` (fallback), or `claude -p` (headless).

Each lane is a Claude teammate inside its own plain `git worktree` on its own local-only `<role>-<n>` branch. Workers pick claimable sub-tasks, execute via their own sub-agent fleet (Sonnet/Haiku/Opus, **unbounded parallel** — N chosen for *best result*, not 1:1 with files), and signal completion via a **4-step closer**:

```
1. Raw output      →  <LOGS>/raw/<ID>__<lane>.md
2. Curated digest  →  <LOGS>/<ID>.md            (## TL;DR · first 15 lines)
3. Master log line →  <LOGS>/master_agent.log   (append-only)
4. Sentinel flag   →  <LOGS>/done/<ID>__<lane>.flag  (+ optional cmux notify)
```

Where `<LOGS> = <workspace>/.kingdom/<project>/logs/` — outside any project's git, so no `.gitignore` entries leak.

Before any sub-agent dispatch, the lane master writes a **task file** at `.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md` — a checkbox doc with the multi-layer plan (Discovery → Strategy → Execution → Verification), live progress, and final summary. It's the human-readable audit trail of HOW the work happened.

The King polls the sentinel, runs your **pre-commit gate** (typecheck + tests + dry-merge against develop + cross-lane file-overlap check), writes a per-lane test report, and asks you "push?". On approval, it runs a **FINAL conflict check** against `origin/develop` via `git merge-tree` (a plumbing dry-merge with zero side effects — catches drift if the lead merged something while you were deciding), carves a fresh `feature/<topic>` branch from the lane tip, and pushes. After PR merge, the lane resets for the next sub-task.

The **Watchman** is separate: a `/loop` agent (dynamic 5–15 min) that tracks `origin/develop` tip and babysits open PRs — runs smoke when develop advances, alerts on CI transitions, posts notifications when a PR is ready to merge. Read-only + test runner + alerter. Never edits, never pushes.

Full role specs: [`.kingdom/.setting/index.md`](.kingdom/.setting/index.md).

---

## 🤔 Why?

**Problem:** running multiple Claude sessions in parallel means each one editing the same files, fighting over git state, broken builds, lost work.

**Existing fixes:** `git worktree` gives isolated checkouts but no orchestration. Manual tmux gives panes but no audit trail. Headless `claude -p` chains give batch but no visibility.

**kingdom:** an opinionated stack that puts these together:

- `git worktree` for isolation (built into git ≥ 2.5)
- tmux-protocol for dispatch (via cmux.app's `__tmux-compat`)
- Claude Code's experimental agent-teams mode for native team-spawn
- 4-step closer artifact discipline so every task leaves a paper trail

**You get:**
- Real parallelism (3–10 lanes editing different branches simultaneously)
- One conversation (you talk to the King; the King talks to lanes)
- One audit trail (`tail -n 50 <workspace>/.kingdom/*/logs/master_agent.log` — all projects, one command)
- Zero new runtime (cmux + tmux + jq + gh are common dev tooling)
- macOS-native via cmux.app; Linux/remote-fallback via raw tmux

---

## ❓ FAQ

<details>
<summary><strong>Does this require Opus?</strong></summary>

Yes for the King, Workers, and Co-workers. Watchmen are Sonnet (P1) by default. Sub-agents use Sonnet (P1) / Haiku (P2) / Opus (P3) — lane masters choose based on task weight.

</details>

<details>
<summary><strong>Does this work on Linux?</strong></summary>

The "primary" path (cmux.app) is macOS-only. The "fallback" path uses raw tmux and works on Linux — git worktrees are built-in everywhere. Same artifact protocol on both paths; just the dispatch mechanism differs. See [`TMUX-Guide.md`](TMUX-Guide.md).

</details>

<details>
<summary><strong>What if my project uses different commands?</strong></summary>

Edit `kingdom.json` → `gate.*` arrays per project. The King runs whatever you put there — `cargo check`, `pytest`, `mvn verify`, anything.

</details>

<details>
<summary><strong>Can I have 7 workers?</strong></summary>

Yes. Set `kingdom.json` → `shape.workers = 7`. Soft cap is 10 lanes total (`sanityCap`); the workspace gets cramped past that. Override `sanityCap` in `kingdom.json` if you really want more.

</details>

<details>
<summary><strong>Does it work with squash merge?</strong></summary>

Yes. `kingdom.json` → `git.mergeStyle` can be `merge-commit` (default) or `squash`. The King carves clean feature branches either way.

</details>

<details>
<summary><strong>Can I commit <code>.kingdom/</code> to my workspace?</strong></summary>

`.kingdom/` is outside any project's git by design (workspace root is not a repo). If your workspace IS a repo, gitignore `.kingdom/<project>/logs/` — the config file (`.kingdom/<project>/kingdom.json`) is fine to commit and useful for onboarding new agents.

</details>

<details>
<summary><strong>What's a task file?</strong></summary>

Every assignment to a lane creates one at `.kingdom/<project>/tasks/<UTC>__<lane>__<sub-task-id>.md`. It's a checkbox markdown doc with the multi-layer plan, progress notes, and final summary. Lane master writes; sub-agents and you can read it to follow along. Never deleted, never reused. Full schema in [`workers.md`](.kingdom/.setting/workers.md) → "Task file".

</details>

<details>
<summary><strong>What happens if a lane crashes?</strong></summary>

State persists in the worktree filesystem. Re-running `/kingdom:start <project>` detects existing worktrees and `cd`s into them (resume) instead of `git worktree add` (create). The 4-step closer's sentinel flag is the source of truth — if the flag is present, the lane finished; if not, dispatch a fix-task.

</details>

<details>
<summary><strong>Can I run this without manaflow/cmux?</strong></summary>

Yes. `/kingdom:start` auto-detects what's available. If cmux.app isn't running, it falls back to raw tmux automatically — no config change, no extra tools required.

</details>

<details>
<summary><strong>What is `/kingdom:update` for?</strong></summary>

A forced audit sweep. Spawns a Sonnet sub-agent that re-reads every task file in `.kingdom/<project>/tasks/`, cross-checks each checkbox against `git log`, backfills orphan raw artifacts (raw with no curated digest), repairs missing `master_agent.log` summary lines, and flags higher-risk items (stale digests to rewrite, task files to merge, suspect "claimed-done-but-no-commit" entries) for King review. Idempotent — safe to run any time. Watchman does the same low-risk fixes continuously during idle `/loop` time; `/kingdom:update` is the explicit one-shot version.

</details>

<details>
<summary><strong>Does the watchman edit my files?</strong></summary>

Only audit artifacts under `.kingdom/<project>/{tasks,logs}/`, and only for **low-risk** fixes (tick a stale checkbox when a matching commit is found, backfill a missing log line, fix a dead `[[name]]` link). It NEVER edits project source code, role specs, `kingdom.json`, or `.git/`. **High-risk** changes (digest rewrites, task-file merges, archive moves) are flagged to `WATCH_DOCS_AUDIT.md` — King decides + acts. Full split in [`watchmans.md`](.kingdom/.setting/watchmans.md) → "Docs audit duty".

</details>

---

## 🧑‍💼 Contributing

The kingdom is opinionated by design — most defaults exist because of a specific failure mode. Before changing a rule, read the role file that owns it ([`.kingdom/.setting/`](.kingdom/.setting/)).

Especially welcome:

- Brew tap formula (`brew install chatthong/tap/kingdom`)
- Linux dev-container preset
- Per-stack `kingdom.json` examples (Rust, Go, Python+Django, Next.js+TRPC, etc.)
- VS Code task definitions that wrap `/kingdom:start`

---

## 📜 License

See [LICENSE](LICENSE).

---

<div align="center">

<sub>Built on [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux), git worktrees (built-in ≥ git 2.5), and Claude Code's experimental agent-teams mode.</sub>

<sub>The kingdom is Claude-only — Codex/Kimi/other-CLI integration is out of scope.</sub>

<br/>

If this saves you time, ⭐ the repo.

</div>
