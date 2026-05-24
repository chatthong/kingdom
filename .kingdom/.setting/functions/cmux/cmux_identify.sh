#!/usr/bin/env bash
# kingdom function: cmux_identify
# Return the caller's cmux context as JSON (caller/focused workspace_ref + surface_ref, socket_path).
# See reference/cmux.md § Identify.
cmux_identify () {
  cmux identify --json 2>/dev/null
}
