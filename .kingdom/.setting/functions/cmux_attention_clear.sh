#!/usr/bin/env bash
# kingdom function: cmux_attention_clear

cmux_attention_clear () {
  cmux workspace-action --action mark-read --workspace "${1:-$CMUX_WORKSPACE_ID}" 2>/dev/null
}
