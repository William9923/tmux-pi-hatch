#!/usr/bin/env bash
# Print one picker row per live Pi tracked by the extension on THIS tmux server.
#
#   Row: pane_id \t pid \t kind \t status \t age \t session:window.pane \t path
#   kind: managed (a `pi-*` session this plugin launched) | manual (any other pane)
#
# Order: red (prompt/stopped), green (ready), yellow (working); newest first in each.
# Registry files of dead Pis are deleted here. Registry dir: $PI_HATCH_DIR.
set -uo pipefail

reg="${PI_HATCH_DIR:-${XDG_RUNTIME_DIR:-/tmp}/tmux-pi-hatch}"
socket="$(tmux display-message -p '#{socket_path}' 2>/dev/null)"
[ -n "$socket" ] || exit 0
panes="$(tmux list-panes -a -F '#{pane_id}'$'\t''#{session_name}'$'\t''#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)"
now="$(date +%s)"

for f in "$reg"/*.json; do
  [ -f "$f" ] || continue
  IFS=$'\t' read -r pid pstart pane sock cwd status ts \
    < <(jq -r '[.pid, .procStart, .paneId, .socket, .cwd, .status, .updatedAt] | @tsv' "$f" 2>/dev/null)
  # An unreadable or incomplete record is not ours to judge; leave it.
  [ -n "${ts:-}" ] || continue

  # Dead process, or the pid was recycled: the start time no longer matches.
  stat="$(cat "/proc/$pid/stat" 2>/dev/null)" || { rm -f "$f"; continue; }
  read -ra fields <<<"${stat##*) }"
  [ "${fields[19]:-}" = "$pstart" ] || { rm -f "$f"; continue; }

  # A live Pi on another tmux server is valid there; just not listed here.
  [ "$sock" = "$socket" ] || continue

  line="$(printf '%s\n' "$panes" | awk -F'\t' -v p="$pane" '$1 == p { print; exit }')"
  [ -n "$line" ] || { rm -f "$f"; continue; }
  IFS=$'\t' read -r _ session loc <<<"$line"

  case "$status" in
  prompt) rank=0 label=$'\033[31m●\033[0m prompt ' ;;
  aborted) rank=0 label=$'\033[31m●\033[0m stopped' ;;
  ready) rank=1 label=$'\033[32m●\033[0m ready  ' ;;
  working) rank=2 label=$'\033[33m●\033[0m working' ;;
  *) rank=3 label=$'\033[90m●\033[0m ?      ' ;;
  esac

  mins=$(((now - ts) / 60))
  if [ "$mins" -lt 60 ]; then age="${mins}m"; elif [ "$mins" -lt 2880 ]; then age="$((mins / 60))h"; else age="$((mins / 1440))d"; fi
  case "$session" in pi-*) kind=managed ;; *) kind=manual ;; esac
  path="${cwd/#$HOME/\~}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%5s\t%s\t%s\n' "$rank" "$ts" "$pane" "$pid" "$kind" "$label" "$age" "$loc" "$path"
done | sort -t$'\t' -k1,1n -k2,2nr | cut -f3-
exit 0
