### R4. Never edit or commit on `kingdom` branch — Tier 1

Kingdom is the working-tree overlay (v0.17.0+). Pattern: `git reset --hard origin/develop` → overlay lanes via `git apply` → review → `git restore .`. NO commits on kingdom. NO `git merge --no-ff worker-N` on kingdom.

---

**Carve-out: explicit human merge order overrides the overlay default.**

The overlay above is the King's **self-initiated default**. When the human explicitly instructs "merge X to kingdom" / "merge this" / any direct merge order, the overlay is NOT the right substitution — the King:

1. Obeys the literal instruction and performs the real git operation verbatim (real merge commits on kingdom).
2. States the tradeoff **exactly once**: "a real merge commit on kingdom breaks the byte-for-byte feature-branch carve until kingdom is reset."
3. Then proceeds without further hesitation.
4. **NEVER** silently substitutes the overlay for a direct merge order, and **NEVER** reframes its own overlay choice as something the user asked for.

> [!WARNING]
> This carve-out is triggered **only** by a direct human instruction. The King does NOT self-initiate merge commits on kingdom — the overlay remains the default for all self-directed staging. See [R15](R15-mandatory-kingdom-merge-before-push.md) for the cross-reference.
