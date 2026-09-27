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
  names=$(awk '{print $2}' "$T/out" | tr '\n' ' ')
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
  # banner, plain text, projects folder, create it, default tabs, not those, my names, done
  choices_run '' 2 "$H/repos" y y n 'agents,server' ''
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "icons answer saved"
  check "grep -qx 'PROJECTS_DIR=$H/repos' '$STATE/choices.env'" "projects folder saved"
  check "grep -qx 'TABS=agents,server' '$STATE/choices.env'" "tab names saved"
  check "[[ -d '$H/repos' ]]" "the projects folder was created"
  wizard 'printf "%s|%s|%s" "$GLYPHS" "$DEFAULT_TABS" "$(current_projects_dir)"'
  check "[[ '$(cat "$T/out")' == 'off|agents,server|$H/repos' ]]" \
    "later stages start from the saved answers (got '$(cat "$T/out")')"
  cleanup
}

test_a_rerun_offers_last_times_answers() {
  new_home
  choices_run '' 2 "$H/repos" y y y ''
  cp "$STATE/choices.env" "$T/first"
  choices_run '' y
  check "grep -q \"Last time's answers\" '$T/out'" "a re-run shows last time's answers"
  same_bytes "$STATE/choices.env" "$T/first" "yes keeps them unchanged"
  check "! grep -q 'Projects folder' '$T/out'" "yes asks nothing more"
  # No: ask again, Enter keeps each answer, no default tabs this time.
  choices_run '' n '' '' n ''
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env' && grep -qx 'PROJECTS_DIR=$H/repos' '$STATE/choices.env'" \
    "no asks again, Enter keeping each answer"
  check "grep -qx 'TABS=' '$STATE/choices.env'" "no default tabs is saved as empty"
  wizard 'printf "[%s]" "$DEFAULT_TABS"'
  check "[[ '$(cat "$T/out")' == '[]' ]]" "saved empty means no default tabs (got '$(cat "$T/out")')"
  # Changing their mind: yes to tabs, yes to the standard set.
  choices_run '' n '' '' y y ''
  check "grep -qx 'TABS=agents,code,dev server,git review' '$STATE/choices.env'" \
    "after no tabs, yes offers the standard set again"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
