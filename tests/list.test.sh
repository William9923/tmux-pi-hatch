#!/usr/bin/env bash
# list.sh opens the picker popup, also when pressed inside a Pi popup.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

export PI_HATCH_DIR="$(mktemp -d)"
picker_running() { pgrep -f "$ROOT/scripts/picker.sh" >/dev/null; }
no_picker() { ! picker_running; }
client_of() { T list-clients -F '#{client_name} #{session_name}' | awk -v s="$1" '$2 == s { print $1; exit }'; }

# --- normal case: pressed in an ordinary window
start_server
attach_client main
client="$(client_of main)"
T run-shell -b "$ROOT/scripts/list.sh '$client'"
ok "picker popup opens" wait_for picker_running
ok "parent client recorded" test "$(T show-options -gqv @pi_hatch_parent)" = "$client"
pkill -f "$ROOT/scripts/picker.sh"
wait_for no_picker
stop_server

# --- pressed inside a Pi popup: popup closes, picker reopens on the outer client
start_server
T set -g @pi_hatch_command 'sleep 600'
attach_client main
outer="$(client_of main)"
T set -g @pi_hatch_parent "$outer"
mkdir -p /tmp/pihatch-l
T run-shell -b "$ROOT/scripts/launch.sh /tmp/pihatch-l '$(T display-message -p -t main '#{window_id}')' main"
sess="pi-$(printf '/tmp/pihatch-l\n' | md5sum | cut -c1-8)"
ok "Pi popup open" wait_for in_session "$sess"
inner="$(client_of "$sess")"
sleep 0.5
T run-shell -b "$ROOT/scripts/list.sh '$inner'"
ok "popup client detached" wait_for not_in_session "$sess"
ok "Pi keeps running" T has-session -t "$sess"
ok "picker opened over the outer client" wait_for picker_running

rm -rf "$PI_HATCH_DIR"
finish list
