### R36. Visible workspace progress BEFORE any processing — Tier 1 (v0.28.0+)

On `/kingdom:work` invocation, the sequence MUST be (in this order, no exceptions):

1. **Within ~1 second of command receipt:** King renames its OWN workspace to `👑 King · ${PROJECT}` (amber, pinned) and sets its description to `Starting ${PROJECT}…`. The user must see immediate visual feedback that the kingdom is responding to the command. No "Crunched for 30s while you wait staring at unchanged sidebar."
2. **Within ~5-10 seconds:** all lane workspaces from `kingdom.json.shape` are spawned in parallel — every `worker-N`, `co-worker-N`, `watchman-N` appears in the cmux sidebar BEFORE any audit/dispatch processing begins. Sidebar shows the kingdom shape immediately so the user knows the lanes are alive and ready.
3. **Render `spawn-complete` card** with the full lane roster as final visual confirmation.
4. **ONLY AFTER step 3** does any further processing (audit, suggested-task synthesis, dispatch) begin.

**Anti-pattern banned:** "I'll go think for a minute then spawn lanes when I've planned the day." The user sees an unchanged sidebar with King's "✳ Claude Code" auto-title while heavy planning runs. Looks dead. Multiple morning incidents traced to this perception gap.

**Sequence is sequential at the surface level but parallel inside step 2.** Renames + spawns are independent operations that can run as background `&` jobs; what matters is the sidebar SHOWS the full kingdom shape within ~10 seconds of command receipt.
