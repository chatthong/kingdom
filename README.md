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

### Multi-agent orchestration kit for Claude Code

**One King. N workers. Auditable parallel work, any domain you version with git.**

`v0.31.1: Consumer-test fix release. Worker spawn now reliably launches claude REPL (fixes silent dispatch-to-shell on workers/co-workers). Poll loop's overlay call points at the right helper name (was silently a no-op). New: R45 mandates Haiku-army doc orientation for all roles (10 parallel reads of wayfinding + recent docs). Watchman Duty 1 expanded into senior-dev review with doc cross-check. Workers now write mandatory smoke-test reports to docs/test-reports/ (format-discovery first). Sub-agent pool defaults to Sonnet.`

![Version](https://img.shields.io/badge/version-0.31.1-success)
![License](https://img.shields.io/badge/license-see%20LICENSE-blue)
![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-purple)
![macOS](https://img.shields.io/badge/macOS-primary-black)
![Linux](https://img.shields.io/badge/Linux-tmux%20fallback-333333)
![git worktrees](https://img.shields.io/badge/git%20worktrees-built--in-orange)
![Multi-Agent](https://img.shields.io/badge/multi--agent-orchestration-9333ea)
![cmux.app](https://img.shields.io/badge/cmux.app-native-f59e0b)

[Quick start](#-quick-start) · [Install](#-install) · [Contract](#-the-contract) · [Slash commands](#-slash-commands) · [Docs](#-docs)

</div>

---

## ⚡ Quick start

```bash
# 1. Install (in any Claude Code session)
/plugin marketplace add chatthong/kingdom
/plugin install kingdom@kingdom

/kingdom:init my-app          # scaffold once — workspace + git worktrees (~90s)
/kingdom:self-care            # check prereqs once — cmux.app, tmux, jq, gh, git

/kingdom:work my-app          # daily — audit, spawn, dispatch, poll
/kingdom:save my-app          # end of session — snapshot state, close lane workspaces
```

`/kingdom:work` is the daily ritual. It audits the project, spawns lanes, prints a kickoff brief with your local date+time and a Suggested next task, then auto-dispatches and gates work until something needs your approval. You stay in one chat with the King. At end of day, `/kingdom:save` snapshots lane + task state so the next `/kingdom:work` picks up where you left off.

```bash
# ── default daily ────────────────────────────────────────────────
/kingdom:work my-app                          # use kingdom.json shape

# ── caps + targets (pace control) ────────────────────────────────
/kingdom:work my-app cap=5                    # hard stop at 5 task-completions today
/kingdom:work my-app target=30-50/week        # soft budget; auto-splits to ~6-10/day
/kingdom:work my-app target=30-50/day         # heavy pace; auto-splits to ~150-250/week

# ── shape overrides (per-session, not persisted to kingdom.json) ─
/kingdom:work my-app worker=1                 # solo prototype: 1 autonomous worker
/kingdom:work my-app worker=2 co-worker=1     # mixed: 2 autonomous + 1 paired
/kingdom:work my-app worker=0 co-worker=2     # pair-programming day, no auto work
/kingdom:work my-app worker=5 watchman=2      # unattended overnight, heavy monitoring
/kingdom:work my-app worker=1 co-worker=0 watchman=0   # quick session, no overhead

# ── combined: shape + cap + target ───────────────────────────────
/kingdom:work my-app worker=3 co-worker=1 cap=8                   # full day, capped
/kingdom:work my-app worker=5 watchman=2 target=40-60/day         # heavy auto, weekly visible
/kingdom:work my-app worker=2 co-worker=1 target=30-50/week       # standard pace
```

**Pick a shape by situation:**

| Situation | Recommended | Why |
|---|---|---|
| Solo prototype / one-person repo | `worker=1 co-worker=0 watchman=0` | Minimal overhead; one autonomous lane |
| Standard day (default) | `worker=3 co-worker=1 watchman=1` | 3 autonomous + 1 paired + monitoring |
| UI/design session | `worker=0 co-worker=2 watchman=1` | All paired with you; watchman covers `develop` |
| Heavy autonomous batch | `worker=5 co-worker=0 watchman=2` | Maximum parallelism; double watchmen for safety |
| Quick focused session | `worker=2 cap=3` | 2 lanes, hard stop at 3 task-completions |
| Sustainable weekly cadence | `worker=3 target=30-50/week` | Soft budget; King paces dispatch to hit band |

You now have **5 AI agents** in cmux.app's sidebar: 👑 King, 3× 👷 workers, 1× 🧑‍💼 co-worker, 1× 🕵️ watchman — each in its own colour-coded workspace, all coordinated through your one chat with the King.

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

A Claude Code plugin that turns one session into a coordinated team: each lane in its own git worktree, each branch isolated until you approve the push. The King gates every commit, writes audit artifacts you can grep next month, and never touches your main checkout. No new runtime, no daemons.

**Domain-agnostic by design.** Anything you version in git — code, research, finance models, scientific notebooks, manuscripts — the kingdom can orchestrate. Workers are generic capacity; `gate.*` commands are arbitrary bash. Same kit whether your "tests" run `pytest`, `Rscript`, or `pandoc --validate`.

---

## ✨ Why kingdom?

- **Real parallelism** — 3-10 lanes editing different branches simultaneously, isolated by `git worktree`
- **One conversation** — you talk to the King; the King talks to the lanes; you never juggle panes
- **Native cmux.app feel** — every role gets its own colour-coded workspace; notifications fire as blue rings, badges, and bell-panel entries
- **Full audit trail** — every task leaves a 4-step closer artifact: raw log, curated digest, master log line, sentinel flag
- **Zero new runtime** — cmux + tmux + jq + gh are standard dev tooling; the protocol is plain text
- **Skill-aware** — King and lanes auto-pick from the Claude Code skill catalog (`nextjs-best-practices`, `prisma-cli`, `superpowers:test-driven-development`, etc) per-task. Domain-routed via [`skill-routing.md`](.kingdom/.setting/skill-routing.md), with auto-discovery fallback when the routing table doesn't match.

---

## 🚀 Install

```bash
/plugin marketplace add chatthong/kingdom
/plugin install kingdom@kingdom
/kingdom:self-care
```

`/kingdom:self-care` tells you what's missing (cmux.app, tmux, jq, gh, settings.json keys) and offers to fix it.

---

## 🛡 The contract (what kingdom won't touch)

- ❌ Your project files outside `.worktrees/<lane>/` — main checkout untouched until you say "push"
- ❌ `develop` and `main` — read-only; only `feature/<topic>` reaches origin
- ❌ Pushes — never without your explicit "push?" approval
- ❌ Your `~/.zshrc`, `~/.gitconfig`, PATH, shell hooks — zero modifications
- ❌ Your `.gitignore` — kingdom adds ONE line (`.worktrees/`) and stops there
- ✅ `rm -rf .kingdom/ .worktrees/` removes the kingdom; your project, git history, branches survive intact

---

## 🎭 Roles at a glance

| Role | Model | What it does | Spec |
|---|---|---|---|
| 👑 **King** | Opus | Orchestrator. Holds your conversation. Sole pusher. Never edits files. | [`kings.md`](.kingdom/.setting/kings.md) |
| 👷 **Worker** | Opus | Autonomous lane. Picks + executes sub-tasks. Spawns own sub-agents (no eco cap). | [`workers.md`](.kingdom/.setting/workers.md) |
| 🧑‍💼 **Co-worker** | Opus | Paired with you. Dormant until you signal. | [`co-workers.md`](.kingdom/.setting/co-workers.md) |
| 🕵️ **Watchman** | Sonnet | Passive monitor (`/loop`, 5-15 min). Smoke + PR babysitting. Never edits, never pushes. | [`watchmans.md`](.kingdom/.setting/watchmans.md) |
| 🐱 **Sub-agent** | Sonnet/Haiku/Opus | One-shot via `Agent(model=…)`. Spawned by King or a lane. | [`workers.md`](.kingdom/.setting/workers.md) |

Full role write-ups: [`docs/roles.md`](docs/roles.md).

---

## 🔧 Slash commands

| Command | What it does |
|---|---|
| **`/kingdom:work [<project>] [target=N-M/<day\|week\|month>] [cap=N] [worker=N] [co-worker=N] [watchman=N]`** | **THE daily ritual.** Audit + spawn + kickoff brief (local date+time + Suggested next task) + auto-gate-poll loop. `target=` is a soft budget; `cap=` is a hard daily ceiling. Per-session shape overrides via `worker=N` / `co-worker=N` / `watchman=N`. The one command you type every morning. |
| `/kingdom:init [<project>]` | Workspace + optional project scaffold. See [`docs/configuration.md`](docs/configuration.md) for shape choices. |
| `/kingdom:self-care` | Check prerequisites: cmux.app, tmux, jq, gh, git ≥ 2.5, settings.json keys. Re-run anytime. |
| `/kingdom:save [<project>]` | State snapshot. Writes current lane + task state to `state.json`; closes lane workspaces. Keeps King's workspace by default. No commits or pushes — those go through the normal push-approval gate. |

---

## 📚 Docs

| Topic | Where |
|---|---|
| Work cycle: first-time setup, every-day command, plugin updates | [`docs/work-cycle.md`](docs/work-cycle.md) |
| Configuration: project shapes, `kingdom.json`, `gate.*` keys | [`docs/configuration.md`](docs/configuration.md) |
| Roles: King, workers, co-workers, watchmen, sub-agents | [`docs/roles.md`](docs/roles.md) |
| Branch model: lifecycle, overlay, two-tier gate, three rules | [`docs/branch-model.md`](docs/branch-model.md) |
| cmux.app integration: sidebar, notifications, three-tier hierarchy | [`docs/cmux-integration.md`](docs/cmux-integration.md) |
| How it works: King's role, lane mechanics, 4-step closer | [`docs/how-it-works.md`](docs/how-it-works.md) |
| Why: the problem kingdom solves | [`docs/why.md`](docs/why.md) |
| FAQ | [`docs/faq.md`](docs/faq.md) |
| Internal role specs (King reads these at session start) | [`.kingdom/.setting/`](.kingdom/.setting/) |
| Rules: priority-tiered enforceable rules | [`.kingdom/.setting/rules.md`](.kingdom/.setting/rules.md) |
| Changelog | [`CHANGELOG.md`](CHANGELOG.md) |

---

## 🧑‍💼 Contributing

The kingdom is opinionated by design; most defaults exist because of a specific failure mode. Before changing a rule, read the role file that owns it ([`.kingdom/.setting/`](.kingdom/.setting/)).

Especially welcome:

- Brew tap formula (`brew install chatthong/tap/kingdom`)
- Linux dev-container preset
- Per-stack `kingdom.json` examples (Rust, Go, Python+Django, Next.js+TRPC, etc.)
- VS Code task definitions that wrap `/kingdom:work`

---

## 📜 License

See [LICENSE](LICENSE).

---

<div align="center">

<sub>Built on [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux), git worktrees (built-in ≥ git 2.5), and Claude Code's experimental agent-teams mode.</sub>

<sub>The kingdom is Claude-only. Codex/Kimi/other-CLI integration is out of scope.</sub>

<br/>

If this saves you time, ⭐ the repo.

</div>
