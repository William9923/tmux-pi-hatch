#!/usr/bin/env bash
# Launch, re-attach to, or (from inside the popup) close the Pi popup for a folder.
# Args: <dir> <origin-window-id> <current-session>   (all expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"
# From the binding, not `display-message`: a script has no client of its own, so tmux
# would guess the most recently used one, which is wrong with a popup open.
current="${3:-}"
case "$current" in
pi-*)
  # Toggle: the key was pressed inside a hatch popup. Detach it; Pi keeps running.
  tmux detach-client -s "$current"
  exit 0
  ;;
esac

cmd="$(get_tmux_option @pi_hatch_command 'pi')"
w="$(get_tmux_option @pi_hatch_popup_width '90%')"
h="$(get_tmux_option @pi_hatch_popup_height '90%')"
session="pi-$(session_hash "$path")"

if ! tmux has-session -t "$session" 2>/dev/null; then
  [ -d "$path" ] || {
    tmux display-message "tmux-pi-hatch: $path no longer exists"
    exit 0
  }
  tmux new-session -d -s "$session" -c "$path" "$cmd"
fi

# Close the popup when Pi exits, even under a global detach-on-destroy off.
tmux set-option -t "$session" detach-on-destroy on

# Remember the launching window, so the picker and bell forwarding can find it.
[ -n "$window" ] && tmux set-option -t "$session" @pi_hatch_origin "$window"

tmux display-popup -w "$w" -h "$h" -b rounded -T " Pi " -E "tmux attach-session -t '$session'"
