#!/usr/bin/env bash
# Chunk 1: pi_hatch.tmux binds the launch and list keys, honouring options.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

bound() { T list-keys -T prefix | grep -E "^bind-key +(-r +)?-T prefix +$1 +run-shell .*$2" >/dev/null; }

not_bound() { ! bound "$1" scripts/launch.sh; }

start_server
T run-shell "$ROOT/pi_hatch.tmux"
ok "y -> launch.sh" bound y scripts/launch.sh
ok "u -> list.sh" bound u scripts/list.sh
stop_server

start_server
T set -g @pi_hatch_launch_key Y
T set -g @pi_hatch_list_key U
T run-shell "$ROOT/pi_hatch.tmux"
ok "option Y -> launch.sh" bound Y scripts/launch.sh
ok "option U -> list.sh" bound U scripts/list.sh
ok "default y not bound when overridden" not_bound y

ok "bash -n" bash -c "cd '$ROOT' && bash -n scripts/*.sh pi_hatch.tmux"
finish skeleton
