#!/usr/bin/env bash
# Forward a bell from a hatch (`pi-*`) session to its origin window's pane, so tmux's
# bell machinery highlights the window you launched from even though the ringing
# session is a separate one.
#
#   bell.sh <session-name>   bound to the alert-bell hook via #{hook_session_name}
set -uo pipefail

session="${1:-}"
case "$session" in
pi-*) ;;
*) exit 0 ;;
esac

origin="$(tmux show-options -qv -t "$session" @pi_hatch_origin 2>/dev/null)"
[ -n "$origin" ] || exit 0

# Skip if the origin is itself a hatch session, to avoid a forwarding loop.
case "$(tmux display-message -p -t "$origin" '#{session_name}' 2>/dev/null)" in
pi-*) exit 0 ;;
esac

tty="$(tmux display-message -p -t "$origin" '#{pane_tty}' 2>/dev/null)"
[ -n "$tty" ] && printf '\a' >"$tty" 2>/dev/null
exit 0
