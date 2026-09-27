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
  : > "$T/answers"
}
# KEEP=1 leaves each sandbox in place (and prints where) for a closer look.
cleanup() { [[ -n "${KEEP:-}" ]] && echo "kept $T" || rm -rf "$T"; }

# wizard CODE: one "run" of the wizard. Sources the library into a subshell
# (so state never leaks between runs) and evaluates CODE. Output goes to $T/out.
# Questions read from stdin (such as revert's drift prompts) are answered from
# $T/answers, one line each; an empty file means Enter, the default, for all.
wizard() {
  (
    export HOME="$H" GHW_TTY="$T/tty" GIT_CONFIG_NOSYSTEM=1
    unset XDG_CONFIG_HOME
    # shellcheck source=/dev/null
    source "$WIZARD"
    set +e
    eval "$1"
  ) < "$T/answers" > "$T/out" 2>&1
}
# cli ARGS...: run the real script as a user would. Enter for every pause, or
# the answers in the file CLI_INPUT names. It runs as if inside Ghostty and
# outside herdr, so the ghostty stage never opens Ghostty or fills the clipboard.
cli() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do printf '\n'; done > "$T/enter"
  HOME="$H" GHW_TTY="$T/tty" TERM_PROGRAM=ghostty HERDR_ENV='' \
    bash "$WIZARD" "$@" < "${CLI_INPUT:-$T/enter}" > "$T/out" 2>&1
}
# fake_brew: put a brew on PATH that only logs its arguments to $T/brew.log.
fake_brew() {
  mkdir -p "$T/bin"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/brew.log"\n' "$T" > "$T/bin/brew"
  chmod +x "$T/bin/brew"
  PATH="$T/bin:$PATH"
}
# fake_bat: put a bat on PATH whose Catppuccin themes are already there, so no
# stage downloads them. Call after fake_brew.
fake_bat() {
  mkdir -p "$T/bin" "$T/bat/themes"
  touch "$T/bat/themes/Catppuccin Mocha.tmTheme" "$T/bat/themes/Catppuccin Latte.tmTheme"
  printf '#!/bin/sh\n[ "$1" = --config-dir ] && echo "%s/bat"\nexit 0\n' "$T" > "$T/bin/bat"
  chmod +x "$T/bin/bat"
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
journal_lines() { grep -c . "$STATE/journal.tsv" 2>/dev/null || true; }

# run_tests [NAME...]: run every test_* function, or just the named ones, print
# the tally, fail if any failed.
run_tests() {
  local t
  for t in ${@:-$(declare -F | awk '{print $3}' | grep '^test_')}; do
    printf '%s\n' "$t"
    "$t"
  done
  printf '\n%d passed, %d failed\n' "$PASSES" "$FAILS"
  (( FAILS == 0 ))
}
