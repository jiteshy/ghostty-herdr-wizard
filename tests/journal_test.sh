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
  : > "$T/answers"
}
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

test_writes_outside_a_run_are_not_journaled_but_still_back_up_once() {
  new_home
  printf 'mine\n' > "$H/.zshrc"
  cp "$H/.zshrc" "$T/original"
  wizard 'journal_init; printf "one\n" | install_file "$HOME/.zshrc"'
  wizard 'journal_init; printf "two\n" | install_file "$HOME/.zshrc"'
  check "[[ '$(journal_lines)' == 0 ]]" "no journal entries while journaling is off (library only sourced)"
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

test_revert_relocates_created_files() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.local/bin/ghostty-launch"'
  wizard 'revert_all'
  check "[[ ! -e '$H/.local/bin/ghostty-launch' ]]" "created file gone from where it was"
  local moved; moved=$(find "$STATE/reverted" -type f -path '*/.local/bin/ghostty-launch' 2>/dev/null | head -1)
  check "[[ -n '$moved' && \"\$(cat '$moved')\" == x ]]" "created file moved under reverted/, keeping its relative path"
  check "grep -q 'moved $H/.local/bin/ghostty-launch' '$T/out'" "revert reports the move"
  cleanup
}

test_untouched_file_is_restored_without_a_prompt() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  wizard 'revert_all'
  check "! grep -q '\[y/N\]' '$T/out'" "no question asked"
  check "[[ \"\$(cat '$H/.config/ghostty/config')\" == mine ]]" "original restored"
  cleanup
}

test_drifted_file_is_kept_by_default_and_reported() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  printf 'wizard\nfont-size = 18\n' > "$H/.config/ghostty/config"
  cp "$H/.config/ghostty/config" "$T/edited"
  wizard 'revert_all'
  check "grep -q '+font-size = 18' '$T/out' || grep -q -- '-font-size = 18' '$T/out'" "shows the diff"
  check "grep -q '\[y/N\]' '$T/out'" "asks, defaulting to no"
  same_bytes "$H/.config/ghostty/config" "$T/edited" "user's edited version kept"
  check "sed -n '/kept your version/,\$p' '$T/out' | grep -q '$H/.config/ghostty/config'" \
    "closing summary lists it as kept"
  cleanup
}

test_drifted_file_is_reverted_when_the_user_says_yes() {
  new_home
  mkdir -p "$H/.config/ghostty"
  printf 'mine\n' > "$H/.config/ghostty/config"
  wizard 'journal_init; JOURNALING=1; printf "wizard\n" | install_file "$HOME/.config/ghostty/config"'
  printf 'wizard\nedited\n' > "$H/.config/ghostty/config"
  printf 'y\n' > "$T/answers"
  wizard 'revert_all'
  check "[[ \"\$(cat '$H/.config/ghostty/config')\" == mine ]]" "original restored"
  check "grep -rqx edited '$STATE/reverted'" "the edited version is kept under reverted/"
  cleanup
}

test_drifted_created_file_is_kept_by_default() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.config/starship.toml"'
  printf 'x\nmine\n' > "$H/.config/starship.toml"
  wizard 'revert_all'
  check "[[ -f '$H/.config/starship.toml' ]]" "edited created file stays in place"
  check "grep -q 'kept your version' '$T/out'" "reported as kept"
  cleanup
}

test_upsert_block_journals_a_block_entry() {
  new_home
  printf 'alias x=y\n' > "$H/.zshrc"
  wizard 'journal_init; JOURNALING=1; printf "export A=1\n" | upsert_block "$HOME/.zshrc"'
  local type path marker; IFS=$'\t' read -r _ type path marker _ <<<"$(tail -1 "$STATE/journal.tsv")"
  check "[[ '$type' == BLOCK ]]" "entry type is BLOCK (got '$type')"
  check "[[ '$path' == '$H/.zshrc' ]]" "entry records the path"
  check "[[ '$marker' == '#' ]]" "entry records the marker's comment leader (got '$marker')"
  check "[[ '$(journal_lines)' == 1 ]]" "the file write itself isn't journaled a second time"
  cleanup
}

