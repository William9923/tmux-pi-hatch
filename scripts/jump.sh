#!/usr/bin/env bash
# Jump to a Pi picked in the picker. Runs inside the picker's popup.
#   jump.sh <pane_id> <kind>      kind: managed | manual
#
#   managed  a Pi in a `pi-*` session this plugin launched: bring the outer client to
#            the window it was launched from, then resume it in THIS popup over it.
#   manual   a Pi in any other pane: focus that pane in place. The popup closes on
#            its own when the script exits.
set -uo pipefail

pane="${1:?pane}"
kind="${2:?kind}"

# The popup's own process has no client, so the picker records who opened it.
parent="$(tmux show-options -gqv @pi_hatch_parent 2>/dev/null)"
session="$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null)"
[ -n "$session" ] || exit 0 # the pane vanished while the picker was open

switch() { # switch the outer client to <target>
  if [ -n "$parent" ]; then tmux switch-client -c "$parent" -t "$1" 2>/dev/null; else tmux switch-client -t "$1" 2>/dev/null; fi
}

if [ "$kind" = manual ]; then
  switch "$session"
  tmux select-window -t "$pane" 2>/dev/null
  tmux select-pane -t "$pane" 2>/dev/null
  exit 0
fi

origin="$(tmux show-options -qv -t "$session" @pi_hatch_origin 2>/dev/null)"
[ -n "$origin" ] && switch "$origin"
tmux select-window -t "$pane" 2>/dev/null
tmux select-pane -t "$pane" 2>/dev/null
tmux attach-session -t "$session"
