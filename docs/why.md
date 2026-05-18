# 🤔 Why?

> Part of the [kingdom](../README.md) docs.

**Problem:** running multiple Claude sessions in parallel means each one editing the same files, fighting over git state, broken builds, lost work.

**Existing fixes:** `git worktree` gives isolated checkouts but no orchestration. Manual tmux gives panes but no audit trail. Headless `claude -p` chains give batch but no visibility.

**kingdom:** an opinionated stack that puts these together:

- `git worktree` for isolation (built into git ≥ 2.5)
- tmux-protocol for dispatch (via cmux.app's `__tmux-compat`)
- Claude Code's experimental agent-teams mode for native team-spawn
- 4-step closer artifact discipline so every task leaves a paper trail

**You get:**

- Real parallelism (3-10 lanes editing different branches simultaneously)
- One conversation (you talk to the King; the King talks to lanes)
- One audit trail (`tail -n 50 <workspace>/.kingdom/*/logs/master_agent.log`, all projects, one command)
- Zero new runtime (cmux + tmux + jq + gh are common dev tooling)
- macOS-native via cmux.app; Linux/remote-fallback via raw tmux

## See also

- [`how-it-works.md`](how-it-works.md): the mechanics behind the claims
- [`branch-model.md`](branch-model.md): the discipline that keeps parallel lanes from stepping on each other
- [`faq.md`](faq.md): "what if" questions
