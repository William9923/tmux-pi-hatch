#!/usr/bin/env bash
# Open the picker in a popup. Arg: <client_name> of the client that pressed the key.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

w="$(get_tmux_option @pi_hatch_popup_width '90%')"
h="$(get_tmux_option @pi_hatch_popup_height '90%')"

# The session the pressing client is attached to, by exact client_name match (a
# global scan could grab an unrelated client when several are attached).
me="${1:-}"
my_session="$(tmux list-clients -F '#{client_name} #{session_name}' 2>/dev/null |
  awk -v me="$me" '$1 == me { print $2; exit }')"

# open_picker <host>: the picker popup on <host>, or on the default client if empty.
open_picker() {
  if [ -n "$1" ]; then
    tmux display-popup -b rounded -T " Pi agents " -c "$1" -w "$w" -h "$h" -E "$DIR/picker.sh"
  else
    tmux display-popup -b rounded -T " Pi agents " -w "$w" -h "$h" -E "$DIR/picker.sh"
  fi
}

case "$my_session" in
pi-*)
  # Pressed inside a Pi popup: close it, then reopen the picker on the outer client.
  # display-popup returns before tmux finishes destroying the closing overlay, and a
  # popup opened in that window never receives input. So wait for the popup client
  # to leave, settle, and retry a reopen that is rejected mid-teardown (it returns
  # almost instantly, whereas a popup that opened blocks while in use).
  tmux detach-client -s "$my_session"
  for _ in $(seq 1 100); do
    tmux list-clients -F '#{session_name}' 2>/dev/null | grep -qx "$my_session" || break
    sleep 0.05
  done
  host="$(tmux show-options -gqv @pi_hatch_parent 2>/dev/null)"
  # A stale parent would make every retry fail; fall back to the default client.
  if [ -n "$host" ] && ! tmux list-clients -F '#{client_name}' 2>/dev/null | grep -qx "$host"; then
    host=''
  fi
  sleep 0.1
  rc=0
  for _ in $(seq 1 40); do
    before=$SECONDS
    open_picker "$host"
    rc=$?
    { [ "$rc" -eq 0 ] || [ $((SECONDS - before)) -ge 1 ]; } && break
    sleep 0.1
  done
  exit "$rc"
  ;;
*)
  tmux set-option -g @pi_hatch_parent "$me"
  open_picker "$me"
  ;;
esac
