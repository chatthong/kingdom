#!/usr/bin/env bash
# kingdom function: rules_digest
#
# Emits the compact tiered rule list (R## — title, every rule) + the per-turn
# self-check header, generated from rules/index.md so it NEVER drifts (add/edit a
# rule and the digest updates itself).
#
# This is the kingdom's settings-free re-injection vehicle. There is no harness
# hook (hooks need .claude/settings.json, which would fire on NON-kingdom sessions
# too). Instead the kingdom re-injects this digest through its OWN prompt stream —
# every King poll-loop tick, every dispatch brief, every looped role (watchman) —
# so the rules stay in context throughout kingdom work and ONLY during it. Pure
# kingdom-scoped: not running kingdom => this never fires => normal sessions clean.
#
# Honest limit: this re-injects per CYCLE/DISPATCH, the closest to per-reply
# achievable without a hook — not a hard guarantee. Slimming the ruleset makes it
# bite harder, but the digest tracks whatever the registry holds.
#
# Usage: rules_digest [path-to-rules/index.md]   (defaults to $WS workspace copy)

rules_digest () {
  local idx="${1:-$WS/.kingdom/.setting/rules/index.md}"
  [ -f "$idx" ] || { echo "⚠️ rules_digest: registry not found ($idx)" >&2; return 1; }
  cat <<'HDR'
━━━ KINGDOM · re-read EVERY reply (R14) · before acting, answer in 3 lines: ━━━
  1. ROLE: King / worker / co-worker / Senior / watchman?
  2. RULES IN PLAY: which R-numbers govern what I'm about to do this turn? (cite them)
  3. SURFACE: explaining via a card (render_card)? if not, why not?
  Skipping 1-3 is itself an R14 violation.
HDR
  awk -F'|' '
    /^\| R[0-9]+ \| [123] \|/ {
      id=$2;    gsub(/ /,"",id);
      tier=$3;  gsub(/ /,"",tier);
      title=$4; sub(/^ +/,"",title); sub(/ +$/,"",title);
      rules[tier]=rules[tier] sprintf("  %s — %s\n", id, title);
    }
    END {
      print "🔴 TIER 1 — IRON-CLAD (never violate):"; printf "%s", rules["1"];
      print "🟠 TIER 2 — STRONG DEFAULTS:";           printf "%s", rules["2"];
      print "🔵 TIER 3 — CONVENTIONS:";               printf "%s", rules["3"];
    }
  ' "$idx"
}
