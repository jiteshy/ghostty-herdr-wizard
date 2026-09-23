#!/usr/bin/env bash
# Tests for the journal, the first-ever-wins backup store and --revert.
#
#   bash tests/journal_test.sh
#
# Each test gets a throwaway HOME under mktemp, so nothing outside it is touched,
# and no network, brew or sudo is needed. Works under macOS's bash 3.2.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
# cli ARGS...: run the real script as a user would. Enter for every pause.
cli() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do printf '\n'; done > "$T/enter"
  HOME="$H" GHW_TTY="$T/tty" bash "$WIZARD" "$@" < "$T/enter" > "$T/out" 2>&1
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
journal_lines() { grep -c . "$STATE/journal.tsv" 2>/dev/null || true; }

# ── tests ─────────────────────────────────────────────────────────────────

test_first_run_creates_state_dir() {
  new_home
  wizard 'journal_init'
  check "[[ -f '$STATE/journal.tsv' ]]" "journal.tsv exists"
  check "[[ -d '$STATE/backups' ]]" "backups/ exists"
  cleanup
}

test_replacing_a_file_journals_modify_with_backup_and_sha() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'theme = mine\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/original"
  wizard 'journal_init; JOURNALING=1; printf "theme = wizard\n" | install_file "$HOME/.config/ghostty/config"'
  local line; line=$(tail -1 "$STATE/journal.tsv")
  local type path ref hash
  IFS=$'\t' read -r _ type path ref hash <<<"$line"
  check "[[ '$type' == MODIFY ]]" "entry type is MODIFY (got '$type')"
  check "[[ '$path' == '$H/.config/ghostty/config' ]]" "entry records the path"
  check "[[ '$hash' == '$(sha "$H/.config/ghostty/config")' ]]" "entry records sha of what was written"
  same_bytes "$STATE/backups/$ref" "$T/original" "backup ref points at the user's original"
  cleanup
}

test_writing_a_new_file_journals_create_without_backup() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.config/ghostty/config"'
  local type; type=$(tail -1 "$STATE/journal.tsv" | cut -f2)
  check "[[ '$type' == CREATE ]]" "new file is journaled as CREATE (got '$type')"
  check "[[ -z \"\$(ls -A '$STATE/backups')\" ]]" "nothing backed up"
  cleanup
}

test_unchanged_file_is_not_journaled() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'same\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "same\n" | install_file "$HOME/.config/ghostty/config"'
  check "[[ '$(journal_lines)' == 0 ]]" "no entry when nothing was written"
  cleanup
}

test_second_run_keeps_the_users_original_in_backup() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'theme = mine\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/original"
  wizard 'journal_init; JOURNALING=1; printf "run one\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'journal_init; JOURNALING=1; printf "run two\n" | install_file "$HOME/.config/ghostty/config"'
  local ref; ref=$(tail -1 "$STATE/journal.tsv" | cut -f4)
  same_bytes "$STATE/backups/$ref" "$T/original" "backup still holds the user's original after run 2"
  check "[[ '$(tail -1 "$STATE/journal.tsv" | cut -f5)' == '$(sha "$H/.config/ghostty/config")' ]]" \
    "latest entry carries run two's sha"
  cleanup
}

test_edits_made_between_runs_are_kept_when_replaced() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'theme = mine\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/original"
  wizard 'journal_init; JOURNALING=1; printf "run one\n" | install_file "$HOME/.config/ghostty/config"'
  printf 'run one\nfont-size = 18\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/edited"
  wizard 'journal_init; JOURNALING=1; printf "run two\n" | install_file "$HOME/.config/ghostty/config"'
  same_bytes "$STATE/backups/.config/ghostty/config" "$T/original" "store still holds the first-ever original"
  local kept; kept=$(find "$STATE/replaced" -type f -path '*/.config/ghostty/config' 2>/dev/null | head -1)
  same_bytes "$kept" "$T/edited" "the user's between-runs edits are kept under replaced/"
  cleanup
}

test_unedited_wizard_output_is_not_kept_again() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'theme = mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "run one\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'journal_init; JOURNALING=1; printf "run two\n" | install_file "$HOME/.config/ghostty/config"'
  check "[[ ! -e '$STATE/replaced' ]]" "wizard's own unedited output is not kept as a replaced version"
  cleanup
}

test_file_the_wizard_created_is_never_backed_up_as_an_original() {
  new_home
  wizard 'journal_init; JOURNALING=1
    printf "first\n"  | install_file "$HOME/.config/ghostty/config"
    printf "second\n" | install_file "$HOME/.config/ghostty/config"'
  check "[[ -z \"\$(ls -A '$STATE/backups')\" ]]" "wizard output not captured as a backup"
  check "[[ '$(tail -1 "$STATE/journal.tsv" | cut -f2)' == CREATE ]]" "still recorded as a creation"
  cleanup
}

