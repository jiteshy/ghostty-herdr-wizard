# Shared harness for the wizard's tests. Sourced by each tests/*_test.sh.
#
# Each test gets a throwaway HOME under mktemp, so nothing outside it is touched,
# and no network, brew or sudo is needed. Works under macOS's bash 3.2.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIZARD="$ROOT/ghostty-herdr-wizard.sh"
FAILS=0
PASSES=0

fail() { printf '  FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }
pass() { PASSES=$((PASSES + 1)); }
check() { # CONDITION NAME
  if eval "$1"; then pass; else fail "$2"; fi
}
# same_bytes ACTUAL EXPECTED NAME: byte-for-byte, printing the diff on failure.
same_bytes() {
  if [[ -f "$1" ]] && cmp -s "$1" "$2"; then pass; else
    fail "$3"
    diff -u "$2" "$1" 2>&1 | sed 's/^/      /'
  fi
}

# new_home: fresh sandbox. $T/home is HOME; $T/tty answers "y" to every
# replace-this-file prompt.
new_home() {
  T=$(mktemp -d)
  H="$T/home"
  STATE="$H/.ghostty-herdr-wizard"
  mkdir -p "$H"
  printf 'y\ny\ny\ny\ny\ny\n' > "$T/tty"
}
cleanup() { rm -rf "$T"; }

# wizard CODE: one "run" of the wizard. Sources the library into a subshell
# (so state never leaks between runs) and evaluates CODE. Output goes to $T/out.
wizard() {
  (
    export HOME="$H" GHW_TTY="$T/tty"
    # shellcheck source=/dev/null
    source "$WIZARD"
    set +e
    eval "$1"
  ) > "$T/out" 2>&1
}
# cli ARGS...: run the real script as a user would. Enter for every pause, or
# the answers in the file CLI_INPUT names.
cli() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do printf '\n'; done > "$T/enter"
  HOME="$H" GHW_TTY="$T/tty" bash "$WIZARD" "$@" < "${CLI_INPUT:-$T/enter}" > "$T/out" 2>&1
}
# fake_brew: put a brew on PATH that only logs its arguments to $T/brew.log.
fake_brew() {
  mkdir -p "$T/bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/brew.log"\n' "$T" > "$T/bin/brew"
  chmod +x "$T/bin/brew"
  PATH="$T/bin:$PATH"
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
journal_lines() { grep -c . "$STATE/journal.tsv" 2>/dev/null || true; }

# run_tests: run every test_* function, print the tally, fail if any failed.
run_tests() {
  local t
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    printf '%s\n' "$t"
    "$t"
  done
  printf '\n%d passed, %d failed\n' "$PASSES" "$FAILS"
  (( FAILS == 0 ))
}