test_revert_strips_only_the_block_even_after_edits() {
  new_home
  printf 'alias x=y\n# my comment\n' > "$H/.zshrc"
  wizard 'journal_init; JOURNALING=1; printf "export A=1\n" | upsert_block "$HOME/.zshrc"'
  wizard 'journal_init; JOURNALING=1; printf "export A=2\n" | upsert_block "$HOME/.zshrc"'
  printf 'alias later=1\n' >> "$H/.zshrc"
  printf 'alias x=y\n# my comment\nalias later=1\n' > "$T/expected"
  wizard 'revert_all'
  same_bytes "$H/.zshrc" "$T/expected" "only the marked block is removed"
  check "! grep -q '\[y/N\]' '$T/out'" "no drift question for a block"
  cleanup
}

test_revert_strips_a_lua_block() {
  new_home
  mkdir -p "$H/.config/nvim/lua/config"
  printf -- '-- mine\n' > "$H/.config/nvim/lua/config/autocmds.lua"
  cp "$H/.config/nvim/lua/config/autocmds.lua" "$T/original"
  wizard 'journal_init; JOURNALING=1; printf "vim.o.autoread = true\n" | upsert_block "$HOME/.config/nvim/lua/config/autocmds.lua" "--"'
  wizard 'revert_all'
  same_bytes "$H/.config/nvim/lua/config/autocmds.lua" "$T/original" "lua block stripped"
  cleanup
}

test_revert_moves_a_file_the_wizard_created_for_its_block() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "export A=1\n" | upsert_block "$HOME/.zprofile"'
  wizard 'revert_all'
  check "[[ ! -e '$H/.zprofile' ]]" "file created only for the block is moved away"
  cleanup
}

test_revert_keeps_a_created_block_file_the_user_added_to() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "export A=1\n" | upsert_block "$HOME/.zprofile"'
  printf 'export MINE=1\n' >> "$H/.zprofile"
  wizard 'revert_all'
  check "[[ \"\$(cat '$H/.zprofile')\" == 'export MINE=1' ]]" "user's lines stay, block gone"
  cleanup
}

# seed_settings: a Claude Code settings file with the user's own keys.
seed_settings() {
  mkdir -p "$H/.claude"
  cat > "$H/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": { "PreToolUse": [{ "matcher": "Bash", "hooks": [] }] }
}
EOF
}
# jkey PATH: a key of the sandbox settings file, compact.
jkey() { jq -c "$1" "$H/.claude/settings.json"; }

test_json_set_journals_the_key_with_its_prior_value() {
  new_home
  seed_settings
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".statusLine = {type: \"command\"}"'
  check "[[ '$(jkey .statusLine)' == '{\"type\":\"command\"}' ]]" "key written"
  local type key prior; IFS=$'\t' read -r _ type _ key prior _ <<<"$(tail -1 "$STATE/journal.tsv")"
  check "[[ '$type' == JSONKEY ]]" "entry type is JSONKEY (got '$type')"
  check "[[ '$key' == '[\"statusLine\"]' ]]" "entry records the key (got '$key')"
  check "[[ '$prior' == '<absent>' ]]" "entry records it was absent (got '$prior')"
  check "! grep -qE 'MODIFY|CREATE' '$STATE/journal.tsv'" "no whole-file entry for settings.json"
  cleanup
}

test_revert_removes_only_the_wizards_keys() {
  new_home
  seed_settings
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".statusLine = {type: \"command\"}"'
  # Claude Code keeps writing to the file as the user accepts permissions.
  jq '.permissions.allow += ["Read"]' "$H/.claude/settings.json" > "$T/s" && mv "$T/s" "$H/.claude/settings.json"
  wizard 'revert_all'
  check "[[ '$(jkey .statusLine)' == null ]]" "statusLine removed"
  check "[[ '$(jkey .permissions)' == '{\"allow\":[\"Bash(ls:*)\",\"Read\"]}' ]]" "permissions, incl. one added later, untouched"
  check "[[ '$(jkey .model)' == '\"opus\"' ]]" "model untouched"
  check "! grep -q '\[y/N\]' '$T/out'" "no drift question for unrelated keys changing"
  cleanup
}

