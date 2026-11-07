#!/usr/bin/env bash
# Chunk 5: registry -> picker rows (liveness, stale cleanup, kind, ordering).
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REG="$(mktemp -d)"
export PI_HATCH_DIR="$REG"
start_server
now=$(date +%s)

agents() { TMUX="$SOCKPATH,0,0" "$ROOT/scripts/agents.sh"; }
col() { agents | cut -f"$1"; }

read -r pA pidA < <(newpane main wa) # manual, prompt (red)
read -r pB pidB < <(newpane pi-aaaa wb) # managed, ready
read -r pC pidC < <(newpane main wc) # manual, working
read -r pD pidD < <(newpane main wd) # manual, ready, newer than B
read -r pE pidE < <(newpane main we) # manual, aborted (red), newer than A
rec A "$pidA" "$(pstart "$pidA")" "$pA" "$SOCKPATH" prompt $((now - 100)) "$HOME/proj"
rec B "$pidB" "$(pstart "$pidB")" "$pB" "$SOCKPATH" ready $((now - 50))
rec C "$pidC" "$(pstart "$pidC")" "$pC" "$SOCKPATH" working $((now - 10))
rec D "$pidD" "$(pstart "$pidD")" "$pD" "$SOCKPATH" ready $((now - 5))
rec E "$pidE" "$(pstart "$pidE")" "$pE" "$SOCKPATH" aborted $((now - 1))
# stale / foreign records
rec dead 99999999 123 "$pA" "$SOCKPATH" ready "$now"
rec recycled "$pidC" 1 "$pC" "$SOCKPATH" ready "$now"
rec nopane "$pidC" "$(pstart "$pidC")" %999 "$SOCKPATH" ready "$now"
rec foreign "$pidC" "$(pstart "$pidC")" "$pC" /tmp/tmux-0/other ready "$now"
echo '{ not json' >"$REG/garbage.json"

out="$(agents)"
ok "rows ordered red(newest first), green(newest first), yellow" test "$(printf '%s\n' "$out" | cut -f1 | paste -sd' ')" = "$pE $pA $pD $pB $pC"
ok "exactly 5 live rows (no stale/foreign)" test "$(printf '%s\n' "$out" | wc -l)" = 5
ok "managed vs manual kind" test "$(printf '%s\n' "$out" | cut -f1,3 | tr '\t' ':' | paste -sd' ')" = "$pE:manual $pA:manual $pD:manual $pB:managed $pC:manual"
ok "labels" bash -c 'printf "%s\n" "$0" | cut -f4 | sed "s/\x1b\[[0-9;]*m//g" | paste -sd, | grep -qx "● stopped,● prompt ,● ready  ,● ready  ,● working"' "$out"
ok "age + loc + ~ path" bash -c 'printf "%s\n" "$0" | grep -P "\tmain:\d+\.\d+\t~/proj$" | grep -qP "\s1m\t"' "$out"
ok "pid column" test "$(printf '%s\n' "$out" | cut -f2 | head -1)" = "$pidE"
ok "dead/recycled/no-pane records deleted" bash -c '[ ! -e "$0/dead.json" ] && [ ! -e "$0/recycled.json" ] && [ ! -e "$0/nopane.json" ]' "$REG"
ok "foreign-server + garbage records kept" bash -c '[ -e "$0/foreign.json" ] && [ -e "$0/garbage.json" ]' "$REG"
ok "valid records kept" bash -c 'for f in A B C D E; do [ -e "$0/$f.json" ] || exit 1; done' "$REG"
ok "second run is identical" test "$(agents)" = "$out"
ok "empty/missing registry prints nothing" test -z "$(PI_HATCH_DIR=/nonexistent agents)"
ok "no tmux server: prints nothing, exits 0" bash -c 'TMUX=/nonexistent,0,0 "$0/scripts/agents.sh" | wc -l | grep -qx 0' "$ROOT"

rm -rf "$REG"
ok "bash -n" bash -n "$ROOT/scripts/agents.sh"
finish agents
