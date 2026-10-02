#!/usr/bin/env bash
# Tests for the guided tour: one stage whose screens are picked by what the
# user selected and installed, so it never tours a tool they declined.
#
#   bash tests/tour_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

ALWAYS="launch navigation agents tabs habits"
FULL="prompt,jumper,typing,editor,review,files,github,statusline"
EVERY="launch navigation agents tabs editor review files github statusline habits"

# tools_on_path: fake nvim, lazygit, yazi and a gh with gh-dash in $T/bin, and a
# PATH of just that plus the system's, so the real machine's tools never count.
# jq comes along: the status line check reads settings.json with it.
tools_on_path() {
  mkdir -p "$T/bin"
  local tool
  for tool in nvim lazygit yazi; do printf '#!/bin/sh\nexit 0\n' > "$T/bin/$tool"; done
  printf '#!/bin/sh\n[ "$1 $2" = "extension list" ] && echo "gh dash  dlvhdr/gh-dash  v4.7.0"\nexit 0\n' > "$T/bin/gh"
  chmod +x "$T/bin"/*
  ln -sf "$(command -v jq)" "$T/bin/jq"
  TOUR_PATH="$T/bin:/usr/bin:/bin"
}

# statusline_set_up: the status line as the statusline stage leaves it.
statusline_set_up() {
  mkdir -p "$H/.claude"
  printf '{"statusLine":{"type":"command","command":"%s"}}\n' "$H/.claude/statusline.sh" > "$H/.claude/settings.json"
}

# sections TOOLS: the sections the tour runs with these tools selected.
sections() {
  wizard "PATH='$TOUR_PATH'; TOOLS=',$1,'; tour_sections | cut -d: -f1 | tr '\n' ' '"
  sed 's/ $//' "$T/out"
}

# tour TOOLS [CODE]: the whole tour stage inside herdr, Enter at every screen.
tour() {
  wizard "PATH='$TOUR_PATH'; TOOLS=',$1,'; HERDR_ENV=1; ${2:-} stage_tour"
}

# ── tests ─────────────────────────────────────────────────────────────────

test_the_tour_is_one_stage() {
  new_home
  wizard 'for e in "${STAGES[@]}"; do echo "${e%%:*}"; done'
  check "[[ '$(grep -c tour "$T/out")' == 1 ]]" "one tour stage in the registry"
  cleanup
}

test_sections_follow_what_was_selected_and_installed() {
  new_home
  tools_on_path
  statusline_set_up
  check "[[ '$(sections none)' == '$ALWAYS' ]]" "nothing selected: just the always-on sections (got '$(sections none)')"
  check "[[ '$(sections "$FULL")' == '$EVERY' ]]" \
    "everything selected and installed: every section (got '$(sections "$FULL")')"
  check "[[ '$(sections files,github)' == 'launch navigation agents tabs files github habits' ]]" \
    "a section runs only for its own tool (got '$(sections files,github)')"
  rm "$T/bin/yazi" "$T/bin/nvim" "$H/.claude/settings.json"
  check "[[ '$(sections "$FULL")' == 'launch navigation agents tabs review github habits' ]]" \
    "selected but not installed: no section (got '$(sections "$FULL")')"
  cleanup
}

test_the_counter_counts_the_sections_that_run() {
  new_home
  tools_on_path
  tour none
  check "grep -q 'Tour 1/5 ' '$T/out' && grep -q 'Tour 5/5 ' '$T/out' && ! grep -q 'Tour 6/' '$T/out'" \
    "a minimal tour counts 1 to 5"
  check "grep -q 'Press Enter for 2 of 5' '$T/out'" "the pause names the next screen of the 5"
  check "! grep -qE 'of 9|step [0-9]' '$T/out'" "no fixed screen numbers left"
  statusline_set_up
  tour "$FULL"
  check "grep -q 'Tour 10/10 ' '$T/out'" "a full tour counts to 10"
  cleanup
}

test_a_minimal_tour_names_no_unselected_tool() {
  new_home
  tools_on_path
  tour none
  check "! grep -qiE 'nvim|neovim|lazygit|yazi|gh dash|gh-dash|herdr-hunk|status line|Space g|prefix [dfim] |Cmd-O|Cmd-E|v \\.' '$T/out'" \
    "no editor, review, file manager, GitHub, status line or project jumper"
  grep -niE 'nvim|neovim|lazygit|yazi|gh dash|gh-dash|herdr-hunk|status line|Space g|prefix [dfim] |Cmd-O|Cmd-E|v \.' "$T/out" | sed 's/^/      /'
  check "grep -q 'prefix Shift-N' '$T/out'" "without the jumper, workspaces open with herdr's own key"
  cleanup
}

# tabs_screen TABS [CODE]: the tabs and review screens for these default tabs,
# editor and review selected and installed.
tabs_screen() {
  wizard "PATH='$TOUR_PATH'; TOOLS=',editor,review,'; DEFAULT_TABS='$1'; ${2:-} tour_tabs; tour_review"
}

test_the_tabs_screen_follows_the_users_tabs() {
  new_home
  tools_on_path
  tabs_screen 'agents,source code,local server' 'tour_hunk() { return 0; };'
  check "grep -q '4 git review' '$T/out'" "suggested three with herdr-hunk: git review listed as tab 4"
  check "grep -q 'In tab 2 (source code)' '$T/out' && grep -q 'In tab 3 (local server)' '$T/out'" \
    "the suggested layout gets numbered steps"
  check "grep -q 'Cmd-1…4 jump' '$T/out'" "Cmd range covers the four"
  check "grep -q 'or tab 4 (git review)' '$T/out'" "the review screen points at tab 4"

  tabs_screen 'ai,code' 'tour_hunk() { return 1; };'
  check "grep -q '2 code' '$T/out' && ! grep -q 'git review' '$T/out'" "two own tabs, no herdr-hunk: just those two"
  check "! grep -qE 'tab [0-9] \\(' '$T/out'" "no numbered steps for a layout of the user's own"
  check "grep -q 'Cmd-1 / Cmd-2 jump' '$T/out' && ! grep -qE 'Cmd-3|…4' '$T/out'" "Cmd range covers just the two"

  tabs_screen 'a,b,c,d' 'tour_hunk() { return 0; };'
  check "grep -q '5 git review' '$T/out'" "four own tabs with herdr-hunk: git review is tab 5"
  check "grep -q 'or tab 5 (git review)' '$T/out'" "and the review screen says so"

  tabs_screen 'solo' 'tour_hunk() { return 1; };'
  check "! grep -q 'jump between tabs' '$T/out'" "one tab: nothing to jump between"
  cleanup
}

test_the_tour_can_be_skipped_from_any_screen() {
  new_home
  tools_on_path
  printf '\ns\n' > "$T/answers"
  wizard "PATH='$TOUR_PATH'; TOOLS=',none,'; HERDR_ENV=1; stage_tour; echo \"stage-returned:\$?\""
  check "grep -q 'Tour 2/5 ' '$T/out' && ! grep -q 'Tour 3/5' '$T/out'" "s on screen 2 ends the tour there"
  check "grep -q 'stage-returned:0' '$T/out'" "skipping ends the stage cleanly"
  check "grep -q -- '--tour' '$T/out'" "and says how to replay it"
  cleanup
}

test_no_screen_asks_to_change_a_persistent_setting() {
  new_home
  tools_on_path
  statusline_set_up
  tour "$FULL"
  check "grep -q 'effort' '$T/out'" "the status line screen still shows the effort segment"
  check "! grep -qE 'Type /effort|/effort and|Lower /effort|Type /model' '$T/out'" \
    "no instruction to change effort or model"
  cleanup
}

test_the_tour_uses_the_chosen_prefix() {
  new_home
  tools_on_path
  statusline_set_up
  tour "$FULL" 'PREFIX=ctrl-b;'
  check "grep -q 'Ctrl-B' '$T/out' && ! grep -q 'Ctrl-Space' '$T/out'" "Ctrl-B named, Ctrl-Space never"
  cleanup
}

test_tour_output_follows_the_glyph_switch() {
  new_home
  tools_on_path
  statusline_set_up
  tour "$FULL" 'GLYPHS=off;'
  check "! perl -CSD -ne '\$f = 1 if /[\\x{E000}-\\x{F8FF}\\x{F0000}-\\x{10FFFF}]/; END { exit !\$f }' '$T/out'" \
    "glyphs off: no Nerd Font glyph in the tour"
  cleanup
}

test_replay_by_flag_and_by_name() {
  new_home
  wizard 'parse_args --tour; for e in "${STAGES[@]}"; do stage_wanted "${e%%:*}" && echo "${e%%:*}"; done'
  check "[[ '$(cat "$T/out")' == tour ]]" "--tour runs just the tour"
  wizard 'parse_args --only tour; for e in "${STAGES[@]}"; do stage_wanted "${e%%:*}" && echo "${e%%:*}"; done'
  check "[[ '$(cat "$T/out")' == tour ]]" "--only tour runs just the tour"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