test_unmigrated_stages_write_no_journal_but_still_back_up_once() {
  new_home
  printf 'mine\n' > "$H/.zshrc"
  cp "$H/.zshrc" "$T/original"
  wizard 'journal_init; printf "one\n" | install_file "$HOME/.zshrc"'
  wizard 'journal_init; printf "two\n" | install_file "$HOME/.zshrc"'
  check "[[ '$(journal_lines)' == 0 ]]" "no journal entries outside migrated stages"
  same_bytes "$STATE/backups/.zshrc" "$T/original" "backup is first-ever-wins"
  cleanup
}

test_revert_restores_modified_files_and_archives_journal() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'theme = mine\nfont-size = 13\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/original"
  wizard 'journal_init; JOURNALING=1; printf "run one\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'journal_init; JOURNALING=1; printf "run two\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'revert_all'
  same_bytes "$H/.config/ghostty/config" "$T/original" "config restored byte-identical"
  check "grep -q 'restored $H/.config/ghostty/config' '$T/out'" "revert reports the restored path"
  check "[[ ! -e '$STATE/journal.tsv' ]]" "journal archived away"
  check "[[ -n \"\$(ls '$STATE'/archive/*/journal.tsv 2>/dev/null)\" ]]" "archived journal kept"
  wizard 'journal_init'
  check "[[ '$(journal_lines)' == 0 ]]" "next run starts a fresh journal"
  cleanup
}

test_revert_keeps_backups_of_files_it_did_not_revert() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  printf 'my zshrc\n' > "$H/.zshrc"
  cp "$H/.zshrc" "$T/original"
  wizard 'journal_init; printf "wizard zshrc\n" | install_file "$HOME/.zshrc"
    JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'revert_all'
  same_bytes "$STATE/backups/.zshrc" "$T/original" "unjournaled original stays in the store"
  check "[[ ! -e '$STATE/backups/.config/ghostty/config' ]]" "reverted path's backup archived"
  wizard 'journal_init; printf "wizard zshrc v2\n" | install_file "$HOME/.zshrc"'
  same_bytes "$STATE/backups/.zshrc" "$T/original" "next run still doesn't capture the wizard's output"
  cleanup
}

test_failed_restore_keeps_journal_and_leaves_file_alone() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  rm -f "$STATE/backups/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/wizard-version"
  cli --revert
  same_bytes "$H/.config/ghostty/config" "$T/wizard-version" "file left as it was"
  check "[[ -s '$STATE/journal.tsv' ]]" "journal kept for a retry"
  check "grep -q 'still to do by hand' '$T/out'" "--revert lists what's left to do"
  cleanup
}

test_revert_keeps_the_wizards_version_instead_of_deleting_it() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'revert_all'
  check "grep -rqx wizard '$STATE/reverted'" "replaced content moved under reverted/, not deleted"
  cleanup
}

test_revert_leaves_created_files_and_says_so() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.local/bin/ghostty-launch"'
  wizard 'revert_all'
  check "[[ -f '$H/.local/bin/ghostty-launch' ]]" "created file left in place for now"
  check "grep -q 'ghostty-launch' '$T/out'" "revert mentions the created file"
  cleanup
}

test_revert_on_a_fresh_machine_is_a_clean_no_op() {
  new_home
  cli --revert
  local status=$?
  check "[[ $status == 0 ]]" "exits 0 (got $status)"
  check "grep -qi 'nothing to revert' '$T/out'" "says there is nothing to revert"
  check "[[ ! -e '$STATE' ]]" "does not create the state dir"
  cleanup
}

test_journal_is_only_ever_appended() {
  # Every redirect into the journal must be >>, never > or a rewrite via mv/sed.
  local bad
  bad=$(grep -nE '[^>]>[[:space:]]*"?\$JOURNAL' "$WIZARD" || true)
  check "[[ -z '$bad' ]]" "no truncating write to \$JOURNAL: $bad"
  bad=$(grep -nE '(sed -i|mv [^|]*"\$JOURNAL"[[:space:]]*$)' "$WIZARD" || true)
  check "[[ -z '$bad' ]]" "no in-place rewrite of \$JOURNAL: $bad"
}

# End to end through the real CLI: the Ghostty config stage (3) against an
# existing config, twice, then --revert.
test_ghostty_stage_end_to_end() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf '# my own ghostty config\ntheme = Dracula\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/original"
  cli --only 3
  check "grep -q \"MODIFY	$H/.config/ghostty/config\" '$STATE/journal.tsv'" "stage 3 journals the Ghostty config"
  check "! cmp -s '$H/.config/ghostty/config' '$T/original'" "stage 3 replaced the config"
  cli --only 3
  cli --revert
  same_bytes "$H/.config/ghostty/config" "$T/original" "--revert restores the user's config byte-identical"
  cleanup
}

# ── runner ────────────────────────────────────────────────────────────────

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  printf '%s\n' "$t"
  "$t"
done
printf '\n%d passed, %d failed\n' "$PASSES" "$FAILS"
(( FAILS == 0 ))