test_revert_restores_a_keys_first_ever_value() {
  new_home
  seed_settings
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".model = \"wizard-1\""'
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".model = \"wizard-2\""'
  wizard 'revert_all'
  check "[[ '$(jkey .model)' == '\"opus\"' ]]" "model back to the user's value, not run one's"
  cleanup
}

test_json_track_journals_an_external_tools_nested_change() {
  new_home
  seed_settings
  wizard 'journal_init; JOURNALING=1
    add_hook() { jq ".hooks.Stop = [{\"hooks\": []}]" "$1" > "$1.new" && mv "$1.new" "$1"; }
    json_track "$HOME/.claude/settings.json" add_hook "$HOME/.claude/settings.json"'
  check "grep -q 'JSONKEY.*\[\"hooks\",\"Stop\"\]' '$STATE/journal.tsv'" "nested key journaled"
  wizard 'revert_all'
  check "[[ '$(jkey .hooks.Stop)' == null ]]" "tool's hook removed"
  check "[[ '$(jkey '.hooks.PreToolUse | length')' == 1 ]]" "user's own hook kept"
  cleanup
}

test_drifted_json_key_is_kept_by_default() {
  new_home
  seed_settings
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".statusLine = {type: \"command\"}"'
  jq '.statusLine.padding = 2' "$H/.claude/settings.json" > "$T/s" && mv "$T/s" "$H/.claude/settings.json"
  wizard 'revert_all'
  check "[[ '$(jkey .statusLine.padding)' == 2 ]]" "user's edit to the key kept"
  check "grep -q '\[y/N\]' '$T/out'" "asked"
  check "grep -q 'kept your version' '$T/out'" "reported as kept"
  cleanup
}

test_settings_safety_net_backup_is_taken_once() {
  new_home
  seed_settings
  cp "$H/.claude/settings.json" "$T/original"
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".a = 1"'
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".a = 2"'
  same_bytes "$STATE/backups/.claude/settings.json" "$T/original" "whole-file safety net holds the original"
  check "[[ ! -e '$STATE/replaced' ]]" "no extra copy per run for a key-level file"
  cleanup
}

test_settings_file_the_wizard_created_is_moved_away() {
  new_home
  wizard 'journal_init; JOURNALING=1; json_set "$HOME/.claude/settings.json" ".statusLine = {type: \"command\"}"'
  wizard 'revert_all'
  check "[[ ! -e '$H/.claude/settings.json' ]]" "settings.json the wizard created is gone"
  cleanup
}

gitkey() { HOME="$H" GIT_CONFIG_NOSYSTEM=1 git config --global --get "$1"; }

test_git_set_is_reverted_key_by_key() {
  new_home
  printf '[user]\n\tname = Me\n[core]\n\tpager = less\n' > "$H/.gitconfig"
  wizard 'journal_init; JOURNALING=1; git_set core.pager delta; git_set alias.dft "difft diff"'
  wizard 'journal_init; JOURNALING=1; git_set core.pager delta2'
  check "grep -q 'GITKEY' '$STATE/journal.tsv'" "journaled as GITKEY"
  HOME="$H" git config --global user.email me@example.com
  wizard 'revert_all'
  check "[[ '$(gitkey core.pager)' == less ]]" "core.pager back to the user's first-ever value"
  check "[[ -z '$(gitkey alias.dft)' ]]" "alias the wizard added is unset"
  check "[[ '$(gitkey user.name)' == Me ]]" "user.name untouched"
  check "[[ '$(gitkey user.email)' == me@example.com ]]" "key added after the wizard untouched"
  cleanup
}

test_drifted_git_key_is_kept_by_default() {
  new_home
  wizard 'journal_init; JOURNALING=1; git_set core.pager delta'
  HOME="$H" git config --global core.pager bat
  wizard 'revert_all'
  check "[[ '$(gitkey core.pager)' == bat ]]" "user's value kept"
  check "grep -q 'kept your version' '$T/out'" "reported as kept"
  cleanup
}

