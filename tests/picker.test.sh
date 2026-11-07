#!/usr/bin/env bash
# the fzf picker, run in a real pane; rows, preview, enter -> jump.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REG="$(mktemp -d)"
start_server
now=$(date +%s)
read -r _ _ < <(newpane main m0)
read -r pA pidA < <(newpane target wa 'echo MARK-A')
read -r pB pidB < <(newpane target wb 'echo MARK-B')
read -r pC pidC < <(newpane target wc 'echo MARK-C')
rec A "$pidA" "$(pstart "$pidA")" "$pA" "$SOCKPATH" ready $((now - 300)) /work/a
rec B "$pidB" "$(pstart "$pidB")" "$pB" "$SOCKPATH" prompt $((now - 60)) /work/b
rec C "$pidC" "$(pstart "$pidC")" "$pC" "$SOCKPATH" working $((now - 10)) /work/c
attach_client main
client="$(T list-clients -F '#{client_name}' | head -1)"
T set -g @pi_hatch_parent "$client"

picker="$(T new-window -d -t main -n picker -P -F '#{pane_id}' "env PI_HATCH_DIR=$REG $ROOT/scripts/picker.sh")"
screen() { T capture-pane -p -t "$picker"; }
has() { screen | grep -q -- "$1"; }

ok "picker shows header" wait_for has "enter: jump"
ok "preview of the first row (prompt, red) is live" wait_for has "MARK-B"
order="$(screen | grep -oE 'prompt|ready|working' | paste -sd' ')"
ok "rows: prompt, ready, working" test "$order" = "prompt ready working"
ok "rows show path and location" bash -c 'screen=$(tmux -L "$0" -f /dev/null capture-pane -p -t "$1"); echo "$screen" | grep -q "/work/b" && echo "$screen" | grep -qE "target:[0-9]+\.[0-9]+"' "$SOCK" "$picker"
T send-keys -t "$picker" Down
ok "preview follows the selection" wait_for has "MARK-A"
T send-keys -t "$picker" Up
wait_for has "MARK-B"
T send-keys -t "$picker" Enter
csession() { T list-clients -F '#{client_name} #{session_name}' | awk -v c="$client" '$1 == c { print $2 }'; }
at_target() { [ "$(csession)" = target ]; }
ok "enter focuses the selected pane's session" wait_for at_target
ok "enter focuses the selected pane" test "$(T display-message -p -t target '#{pane_id}')" = "$pB"
ok "no kill/copy bindings" bash -c '! grep -E "ctrl-x|ctrl-y|kill|copy" "$0/scripts/picker.sh"' "$ROOT"

rm -rf "$REG"
finish picker
