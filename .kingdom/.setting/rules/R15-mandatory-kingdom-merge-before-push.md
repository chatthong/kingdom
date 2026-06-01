### R15. Mandatory kingdom overlay review before push prompt — Tier 2 (v0.15.1+, hardened v0.37.0)

After gate-pass, King overlays the lane onto kingdom + prints review surface + asks the user to review BEFORE asking R1 push. No "gate passed → push?" — always "gate passed → review on kingdom → push?".

**Overlay the FULL gated set, not one lane at a time.** When ≥2 lanes are push-eligible, the King overlays ALL of them onto the kingdom working tree together, so the user sees every in-flight change as uncommitted files in ONE review surface (GitHub Desktop's Changes tab / `git diff`). The user reviews the union, then approves. The King MUST NOT carve+push one lane and then wipe the overlay before the rest are shown — every lane the user is about to authorise has to be visible as dirty files at review time. ("I must see all the dirty files / all N PRs on the kingdom branch before you push" is the contract.)

**The overlay IS the review surface — it stays dirty until push.** Per [R29](R29-after-every-successful-push-kingdom.md) the overlay is discarded ONLY after the gated work is pushed, never before. Resetting/cleaning kingdom while gated work awaits review destroys exactly what the user needs to see.