# A stand-in for cloning the LazyVim starter, then the stage's own writes.
NVIM_RUN='journal_init; JOURNALING=1
  starter() { mkdir -p "$1/lua/config" && printf "starter\n" > "$1/init.lua"; }
  replace_dir "$HOME/.config/nvim" starter "$HOME/.config/nvim"
  printf "return {}\n" | install_file "$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  printf "vim.o.autoread = true\n" | upsert_block "$HOME/.config/nvim/lua/config/autocmds.lua" "--"'

test_revert_moves_a_created_config_dir_with_the_users_additions() {
  new_home
  wizard "$NVIM_RUN"
  check "grep -q \"CREATE	$H/.config/nvim	\" '$STATE/journal.tsv'" "directory journaled as CREATE"
  # Months later: lazy sync and the user's own plugin config.
  printf '{}\n' > "$H/.config/nvim/lazy-lock.json"
  printf 'return { "mine" }\n' > "$H/.config/nvim/lua/plugins/mine.lua"
  wizard 'revert_all'
  check "[[ ! -e '$H/.config/nvim' ]]" "removed from where Neovim looks"
  local moved; moved=$(find "$STATE/reverted" -type d -path '*/.config/nvim' | head -1)
  check "[[ -f '$moved/lua/plugins/mine.lua' && -f '$moved/lazy-lock.json' ]]" "user's files kept under reverted/"
  check "[[ -f '$moved/lua/config/autocmds.lua' && -f '$moved/init.lua' ]]" "moved as one tree, block and all"
  check "! grep -q '\[y/N\]' '$T/out'" "no question: nothing is lost by moving it"
  cleanup
}

test_revert_brings_back_a_config_dir_the_wizard_moved_aside() {
  new_home
  mkdir -p "$H/.config/nvim/lua"
  printf 'my init\n' > "$H/.config/nvim/init.lua"
  printf 'my plugin\n' > "$H/.config/nvim/lua/mine.lua"
  cp -Rp "$H/.config/nvim" "$T/original"
  wizard "$NVIM_RUN"
  check "[[ \"\$(cat '$H/.config/nvim/init.lua')\" == starter ]]" "wizard's config in place"
  # A re-run finds LazyVim in place, so only rewrites files inside it.
  wizard 'journal_init; JOURNALING=1; printf "return { 2 }\n" | install_file "$HOME/.config/nvim/lua/plugins/colorscheme.lua"'
  wizard 'revert_all'
  check "diff -r '$T/original' '$H/.config/nvim' >/dev/null" "user's original config dir is back, identical"
  check "[[ -n \"\$(find '$STATE/reverted' -path '*/.config/nvim/init.lua')\" ]]" "wizard's tree kept under reverted/"
  cleanup
}

test_restore_brings_the_last_relocation_back() {
  new_home
  mkdir -p "$H/.config/nvim"
  printf 'my init\n' > "$H/.config/nvim/init.lua"
  wizard "$NVIM_RUN"
  printf 'return { "mine" }\n' > "$H/.config/nvim/lua/plugins/mine.lua"
  cli --revert
  check "[[ \"\$(cat '$H/.config/nvim/init.lua')\" == 'my init' ]]" "revert put the original back"
  cli --revert --restore
  check "[[ -f '$H/.config/nvim/lua/plugins/mine.lua' ]]" "restore brings the relocated tree back, user's files included"
  check "[[ \"\$(cat '$H/.config/nvim/init.lua')\" == starter ]]" "the wizard's config is in place again"
  check "grep -rqx 'my init' '$STATE/reverted'" "what was in the way is relocated, not overwritten"
  cli --revert --restore
  check "grep -qi 'nothing to restore' '$T/out'" "a relocation is only restored once"
  cleanup
}

test_restore_never_reaches_back_to_an_older_revert() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "one\n" | install_file "$HOME/.config/a"'
  cli --revert
  wizard 'journal_init; JOURNALING=1; printf "two\n" | install_file "$HOME/.config/b"'
  cli --revert
  cli --revert --restore
  check "[[ -f '$H/.config/b' ]]" "latest revert's file restored"
  cli --revert --restore
  check "[[ ! -e '$H/.config/a' ]]" "a second --restore doesn't bring back an older revert's file"
  check "grep -qi 'nothing to restore' '$T/out'" "says there is nothing to restore"
  cleanup
}

