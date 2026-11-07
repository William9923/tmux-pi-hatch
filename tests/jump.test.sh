#!/usr/bin/env bash
# Chunk 6: jump.sh for manual and managed rows.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

start_server
T set -g @pi_hatch_command 'sleep 600'
read -r _ _ < <(newpane work w1) # origin window lives here
read -r _ _ < <(newpane other o1)
read -r pX _ < <(newpane other o2) # manual target: second window of "other"
read -r _ _ < <(newpane pi-test p1)
read -r pY _ < <(newpane pi-test p2) # managed target: second window of the hatch session
origin="$(T display-message -p -t work '#{window_id}')"
T set-option -t pi-test @pi_hatch_origin "$origin"
attach_client main
client="$(T list-clients -F '#{client_name}' | head -1)"
T set -g @pi_hatch_parent "$client"
sessions_before="$(nsessions)"

csession() { T list-clients -F '#{client_name} #{session_name}' | awk -v c="$client" '$1 == c { print $2 }'; }
export TMUX="$SOCKPATH,0,0"

# manual: focus the existing pane, create nothing
"$ROOT/scripts/jump.sh" "$pX" manual
ok "manual: client switched to the pane's session" test "$(csession)" = other
ok "manual: pane's window and pane selected" test "$(T display-message -p -t other '#{pane_id}')" = "$pX"
ok "manual: no session created" test "$(nsessions)" = "$sessions_before"
unset TMUX

# managed: client moves to the origin window, Pi resumes in a popup over it
T run-shell -b "tmux display-popup -c '$client' -w 90% -h 90% -E '$ROOT/scripts/jump.sh $pY managed'"
ok "managed: popup client attached to the hatch session" wait_for in_session pi-test
ok "managed: outer client moved to the origin window" test "$(csession)" = work
ok "managed: hatch window/pane focused" test "$(T display-message -p -t pi-test '#{pane_id}')" = "$pY"
ok "managed: no duplicate session" test "$(nsessions)" = "$sessions_before"

ok "bash -n" bash -n "$ROOT/scripts/jump.sh"
finish jump
