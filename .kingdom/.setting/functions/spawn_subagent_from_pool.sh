#!/usr/bin/env bash
# kingdom function: spawn_subagent_from_pool

spawn_subagent_from_pool () {
  local model="$1" brief="$2"
  local pool_file="$LOGS/.subagent-pool-${CMUX_WORKSPACE_ID#workspace:}.list"
  local lock="${pool_file}.lock"

  # TOCTOU: two concurrent dispatchers could `head -1` the same surface before either
  # deletes it → both send to one tab. `mkdir` is atomic on every POSIX FS (macOS has no
  # flock), so we use the lock dir as a mutex around the read-and-pop. Bounded wait so a
  # crashed holder never hangs us — on lock-acquire failure we fall through to the
  # standard visible-tab spawn rather than blocking.
  local got_lock="" i surface=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "$lock" 2>/dev/null; then
      got_lock="yes"
      break
    fi
    sleep 0.2
  done

  if [ -z "$got_lock" ]; then
    spawn_subagent_tab "$model" "$brief"   # couldn't claim the mutex → standard spawn
    return
  fi

  # Critical section: read the head, pop it atomically, release the lock.
  surface=$(head -1 "$pool_file" 2>/dev/null)
  if [ -z "$surface" ]; then
    rmdir "$lock" 2>/dev/null
    spawn_subagent_tab "$model" "$brief"   # empty pool → standard spawn
    return
  fi
  sed -i.bak '1d' "$pool_file" && rm "${pool_file}.bak"
  rmdir "$lock" 2>/dev/null

  cmux_tab_action rename --surface "$surface" --title "🐱 sub · $model · $(echo "$brief" | head -c 30)"
  cmux_send "$surface" "$brief"

  spawn_pool_slot &   # refill pool in background
}
