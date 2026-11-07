#!/usr/bin/env bash
# tmux-pi-hatch: a Pi agent hatch for tmux. tpm runs this file on tmux startup;
# it reads user options (with defaults) and installs the key bindings.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/scripts/helpers.sh"

launch_key="$(get_tmux_option @pi_hatch_launch_key 'y')"
list_key="$(get_tmux_option @pi_hatch_list_key 'u')"

# Launch / re-attach / toggle the popup for the current pane's directory.
# #{pane_current_path} / #{window_id} are expanded by run-shell before the args
# reach the script.
tmux bind-key "$launch_key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{q:pane_current_path}' '#{q:window_id}'"

# Open the picker.
tmux bind-key "$list_key" \
  run-shell "$CURRENT_DIR/scripts/list.sh '#{q:client_name}'"
