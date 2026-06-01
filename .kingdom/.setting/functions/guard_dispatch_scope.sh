#!/usr/bin/env bash
# kingdom function: guard_dispatch_scope

guard_dispatch_scope () {
  # Inputs: $1 = senior lane, $2 = target worker lane, $3 = space-separated pod members
  # Returns: 0 dispatch allowed; 1 refused (out-of-pod or no visible workspace)
  local senior="$1" target="$2" pod="$3"
  case " $pod " in
    *" $target "*) ;;
    *) echo "❌ R30 VIOLATION: $senior dispatching to $target, not in its pod ($pod). Seniors dispatch in-pod only." >&2; return 1 ;;
  esac
  guard_lane_workspace_exists "$target" || { echo "❌ R30/R36: $target has no visible workspace; $senior cannot dispatch into the void." >&2; return 1; }
  return 0
}
