#!/usr/bin/env bash
# Tests for the runtime REPLACES badges and the plan summary: each stage says,
# from the filesystem right before it runs, which of the user's files it will
# replace, and one plan up front shows the whole run before a single Go.
#
#   bash tests/plan_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# ── tests ─────────────────────────────────────────────────────────────────

test_a_stage_on_a_fresh_home_only_adds() {
  new_home
  wizard 'stage_badges prompt'
  check "grep -q 'adds 1 new file' '$T/out'" "the prompt stage adds one new file"
  check "! grep -q REPLACES '$T/out'" "nothing to replace on a fresh home"
  cleanup
}

test_a_file_the_user_has_is_named_as_replaced() {
  new_home
  mkdir -p "$H/.config/yazi"
  printf 'mine\n' > "$H/.config/yazi/theme.toml"
  wizard 'stage_badges yazi'
  check "grep -q 'REPLACES 1 file you already have' '$T/out'" "the badge counts the user's file"
  check "grep -q '~/.config/yazi/theme.toml' '$T/out'" "and names it"
  check "grep -q '~/.ghostty-herdr-wizard/backups/' '$T/out'" "and says where the copy goes"
  check "grep -q -- '--revert' '$T/out'" "and how to undo it"
  check "! grep -q 'new file' '$T/out'" "nothing is new"
  cleanup
}

test_the_wizards_own_file_is_not_replaced_until_the_user_edits_it() {
  new_home
  wizard 'journal_init; JOURNALING=1; printf "x\n" | install_file "$HOME/.config/starship.toml"'
  wizard 'stage_badges prompt'
  check "! grep -q REPLACES '$T/out'" "a re-run doesn't call its own file the user's"
  check "grep -q 'refreshes 1 file it set up before' '$T/out'" "it says it refreshes its own file"
  printf 'my tweak\n' >> "$H/.config/starship.toml"
  wizard 'stage_badges prompt'
  check "grep -q 'REPLACES 1 file' '$T/out'" "once the user edits it, it is theirs to lose"
  cleanup
}

test_block_files_are_added_to_not_replaced() {
  new_home
  printf 'export EDITOR=vi\n' > "$H/.zshrc"
  wizard 'stage_badges shell'
  check "! grep -q REPLACES '$T/out'" "a marked block never replaces ~/.zshrc"
  check "grep -q 'adds its own lines to 1 file you have' '$T/out'" "the badge says it adds lines"
  check "grep -q '~/.zshrc' '$T/out'" "and names the file"
  cleanup
}

test_an_nvim_folder_that_isnt_lazyvim_is_replaced_whole() {
  new_home
  mkdir -p "$H/.config/nvim"
  printf 'set number\n' > "$H/.config/nvim/init.vim"
  wizard 'stage_badges editor'
  check "grep -q 'REPLACES 1 folder you already have' '$T/out'" "the whole folder is named as replaced"
  check "grep -q '~/.config/nvim/$' '$T/out'" "shown as a folder"
  mkdir -p "$H/.config/nvim/lua/config"
  printf 'spec = { { "LazyVim/LazyVim", import = "lazyvim.plugins" }, { import = "lazyvim.plugins.extras.lang.typescript" } }\n' > "$H/.config/nvim/lua/config/lazy.lua"
  wizard 'stage_badges editor'
  check "! grep -q REPLACES '$T/out'" "an existing LazyVim is added to, not replaced"
  check "grep -q 'adds 4 new files' '$T/out'" "the three plugin files and autocmds.lua are new"
  cleanup
}

test_the_badges_follow_the_choices() {
  new_home
  wizard 'TOOLS=",typing,"; stage_badges shell'
  check "! grep -q hproj '$T/out' && grep -q 'adds 3 new files' '$T/out'" "no project jumper, no hproj"
  wizard 'TOOLS=",jumper,"; stage_badges shell'
  check "grep -q 'adds 4 new files' '$T/out'" "with it, hproj too"
  cleanup
}

