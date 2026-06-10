# self-learn-summary

**Fires when:** `/kingdom:self-learn` finishes its 3-layer doc-grounding sweep (U10, v0.44.0). Any role can run it; it renders 1-3 of these cards (Big picture / Map / Deep notes).
**Used by:** [`commands/self-learn.md`](../../../commands/self-learn.md) — Shared spec 2.

## Template

```markdown
> [!NOTE]
> ```
> ╭─ 📚 Self-learn · ${PROJECT} · ${N_FILES_READ} files ───╮
> │  ${BIG_PICTURE}                                         │
> │                                                         │
> │  Map (where things live):                               │
> │  ${MAP}                                                 │
> │                                                         │
> │  Deep notes / open questions:                           │
> │  ${DEEP_NOTES}                                          │
> ╰────────────────────────────────────────────────────────╯
> ```
```

## Variables

| Var | Source | Example |
|---|---|---|
| `${PROJECT}` | active project | `my-app` |
| `${N_FILES_READ}` | total files read across the 3 layers | `47` |
| `${BIG_PICTURE}` | 2-5 line synthesis: what the project is, its stack, its top-level flow | `Next.js webshop + a Fastify API; develop→main; auth via httpOnly cookie.` |
| `${MAP}` | bulleted "X lives in Y" wayfinding lines (entry points, config, docs index) | `• routes → src/app/  • db → prisma/  • docs index → docs/README.md` |
| `${DEEP_NOTES}` | Layer-3 load-bearing notes + open questions the reader should resolve before working | `• Migrations are squashed quarterly  • Open: where does SEO metadata come from?` |

## Variants

The command renders **1 to 3** of these cards from a single `/kingdom:self-learn` run, splitting the content so each card stays one-screen:

| Card | Carries | When |
|---|---|---|
| **card 1 — Big picture** | `${BIG_PICTURE}` only (the Map / Deep-notes rows drop to empty → their lines are removed by `render_card`) | always |
| **card 2 — Map** | `${MAP}` (where things live) | when Layer 1+2 produced a non-trivial wayfinding map |
| **card 3 — Deep notes** | `${DEEP_NOTES}` (open questions, load-bearing details) | optional — only when Layer 3 flagged something |

Each empty `${VAR}` and its line is dropped by `render_card` (the shared empty-row rule), so a single-card render collapses cleanly to just the populated section.

## Notes

- The three layers (orientation → essentials → deep pass) and their file caps live in [`commands/self-learn.md`](../../../commands/self-learn.md) (Shared spec 2). This card is purely the OUTPUT surface.
- No ANSI. Box-drawing + a single `[!NOTE]` wrapper like its siblings.
