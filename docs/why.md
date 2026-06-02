# 🤔 Why?

> Part of the [kingdom](../README.md) docs.

**Problem:** running multiple Claude sessions in parallel means each one editing the same files, fighting over git state, broken builds, lost work.

**Existing fixes:** `git worktree` gives isolated checkouts but no orchestration. Manual tmux gives panes but no audit trail. Headless `claude -p` chains give batch but no visibility.

**kingdom:** an opinionated stack that puts these together:

- `git worktree` for isolation (built into git ≥ 2.5)
- Three auto-detected dispatch backends (no config switch): cmux.app (primary, macOS), raw tmux (fallback, Linux or non-cmux macOS), headless `claude -p` (last resort)
- A standalone case (neither cmux nor tmux) that falls back to in-process Agent() sub-agents
- 4-step closer artifact discipline so every task leaves a paper trail

**You get:**

- Real parallelism (many lanes editing different branches simultaneously — up to ~16 in a documented fleet)
- One conversation (you talk to the King; the King talks to lanes)
- One audit trail (`tail -n 50 <workspace>/.kingdom/*/logs/master_agent.log`, all projects, one command)
- Zero new runtime (git + cmux/tmux + jq + gh are common dev tooling)
- macOS-native via cmux.app; Linux or non-cmux macOS via raw tmux; headless `claude -p` as a last-resort standalone fallback

## See also

- [`how-it-works.md`](how-it-works.md): the mechanics behind the claims
- [`branch-model.md`](branch-model.md): the discipline that keeps parallel lanes from stepping on each other
- [`faq.md`](faq.md): "what if" questions
