#!/usr/bin/env bash
# Run every test suite. Exit non-zero if any fails.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
rc=0
for t in *.test.sh; do bash "$t" || rc=1; done
for t in *.test.mjs; do
  if out="$(node --experimental-strip-types --no-warnings --test "$t" 2>&1)"; then
    echo "${t%.test.mjs}: PASS"
  else
    printf '%s\n' "$out" | grep -E '^not ok|^# (pass|fail)'
    echo "${t%.test.mjs}: FAIL"
    rc=1
  fi
done
exit "$rc"
