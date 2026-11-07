#!/usr/bin/env bash
# Chunk 2: launch / reattach / per-path sessions / toggle.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p /tmp/pihatch-a /tmp/pihatch-b
start_server
T set -g @pi_hatch_command 'sleep 600'
attach_client main
main_pane="$(T display-message -p -t main '#{pane_id}')"
win="$(T display-message -p -t main '#{window_id}')"
sa="pi-$(printf '/tmp/pihatch-a\n' | md5sum | cut -c1-8)"
sb="pi-$(printf '/tmp/pihatch-b\n' | md5sum | cut -c1-8)"

# press <pane> <dir>: what the y binding does when pressed in <pane>
# tmux rejects a new popup while the previous one is still tearing down, so settle first.
press() {
  sleep 0.5
  T run-shell -b -t "$1" "$ROOT/scripts/launch.sh '$2' '$win' '$(T display-message -p -t "$1" '#{session_name}')'"
}

press "$main_pane" /tmp/pihatch-a
ok "first launch creates session" wait_for T has-session -t "$sa"
ok "popup attached to it" wait_for in_session "$sa"
ok "origin window stored" test "$(T show-options -qv -t "$sa" @pi_hatch_origin)" = "$win"
ok "detach-on-destroy on" test "$(T show-options -qv -t "$sa" detach-on-destroy)" = on

# toggle: y pressed inside the popup (pane of the hatch session)
press "$(T display-message -p -t "$sa" '#{pane_id}')" /tmp/pihatch-a
ok "toggle detaches the popup client" wait_for not_in_session "$sa"
ok "Pi keeps running after toggle" T has-session -t "$sa"

press "$main_pane" /tmp/pihatch-a
ok "relaunch reattaches" wait_for in_session "$sa"
ok "relaunch reuses session (2 sessions, 1 pane)" test "$(nsessions)" = 2 -a "$(T list-panes -s -t "$sa" | wc -l)" = 1
press "$(T display-message -p -t "$sa" '#{pane_id}')" /tmp/pihatch-a
wait_for not_in_session "$sa"

press "$main_pane" /tmp/pihatch-b
ok "other path -> other session" wait_for in_session "$sb"
ok "now 3 sessions" test "$(nsessions)" = 3
press "$(T display-message -p -t "$sb" '#{pane_id}')" /tmp/pihatch-b
wait_for not_in_session "$sb"

T run-shell -t "$main_pane" "$ROOT/scripts/launch.sh /tmp/pihatch-missing-dir '$win' main"
ok "missing dir creates no session" test "$(nsessions)" = 3

ok "bash -n" bash -n "$ROOT/scripts/launch.sh"
finish launch
