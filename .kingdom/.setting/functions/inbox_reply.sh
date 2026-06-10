#!/usr/bin/env bash
# kingdom function: inbox_reply
# King-side sugar (U4, Shared spec 1): post an `info` reply (needs-reply: no) into
# a lane's inbox. Equivalent to `inbox_send <lane> info <task_id> no <message>`.
#   inbox_reply <lane> <task_id> <message...>
inbox_reply () {
  local lane="$1" task="$2"; shift 2 2>/dev/null
  [ -n "$lane" ] || { echo "❌ inbox_reply: usage: inbox_reply <lane> <task_id> <message...>" >&2; return 1; }
  inbox_send "$lane" info "${task:--}" no "$@"
}
