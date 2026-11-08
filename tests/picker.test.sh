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
rows() { screen | grep '●' | grep -oE 'prompt|ready|working' | paste -sd' '; }
order="$(rows)"
ok "rows: prompt, ready, working" test "$order" = "prompt ready working"
ok "rows show path and location" bash -c 'screen=$(tmux -L "$0" -f /dev/null capture-pane -p -t "$1"); echo "$screen" | grep -q "/work/b" && echo "$screen" | grep -qE "target:[0-9]+\.[0-9]+"' "$SOCK" "$picker"
# layout: wide pane -> preview right of the list (fzf-lua style); narrow -> below the rows
ok "wide: preview is on the right" test "$(screen | awk '{ i = index($0, "MARK-B"); if (i > m) m = i } END { print m + 0 }')" -gt 60
T new-session -d -s narrow -x 80 -y 30 "env PI_HATCH_DIR=$REG $ROOT/scripts/picker.sh"
narrow() { T capture-pane -p -t narrow; }
narrow_has() { narrow | grep -q MARK-B; }
wait_for narrow_has
line_of() { narrow | grep -n -- "$1" | head -1 | cut -d: -f1; }
ok "narrow: preview flips below the rows" test "$(line_of MARK-B)" -gt "$(line_of working)"
T kill-session -t narrow

is_working() { test "$(rows)" = working; }
is_ready() { test "$(rows)" = ready; }
is_all() { test "$(rows)" = "prompt ready working"; }
T send-keys -t "$picker" Tab
ok "Tab filters working agents" wait_for is_working
T send-keys -t "$picker" Tab
ok "Tab cycles to ready agents" wait_for is_ready
T send-keys -t "$picker" Tab
ok "Tab cycles back to all agents" wait_for is_all

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
