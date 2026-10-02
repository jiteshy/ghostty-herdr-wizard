#!/usr/bin/env bash
# Tests for the stage list and the flags that pick stages by name: one stage
# for the mandatory work, one per tool group, and a tour.
#
#   bash tests/stages_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# ── tests ─────────────────────────────────────────────────────────────────

test_list_prints_the_stage_names_in_order() {
  new_home
  cli --list
  local names
  names=$(awk '{print $1}' "$T/out" | tr '\n' ' ')
  check "[[ '$names' == 'choices install ghostty herdr macos prompt shell editor review yazi github statusline tour ' ]]" \
    "--list prints the 13 stage names in order (got '$names')"
  cleanup
}

# wanted ARGS...: the stages a run with these flags would run, space-separated.
wanted() {
  wizard "parse_args $* || { echo usage-error; exit; }
    for e in \"\${STAGES[@]}\"; do stage_wanted \"\${e%%:*}\" && printf '%s ' \"\${e%%:*}\"; done"
  cat "$T/out"
}

test_flags_pick_stages_by_name() {
  new_home
  check "[[ '$(wanted --only review,yazi)' == 'review yazi ' ]]" "--only runs just the named stages"
  check "[[ '$(wanted --skip yazi,github)' == 'choices install ghostty herdr macos prompt shell editor review statusline tour ' ]]" \
    "--skip runs everything but the named stages"
  check "[[ '$(wanted --from editor)' == 'editor review yazi github statusline tour ' ]]" "--from starts at the named stage"
  check "[[ '$(wanted --tour)' == 'tour ' ]]" "--tour is --only tour"
  check "[[ '$(wanted)' == 'choices install ghostty herdr macos prompt shell editor review yazi github statusline tour ' ]]" \
    "no flags runs every stage"
  cleanup
}

test_numbers_and_unknown_names_are_rejected() {
  new_home
  local bad
  for bad in '--only 3' '--skip 11,13' '--from 12' '--only nope' '--only review,' '--only review,,yazi' '--from editor,yazi' '--only'; do
    wanted $bad > /dev/null
    check "grep -q usage-error '$T/out'" "rejects $bad"
  done
  local status
  cli --only yazi,nope; status=$?
  check "[[ $status == 2 ]]" "the CLI exits 2 on an unknown stage (got $status)"
  check "grep -q 'unknown stage \"nope\"' '$T/out'" "the CLI names the unknown stage"
  check "grep -q 'yazi github statusline tour' '$T/out'" "and lists the real ones"
  cleanup
}

test_install_brews_every_stage_tool_once() {
  new_home
  wizard 'install_formulae'
  check "grep -qx neovim '$T/out' && grep -qx yazi '$T/out' && grep -qx herdr '$T/out' && grep -qx jq '$T/out'" \
    "install covers every stage's tools"
  check "[[ '$(grep -cx fd "$T/out")' == 1 && '$(grep -cx ripgrep "$T/out")' == 1 ]]" \
    "fd and ripgrep (shell and editor both need them) are listed once"
  wizard 'parse_args --skip yazi,github; install_formulae'
  check "! grep -qxE 'yazi|poppler|resvg|gh' '$T/out'" "a skipped stage's tools aren't installed"
  check "grep -qx neovim '$T/out'" "the other stages' tools still are"
  cleanup
}

# choices_run LINE...: run the choices stage alone, answering with these lines
# (the first is the opening banner's Enter).
choices_run() {
  printf '%s\n' "$@" > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
}

test_choices_are_asked_once_and_saved() {
  new_home
  # banner, untick icons, accept, prefix/theme/prompt defaults, projects folder, create it, my tab names (four of them), done
  choices_run '' 1 '' '' '' '' "$H/repos" y 2 ai code srv diff ''
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "icons answer saved"
  check "grep -qx 'PROJECTS_DIR=$H/repos' '$STATE/choices.env'" "projects folder saved"
  check "grep -qx 'TABS=ai,code,srv,diff' '$STATE/choices.env'" "tab names saved"
  check "[[ -d '$H/repos' ]]" "the projects folder was created"
  wizard 'printf "%s|%s|%s" "$GLYPHS" "$DEFAULT_TABS" "$(current_projects_dir)"'
  check "[[ '$(cat "$T/out")' == 'off|ai,code,srv,diff|$H/repos' ]]" \
    "later stages start from the saved answers (got '$(cat "$T/out")')"
  cleanup
}

test_a_rerun_offers_last_times_answers() {
  new_home
  choices_run '' 1 '' '' '' '' "$H/repos" y 1 ''
  cp "$STATE/choices.env" "$T/first"
  choices_run '' y
  check "grep -q \"Last time's answers\" '$T/out'" "a re-run shows last time's answers"
  same_bytes "$STATE/choices.env" "$T/first" "yes keeps them unchanged"
  check "! grep -q 'Projects folder' '$T/out'" "yes asks nothing more"
  # No: ask again, Enter keeps each answer, no default tabs this time.
  choices_run '' n '' '' '' '' '' 3 ''
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env' && grep -qx 'PROJECTS_DIR=$H/repos' '$STATE/choices.env'" \
    "no asks again, Enter keeping each answer"
  check "grep -qx 'TABS=none' '$STATE/choices.env'" "no default tabs is saved as none"
  wizard 'printf "[%s]" "$DEFAULT_TABS"'
  check "[[ '$(cat "$T/out")' == '[]' ]]" "saved none means no default tabs (got '$(cat "$T/out")')"
  # Changing their mind: the suggested four again.
  choices_run '' n '' '' '' '' '' 1 ''
  check "grep -qx 'TABS=agents,source code,local server,git review' '$STATE/choices.env'" \
    "after no tabs, the suggested four are one answer away"
  cleanup
}

# --only shell with a projects folder that isn't there (never chosen, or
# deleted since) says so rather than pointing p at nothing in silence.
test_shell_warns_when_the_projects_folder_is_missing() {
  new_home
  mkdir -p "$STATE"
  printf 'PROJECTS_DIR=%s\n' "$H/gone" > "$STATE/choices.env"
  ( # subshell: the fake brew and bat on PATH never outlive this test
    fake_brew
    fake_bat
    cli --only shell
    check "grep -q 'find nothing until $H/gone exists' '$T/out'" "the shell stage warns about the missing folder"
    check "grep -q 'PROJECTS_DIR=\"\$HOME/gone\"' '$H/.zprofile'" "and still writes the chosen folder"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
