# role-grounded

**Fires when:** a `/kingdom:self-<role>` command finishes re-reading the kingdom rules + that role's spec.
**Used by:** [`commands/self-king.md`](../../../commands/self-king.md), `self-worker.md`, `self-co-worker.md`, `self-watchman.md`, `self-senior.md` (via [`reference/role-bootstrap.md`](../reference/role-bootstrap.md)).

## Template

```markdown
> [!NOTE]
> ```
> ╭─ ${EMOJI} Re-grounded · ${ROLE} · ${MODEL} ─────────────────────╮
> │  Read: rules/index.md (Tier-1 ×10) + roles/${ROLE}.md         │
> │        ${SUBDOCS}
> │                                                         │
> │  ✅ I may:   ${ALLOWED}
> │  🚫 Never:   ${BANNED}
> │  🚦 Gate:    ${GATE}
> │  📦 Closer:  ${CLOSER}
> │                                                         │
> │  ⚠ THE one: ${THE_ONE_NEVER}
> ╰─────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${EMOJI}` | role emoji (R17) | `👷` |
| `${ROLE}` | the role being grounded | `worker` |
| `${MODEL}` | role's default model | `Opus` |
| `${SUBDOCS}` | sub-docs read in step 3 (single-file roles → none) | `(none — single file)` |
| `${ALLOWED}` | allowed verbs (from role-bootstrap.md table) | `read · edit+commit on worker-N · spawn sub-agents · closer` |
| `${BANNED}` | the hard bans | `push · create feature/* · commit on kingdom/feature/*` |
| `${GATE}` | gate tier the role owns | `Tier-1 in own worktree` |
| `${CLOSER}` | closer obligation | `4-step closer every task (R22)` |
| `${THE_ONE_NEVER}` | the single most important "never" | `never push; the King carves feature/<topic> (R9)` |

## Notes

- `[!NOTE]` (blue) — informational re-grounding, same weight as `daily-status`. Not a high-attention alert; it's a "here's who I am again" confirmation.
- Every role is now a single file (v0.40.0), so `${SUBDOCS}` is `(none — single file)` for all five — never render a hollow line.
- The card is the visible proof the role actually re-read its spec, not just claimed to. Lanes render it after a `/kingdom:self-<role>` at spawn (R52) or an on-demand re-ground.
