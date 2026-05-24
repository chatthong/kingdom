#!/usr/bin/env bash
# kingdom function: cmux_rpc
# Low-level passthrough to cmux's documented RPC surface (e.g. surface.send_text, workspace.list).
#   cmux_rpc workspace.list
#   cmux_rpc surface.send_text '{"surface_id":"surface:7","text":"claude\n"}'
# Prefer the higher-level wrappers (cmux_send etc.) where one exists. See `cmux capabilities`.
cmux_rpc () {
  local method="$1"; shift
  cmux rpc "$method" "$@" 2>/dev/null
}