test_restore_that_fails_can_be_retried() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.config/a/file"'
  cli --revert
  # Something the restore can't move out of the way: a parent that's a file.
  mkdir -p "$H/.config"; rmdir "$H/.config/a"; printf 'blocker\n' > "$H/.config/a"
  cli --revert --restore
  check "grep -q \"couldn't put back\" '$T/out'" "the failure is reported"
  check "[[ -n \"\$(ls '$STATE'/reverted/*/manifest 2>/dev/null)\" ]]" "manifest kept so --restore can be retried"
  cleanup
}

test_same_second_stamps_sort_in_order() {
  new_home
  local s last=""
  mkdir -p "$STATE/reverted"
  for s in 1 2 3 4 5 6 7 8 9 10 11; do
    last=$(HOME="$H" bash -c "source '$WIZARD'; revert_stamp")
    mkdir "$STATE/reverted/$last"
  done
  check "[[ \"\$(ls '$STATE/reverted' | tail -1)\" == '$last' ]]" "the last stamp made sorts last"
  cleanup
}

test_restore_with_nothing_relocated_is_a_clean_no_op() {
  new_home
  cli --revert --restore
  local status=$?
  check "[[ $status == 0 ]]" "exits 0 (got $status)"
  check "grep -qi 'nothing to restore' '$T/out'" "says there is nothing to restore"
  cleanup
}

test_track_file_journals_and_reverts_an_external_tools_write() {
  new_home
  mkdir -p "$H/.codex"
  printf 'model = "mine"\n' > "$H/.codex/config.toml"
  cp "$H/.codex/config.toml" "$T/original"
  wizard 'journal_init; JOURNALING=1
    tool() { printf "[hooks]\n" >> "$HOME/.codex/config.toml"; }
    track_file "$HOME/.codex/config.toml" tool
    track_file "$HOME/.codex/hooks.json" printf ""'
  check "grep -q \"MODIFY	$H/.codex/config.toml\" '$STATE/journal.tsv'" "tool's change journaled as MODIFY"
  check "! grep -q hooks.json '$STATE/journal.tsv'" "a file the tool didn't touch isn't journaled"
  wizard 'revert_all'
  same_bytes "$H/.codex/config.toml" "$T/original" "original restored"
  cleanup
}

MANUAL_RUN='journal_init; JOURNALING=1
  journal_manual "Turn Ctrl-Space back on for input sources" "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
  journal_manual "Turn off notifications for terminal-notifier" "x-apple.systempreferences:com.apple.Notifications-Settings.extension"'

test_manual_changes_print_as_a_numbered_checklist() {
  new_home
  wizard "$MANUAL_RUN"
  wizard "$MANUAL_RUN"
  check "[[ '$(grep -c MANUAL "$STATE/journal.tsv")' == 2 ]]" "each manual change journaled once across runs"
  printf 'y\n\n' > "$T/answers"
  wizard 'open_url() { echo "OPENED $1"; }; revert_all'
  check "grep -q '1\. Turn Ctrl-Space back on for input sources' '$T/out'" "item 1 numbered"
  check "grep -q '2\. Turn off notifications for terminal-notifier' '$T/out'" "item 2 numbered"
  check "grep -q 'OPENED x-apple.systempreferences:com.apple.Keyboard-Settings.extension' '$T/out'" \
    "yes opens the right settings pane"
  check "! grep -q 'OPENED x-apple.systempreferences:com.apple.Notifications' '$T/out'" "Enter skips opening"
  check "[[ ! -e '$STATE/journal.tsv' ]]" "journal still archived"
  cleanup
}

# A pretend herdr: logs each call, with the herdr config as it stood at that
# moment, to $T/herdr.log, and says the tab plugin is linked.
FAKE_HERDR='herdr() {
  echo "$* | $(cat "$HOME/.config/herdr/config.toml" 2>/dev/null)" >> "$HOME/../herdr.log"
  [[ "$1 $2" == "plugin list" ]] && echo worktree-tabs; return 0; }'

