#!/usr/bin/env bash
# Run every tests/*.test.sh. Exit non-zero if any suite fails.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
rc=0
for t in *.test.sh; do bash "$t" || rc=1; done
exit "$rc"