test_a_run_shows_the_badge_under_the_stage_header() {
  new_home
  mkdir -p "$H/.config/yazi"
  printf 'mine\n' > "$H/.config/yazi/theme.toml"
  ( # subshell: the fake brew on PATH never outlives this test
    fake_brew
    cli --only yazi
    check "grep -A2 'Stage .* yazi file manager' '$T/out' | grep -q 'REPLACES 1 file'" \
      "the badge comes right after the header"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

# parsed ARGS...: "YES MODE FROM ONLY" after parse_args, or usage-error.
parsed() {
  wizard "parse_args $* || { echo usage-error; exit; }; echo \"\$YES \$MODE \$FROM \$ONLY\""
  cat "$T/out"
}

test_yes_goes_with_any_run() {
  new_home
  check "[[ '$(parsed --yes)' == '1 run  ' ]]" "--yes alone (got '$(parsed --yes)')"
  check "[[ '$(parsed --yes --from editor)' == '1 run editor ' ]]" "--yes before --from"
  check "[[ '$(parsed --only herdr,macos --yes)' == '1 run  ,herdr,macos,' ]]" "--yes after --only"
  check "[[ '$(parsed --from editor)' == '0 run editor ' ]]" "no --yes, no YES"
  local bad
  for bad in '--revert --yes' '--yes --list' '--yes --revert --restore' '--yes --yes' '--yes nope' '--yes --uninstall'; do
    check "[[ '$(parsed $bad)' == usage-error ]]" "rejects $bad"
  done
  cleanup
}

test_yes_makes_pauses_no_ops_but_not_real_interactions() {
  new_home
  printf 'first\nsecond\n' > "$T/answers"
  wizard 'YES=1; pause; read -r line; echo "read:$line"'
  check "grep -q 'read:first$' '$T/out'" "--yes: a pause between stages reads nothing"
  wizard 'YES=1; wait_for_user "Press Enter when done"; read -r line; echo "read:$line"'
  check "grep -q 'read:second$' '$T/out'" "--yes: a step only the user can do still waits"
  wizard 'pause; read -r line; echo "read:$line"'
  check "grep -q 'read:second$' '$T/out'" "without --yes a pause waits"
  cleanup
}

test_yes_skips_the_tour_unless_asked_for() {
  new_home
  wizard 'parse_args --yes; stage_tour'
  check "grep -q -- 'skipped with --yes' '$T/out' && ! grep -q 'Tour 1/' '$T/out'" "a --yes re-run skips the tour"
  wizard 'parse_args --yes --only tour; stage_tour'
  check "grep -q 'Tour 1/' '$T/out'" "--yes --only tour still gives the tour"
  cleanup
}

# plan ARGS...: the plan a run with these flags shows, from outside Ghostty,
# with a brew that has nothing installed. GLYPHS off, only the review group.
plan() {
  ( # subshell: the fake brew on PATH never outlives this call
    fake_brew
    # The Xcode tools are there, whatever this machine has.
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/xcode-select"
    chmod +x "$T/bin/xcode-select"
    wizard "export TERM_PROGRAM=Apple_Terminal HERDR_ENV=; GLYPHS=off; TOOLS=,review,
      parse_args $*; show_plan"
  )
}

test_the_plan_counts_the_tools_to_install() {
  new_home
  plan
  # herdr, terminal-notifier, lazygit; Ghostty too where it isn't installed.
  local n=3
  [[ -d /Applications/Ghostty.app ]] || n=4
  check "grep -q 'install $n tools' '$T/out'" "counts what brew doesn't have yet (want $n)"
  plan --skip install
  check "! grep -q 'install [0-9]' '$T/out'" "no install stage, no install line"
  cleanup
}

test_the_plan_names_the_files_it_replaces() {
  new_home
  plan
  check "grep -q 'replaces none of your files' '$T/out'" "a fresh home loses nothing"
  mkdir -p "$H/.config/ghostty" "$H/.config/herdr"
  printf 'mine\n' > "$H/.config/ghostty/config"
  printf 'mine\n' > "$H/.config/herdr/config.toml"
  printf 'mine\n' > "$H/.zshrc"
  plan
  check "grep -q '⚠ replaces 2 existing files' '$T/out'" "counts the user's files across stages"
  check "grep -q '~/.config/ghostty/config' '$T/out' && grep -q '~/.config/herdr/config.toml' '$T/out'" "and names them"
  check "! grep -q '~/.zshrc' '$T/out'" "a block in ~/.zshrc isn't a replace"
  plan --only review
  check "grep -q 'replaces none of your files' '$T/out'" "only the stages in this run count"
  cleanup
}

test_the_plan_lists_where_it_needs_you() {
  new_home
  plan
  check "grep -q '4 points where it needs you' '$T/out'" "all four on a first run from outside Ghostty"
  local need
  for need in 'relaunch into Ghostty' 'allow notifications' 'allow accessibility' 'free ctrl+space'; do
    check "grep -q '$need' '$T/out'" "lists: $need"
  done
  plan --skip macos
  check "grep -q '2 points where it needs you' '$T/out' && ! grep -q notifications '$T/out'" \
    "only the stages in this run count"
  ( fake_brew; wizard 'export TERM_PROGRAM=ghostty; parse_args --only review; show_plan' )
  check "grep -q 'needs nothing from you' '$T/out'" "a run with none says so"
  check "grep -q -- '--revert' '$T/out'" "the undo promise is always there"
  cleanup
}

# saved_choices: answers from an earlier run, so choices offers to reuse them.
saved_choices() {
  mkdir -p "$STATE" "$H/repos"
  printf '%s\n' GLYPHS=off TOOLS=review TABS=none "PROJECTS_DIR=$H/repos" > "$STATE/choices.env"
}

test_saying_no_to_the_plan_changes_nothing() {
  new_home
  saved_choices
  printf '%s\n' '' y n > "$T/answers" # banner, reuse last answers, Go? no
  ( # subshell: the fake brew on PATH never outlives this test
    fake_brew
    CLI_INPUT="$T/answers" cli --only choices,review
    printf '%s\n' "$?" > "$T/status"
  )
  check "grep -q 'Plan' '$T/out' && grep -q 'Go?' '$T/out'" "the run shows the plan and asks once"
  check "[[ '$(cat "$T/status")' == 0 ]]" "no is a clean exit"
  check "grep -q 'No files changed' '$T/out'" "and says no files changed"
  check "! grep -q 'Stage .* lazygit' '$T/out'" "no stage after choices ran"
  cleanup
}

test_yes_reuses_answers_and_skips_the_go() {
  new_home
  saved_choices
  : > "$T/answers" # no keyboard at all
  ( # subshell: the fake brew on PATH never outlives this test
    fake_brew
    CLI_INPUT="$T/answers" cli --yes --only choices,review
  )
  check "! grep -q \"Use last time's answers\" '$T/out'" "--yes reuses the saved answers without asking"
  check "grep -q 'Plan' '$T/out' && ! grep -q 'Go?' '$T/out'" "the plan is shown, but no Go"
  check "grep -q 'Stage .* lazygit' '$T/out'" "the stages run"
  cleanup
}

test_choices_alone_shows_no_plan() {
  new_home
  saved_choices
  printf '%s\n' '' y > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
  check "! grep -q 'Plan' '$T/out'" "nothing to plan when only the questions run"
  cleanup
}

test_the_plan_says_when_everything_is_installed() {
  new_home
  mkdir -p "$T/bin"
  # A brew that has every formula already.
  printf '#!/bin/sh\n[ "$1" = list ] && printf "%%s\\n" herdr terminal-notifier lazygit\nexit 0\n' > "$T/bin/brew"
  chmod +x "$T/bin/brew"
  wizard "PATH='$T/bin':\$PATH; export TERM_PROGRAM=ghostty; GLYPHS=off; TOOLS=,review,; show_plan"
  if [[ -d /Applications/Ghostty.app ]]; then
    check "grep -q 'nothing new to install' '$T/out'" "nothing missing, nothing to install"
  else
    check "grep -q 'install 1 tool$' '$T/out'" "only Ghostty is missing"
  fi
  cleanup
}

test_the_plan_names_every_stop_that_applies() {
  new_home
  mkdir -p "$T/bin"
  # No Xcode tools, no gh login.
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/xcode-select"
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/gh"
  chmod +x "$T/bin/xcode-select" "$T/bin/gh"
  ( fake_brew; wizard "PATH='$T/bin':\$PATH; export TERM_PROGRAM=ghostty; TOOLS=,editor,github,; show_plan" )
  local need
  for need in 'install the Xcode command line tools' 'sign in to GitHub' 'open Neovim once'; do
    check "grep -q '$need' '$T/out'" "lists: $need"
  done
  cleanup
}

test_edits_that_change_nothing_are_not_listed() {
  new_home
  mkdir -p "$H/.config/nvim/lua/config"
  printf '"LazyVim/LazyVim"\n"lazyvim.plugins.extras.lang.typescript"\n' > "$H/.config/nvim/lua/config/lazy.lua"
  wizard 'stage_badges editor'
  check "! grep -q 'lazy.lua' '$T/out'" "extras already on: lazy.lua isn't touched"
  printf '"LazyVim/LazyVim"\n' > "$H/.config/nvim/lua/config/lazy.lua"
  wizard 'stage_badges editor'
  check "grep -q 'REPLACES 1 file' '$T/out' && grep -q 'lazy.lua' '$T/out'" \
    "adding extras rewrites lazy.lua whole, so it's a replace"
  cleanup
}

test_a_folder_the_wizard_once_made_is_still_replaced() {
  new_home
  mkdir -p "$H/.config/nvim"
  printf 'x\n' > "$H/.config/nvim/init.vim"
  wizard 'journal_init; JOURNALING=1; journal_write "$HOME/.config/nvim" false'
  wizard 'stage_badges editor'
  check "grep -q 'REPLACES 1 folder' '$T/out'" "a non-LazyVim nvim folder is moved aside, whoever made it"
  cleanup
}

test_yes_answers_the_agent_hook_questions() {
  new_home
  wizard 'YES=1; ask_or_yes "Install it?" && echo said-yes'
  check "grep -q said-yes '$T/out' && ! grep -q 'Install it' '$T/out'" "--yes says yes without asking"
  printf 'n\n' > "$T/answers"
  wizard 'ask_or_yes "Install it?" && echo said-yes'
  check "grep -q 'Install it' '$T/out' && ! grep -q said-yes '$T/out'" "without --yes it asks"
  cleanup
}

test_the_review_badge_covers_herdr_hunk() {
  new_home
  mkdir -p "$H/.config/herdr"
  printf 'mine\n' > "$H/.config/herdr/config.toml"
  wizard 'node_ok() { return 0; }; TOOLS=,review,; DEFAULT_TABS=; stage_badges review'
  check "grep -q 'adds its own lines to 1 file' '$T/out' && grep -q '~/.config/herdr/config.toml' '$T/out'" \
    "herdr-hunk's keys go into herdr's config, the rest stays"
  wizard 'node_ok() { return 0; }; TOOLS=,review,; DEFAULT_TABS=agents; stage_badges review'
  check "grep -q 'adds 2 new files' '$T/out'" "with default tabs, herdr-hunk's own config too"
  wizard 'node_ok() { return 1; }; TOOLS=,review,; stage_badges review'
  check "! grep -q 'herdr/config.toml' '$T/out'" "Node too old: no herdr-hunk, nothing of its listed"
  cleanup
}

test_a_stage_without_files_says_nothing() {
  new_home
  wizard 'stage_badges macos; stage_badges tour'
  check "[[ ! -s '$T/out' ]]" "no badge for stages that write no files"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
