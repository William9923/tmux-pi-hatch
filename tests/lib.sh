#!/usr/bin/env bash
# Test helpers: an isolated tmux server, never the user's live one.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Never inherit the caller's tmux context: it would leak into the test server.
unset TMUX TMUX_PANE
SOCK="pihatch-test-$$"
FAILS=0

T() { tmux -L "$SOCK" -f /dev/null "$@"; }
start_server() { T new-session -d -s main -x 200 -y 50 "sleep 600"; }
stop_server() { T kill-server 2>/dev/null; rm -f "/tmp/tmux-$(id -u)/$SOCK"; }
CLIENTS=()
trap '[ ${#CLIENTS[@]} -gt 0 ] && kill "${CLIENTS[@]}" 2>/dev/null; stop_server' EXIT

has_client() { [ -n "$(T list-clients)" ]; }

# attach_client <session>: a real client on a pty, so popups and detach can be tested.
attach_client() {
  script -qfc "stty cols 200 rows 50; exec tmux -L $SOCK attach -t $1" /dev/null </dev/null >/dev/null 2>&1 &
  CLIENTS+=($!)
  wait_for has_client
}

# wait_for <command...>: retry up to ~5s until the command succeeds.
wait_for() {
  for _ in $(seq 1 50); do "$@" >/dev/null 2>&1 && return 0; sleep 0.1; done
  return 1
}

# in_session <session> : true if a client is attached to it.
in_session() { T list-clients -F '#{session_name}' | grep -qx "$1"; }
not_in_session() { ! in_session "$1"; }

# nsessions: number of sessions
nsessions() { T list-sessions | wc -l; }

SOCKPATH="/tmp/tmux-$(id -u)/$SOCK"
# newpane <session> <window-name> [command]: a pane running a long sleep (after the
# optional command); creates the session if needed. Echoes "pane_id pid".
newpane() {
  local c="${3:+$3; }exec sleep 600"
  if T has-session -t "$1" 2>/dev/null; then
    T new-window -d -t "$1" -n "$2" -P -F '#{pane_id} #{pane_pid}' "$c"
  else
    T new-session -d -s "$1" -n "$2" -x 200 -y 50 -P -F '#{pane_id} #{pane_pid}' "$c"
  fi
}
pstart() { local s; s="$(cat /proc/$1/stat)"; s="${s##*) }"; set -- $s; echo "${20}"; }
# rec <file> <pid> <procStart> <pane> <socket> <status> <updatedAt> [cwd]
rec() {
  jq -n --argjson pid "$2" --arg ps "$3" --arg pane "$4" --arg sock "$5" --arg st "$6" --argjson ts "$7" --arg cwd "${8:-/work/p}" \
    '{pid:$pid,procStart:$ps,paneId:$pane,socket:$sock,cwd:$cwd,status:$st,updatedAt:$ts}' >"$REG/$1.json"
}

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
