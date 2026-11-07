#!/usr/bin/env bash
# Shared helpers for tmux-pi-hatch.

# get_tmux_option <option-name> <default>
# Echoes the global tmux option value, or the default when unset/empty.
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# session_hash <path>
# Stable 8-char hash of an exact folder path, used in the session name.
session_hash() {
  local out
  out="$(printf '%s\n' "$1" | md5sum)"
  printf '%s' "${out:0:8}"
}
