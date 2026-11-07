#!/usr/bin/env bash
# fzf picker over the live Pi instances; enter jumps to the chosen one.
#
#   picker.sh                  the picker (run inside a popup)
#   picker.sh --preview <pane> capture <pane> without trailing blank lines, which
#                              would leave fzf's `follow` scrolled onto padding
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

if [ "${1:-}" = '--preview' ]; then
  # A line holding only escape codes (from -e) is still blank.
  tmux capture-pane -ept "${2:-}" 2>/dev/null |
    awk -v esc="$(printf '\033')" '
      { line = $0; gsub(esc "\\[[0-9;]*m", "", line) }
      line ~ /^[[:space:]]*$/ { held = held $0 "\n"; next }
      { printf "%s", held; held = ""; print }
    '
  exit 0
fi

for tool in fzf jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    tmux display-message "tmux-pi-hatch: $tool is required for the picker"
    exit 0
  }
done

self="$DIR/picker.sh"
export FZF_DEFAULT_OPTS=''

# Arbitrary user fzf options (e.g. custom --bind or --preview-window)
extra_opts=()
fzf_options="$(get_tmux_option @pi_hatch_fzf_options '')"
[ -n "$fzf_options" ] && eval "extra_opts=($fzf_options)"

# Row: pane_id \t pid \t kind \t status \t age \t loc \t path; the first three are hidden.
sel=$("$DIR/agents.sh" | fzf --ansi --delimiter='\t' --with-nth=4,5,6,7 \
  --reverse --cycle --header='Pi agents · enter: jump' \
  --preview="$self --preview {1}" --preview-window='up,70%,follow' \
  --bind='change:first' \
  ${extra_opts[@]+"${extra_opts[@]}"})

[ -z "$sel" ] && exit 0
pane=$(printf '%s' "$sel" | cut -f1)
kind=$(printf '%s' "$sel" | cut -f3)
exec "$DIR/jump.sh" "$pane" "$kind"
