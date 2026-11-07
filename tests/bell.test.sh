#!/usr/bin/env bash
# bell forwarding, and the bell-action question (D2).
# The user's tmux has a global `bell-action none`; these tests run with it.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p /tmp/pihatch-bell
start_server
T set -g bell-action none
T set -g @pi_hatch_command 'sleep 600'
read -r _ _ < <(newpane work w1)
read -r _ _ < <(newpane work w2) # origin: a window that is not its session's current one
read -r _ _ < <(newpane pi-other o1) # a hatch-named session used as a (bad) origin
T run-shell "$ROOT/pi_hatch.tmux"
attach_client main
origin="$(T display-message -p -t work:w2 '#{window_id}')"
flag() { T display-message -p -t "$1" '#{window_bell_flag}'; }
ring() { printf '\a' >"$(T display-message -p -t "$1" '#{pane_tty}')"; }
reset() { T select-window -t work:w2; T select-window -t work:w1; }
flag_is() { [ "$(flag "$1")" = "$2" ]; }

ok "alert-bell hook installed" bash -c 'tmux -L "$0" -f /dev/null show-hooks -g | grep -q "alert-bell.*bell.sh"' "$SOCK"

# Control (D2): a hatch-named session WITHOUT bell-action any, global none -> hook never fires.
T new-session -d -s pi-ctl "exec sleep 600"
T set-option -t pi-ctl @pi_hatch_origin "$origin"
ring pi-ctl
sleep 0.8
ok "D2 control: bell-action none -> forwarding does not happen" flag_is work:w2 0
reset

# Real launch: launch.sh sets bell-action any on the hatch session.
T run-shell -b "$ROOT/scripts/launch.sh /tmp/pihatch-bell '$origin' main"
sess="pi-$(printf '/tmp/pihatch-bell\n' | md5sum | cut -c1-8)"
ok "hatch session launched" wait_for T has-session -t "$sess"
ok "launch.sh sets bell-action any on the session" test "$(T show-options -t "$sess" -v bell-action)" = any
sleep 0.5
ring "$sess"
ok "bell in hatch session highlights the origin window" wait_for flag_is work:w2 1
reset

# Loop guard: origin that is itself a hatch session -> no forwarding.
T set-option -t "$sess" @pi_hatch_origin "$(T display-message -p -t pi-other:0 '#{window_id}')"
ring "$sess"
sleep 0.8
ok "origin in a hatch session is not forwarded" flag_is pi-other:0 0

# Opt-out
stop_server
start_server
T set -g @pi_hatch_forward_bell off
T run-shell "$ROOT/pi_hatch.tmux"
ok "forward_bell off installs no hook" bash -c '! tmux -L "$0" -f /dev/null show-hooks -g | grep -q "bell.sh"' "$SOCK"

finish bell