test_revert_reloads_the_running_herdr_after_restoring_its_config() {
  new_home
  mkdir -p "$H/.config/herdr"
  printf 'prefix = "ctrl+b"\n' > "$H/.config/herdr/config.toml"
  wizard 'journal_init; JOURNALING=1
    printf "prefix = \"ctrl+space\"\n" | install_file "$HOME/.config/herdr/config.toml"
    printf "id = 1\n" | install_file "$HOME/.herdr/plugins/worktree-tabs/herdr-plugin.toml"
    journal_undo undo_herdr'
  wizard "$FAKE_HERDR; revert_all"
  check "grep -q '^server reload-config' '$T/herdr.log'" "herdr server reloads its config"
  check "grep -qF 'server reload-config | prefix = \"ctrl+b\"' '$T/herdr.log'" "reload happens after the config is back"
  check "grep -q '^plugin unlink worktree-tabs' '$T/herdr.log'" "tab plugin whose files moved away is unlinked"
  cleanup
}

test_unknown_undo_hooks_in_the_journal_are_not_run() {
  new_home
  wizard 'journal_init'
  printf '2026-01-01T00:00:00\tUNDO\tundo_nope;touch $HOME/pwned\n' >> "$STATE/journal.tsv"
  wizard 'revert_all'
  check "[[ ! -e '$H/pwned' ]]" "journal text is never executed"
  cleanup
}

# Function bodies as bash sees them, for the static checks below.
revert_path_source() {
  ( source "$WIZARD" >/dev/null 2>&1
    for f in $(declare -F | awk '{print $3}' | grep -E '^(revert_|relocate|restore_|undo_|strip_block|block_marker|in_journaled_dir|journaled_dirs)'); do
      declare -f "$f"
    done )
}

test_revert_path_never_deletes() {
  local bad
  # In command position: at the start of a line, or after ; & | ( or a keyword.
  bad=$(revert_path_source |
    grep -nE '(^|[;&|(]|then|do|else)[[:space:]]*(command[[:space:]]+)?(rm|rmdir|unlink|shred)([[:space:]]|;|$)|find .*-delete' || true)
  check "[[ -z \"\$bad\" ]]" "no rm/rmdir/unlink in the revert path: $bad"
  check "[[ -n \"\$(revert_path_source | grep -c relocate)\" ]]" "sanity: the revert path was actually read"
}

test_nothing_touches_symbolic_hotkeys_or_tcc() {
  local bad
  bad=$(grep -nE 'tccutil|defaults (write|delete).*symbolichotkeys|PlistBuddy .*(Set|Add|Delete)' "$WIZARD" || true)
  check "[[ -z \"\$bad\" ]]" "no writes to symbolichotkeys, no tccutil: $bad"
  check "! revert_path_source | grep -q symbolichotkeys" "revert path doesn't even read symbolichotkeys"
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

# End to end through the real CLI: the shell stage (8) writes marked blocks
# and new files. Twice, then --revert leaves the user's .zshrc as it was.
test_shell_stage_end_to_end() {
  new_home
  printf '# mine\nalias gs="git status"\n' > "$H/.zshrc"
  cp "$H/.zshrc" "$T/original"
  cli --only 8
  check "grep -q \"BLOCK	$H/.zshrc\" '$STATE/journal.tsv'" "stage 8 journals its .zshrc block"
  check "grep -q \"CREATE	$H/.local/bin/hproj\" '$STATE/journal.tsv'" "stage 8 journals the files it creates"
  cli --only 8
  cli --revert
  same_bytes "$H/.zshrc" "$T/original" "--revert leaves the user's .zshrc byte-identical"
  check "[[ ! -e '$H/.zprofile' && ! -e '$H/.local/bin/hproj' && ! -e '$H/.config/ghostty-herdr-cheatsheet.md' ]]" \
    "files the stage created are moved away"
  cleanup
}

# ── runner ────────────────────────────────────────────────────────────────

# bash tests/journal_test.sh [NAME...]: every test, or just the named ones.
for t in ${@:-$(declare -F | awk '{print $3}' | grep '^test_')}; do
  printf '%s\n' "$t"
  "$t"
done
printf '\n%d passed, %d failed\n' "$PASSES" "$FAILS"
(( FAILS == 0 ))
