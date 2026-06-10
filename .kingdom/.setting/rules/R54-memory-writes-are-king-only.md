### R54. Memory writes are King-only — lanes request via inbox — Tier 2 (v0.44.0)

Only the **King** writes to user/project memory (`MEMORY.md`, `feedback_*.md`, project-memory stores). Lanes, co-workers, Seniors, and the watchman **never** edit memory directly. A scattered fleet writing memory would produce conflicting, drifted, and duplicate notes — exactly the stale-snapshot failure R34 already fights.

**Lane side:** when a lane discovers something genuinely memory-worthy (a durable project fact, a convention, a recurring user preference), it does NOT write memory. It sends `inbox_send king memory-request <task> yes "<proposed memory line>"` (R55) and keeps working.

**King side:** on a `memory-request` inbox item, the King validates the proposal against [R34](R34-tier-1-rules-override-memory.md) (the plugin rules override memory — a proposal that contradicts a rule is declined, never written) and against existing memory (no duplicates). It then writes the memory itself (or declines), and replies to the requesting lane via `inbox_reply`. The King is the single writer, so memory stays coherent.

**Why Tier 2:** a missed memory note costs only re-derivation later; it doesn't lose committed data or break a gate. But funnelling all writes through one validated author is the strong default that keeps memory trustworthy. Complements R34 (rules win over memory) and the consumer-side no-blind-memory-writes discipline. See each lane role doc's conventions + king.md → Inbox triage.
