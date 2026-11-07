#!/usr/bin/env bash
# Test helpers: an isolated tmux server, never the user's live one.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOCK="pihatch-test-$$"
FAILS=0

T() { tmux -L "$SOCK" -f /dev/null "$@"; }
start_server() { T new-session -d -s main -x 200 -y 50 "sleep 600"; }
stop_server() { T kill-server 2>/dev/null; rm -f "/tmp/tmux-$(id -u)/$SOCK"; }
trap stop_server EXIT

# ok <name> <command...>: run a check, report it, count failures.
ok() {
  local name="$1"
  shift
  if "$@"; then echo "  ok   $name"; else echo "  FAIL $name"; FAILS=$((FAILS + 1)); fi
}

# finish <suite>: print PASS/FAIL and exit accordingly.
finish() {
  if [ "$FAILS" -eq 0 ]; then echo "$1: PASS"; else echo "$1: FAIL ($FAILS)"; exit 1; fi
}
