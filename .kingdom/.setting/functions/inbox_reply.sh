#!/usr/bin/env bash
# kingdom function: inbox_reply
# Broker inbox sugar (R55): post an `info` reply (needs-reply: no) to any actor.
# Equivalent to `inbox_send <to> info <task_id> no <message...>`.
#   inbox_reply <to> <task_id> <message...>
#     <to>       the recipient (king | worker-N | co-worker-N | senior-N | watchman-N | all)
#                Caller names the recipient explicitly because this is a broker feed —
#                any actor may reply to any other actor, not just back to the sender.
#     <task_id>  the task this concerns (or "-" if none)
#     <message...> free-text body
inbox_reply () {
  local to="$1" task="$2"; shift 2 2>/dev/null
  [ -n "$to" ] || { printf 'inbox_reply: usage: inbox_reply <to> <task_id> <message...>\n' >&2; return 1; }
  inbox_send "$to" info "${task:--}" no "$@"
}
