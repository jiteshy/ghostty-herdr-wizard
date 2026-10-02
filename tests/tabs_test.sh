#!/usr/bin/env bash
# Tests for the default tabs: the one numbered question that picks them, and the
# herdr hook that opens them in new workspaces, plus a git review tab at the end
# for herdr-hunk when it is installed.
#
#   bash tests/tabs_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

SUGGESTED="agents,source code,local server"
LEGACY="agents,source code,local server,git review"

# answer LINE...: the lines the next wizard run reads from stdin.
answer() { printf '%s\n' "$@" > "$T/answers"; }

# fake_herdr [hunk]: a herdr on PATH for the tab hook. Every call is logged to
# $T/herdr.log; the one workspace is new, on its single starting tab (or on
# $T/tabcount tabs when that file exists). With "hunk", the herdr-hunk plugin
# shows up in `plugin list`.
fake_herdr() {
  mkdir -p "$T/bin"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$T/herdr.log"
count=\$(cat "$T/tabcount" 2>/dev/null || echo 1)
case "\$1 \$2" in
  "workspace list") echo "{\"result\":{\"workspaces\":[{\"workspace_id\":\"w1\",\"active_tab_id\":\"w1:t1\",\"tab_count\":\$count}]}}" ;;
  "pane list") echo '{"result":{"panes":[{"cwd":"/tmp/repo"}]}}' ;;
  "tab create") n=\$(grep -c '^tab create' "$T/herdr.log"); echo "{\"result\":{\"tab\":{\"tab_id\":\"w1:t\$((n + 1))\"}}}" ;;
  "plugin list") echo "1 plugin installed:"; [ "${1:-}" = hunk ] && echo "- jhochenbaum.hunkdiff (hunk) enabled" ;;
esac
exit 0
EOF
  chmod +x "$T/bin/herdr"
}

# run_hook TABS [TOOLS]: write the plugin for these tabs (and selected groups,
# review among them unless TOOLS says otherwise), then fire its workspace hook
# the way herdr would: under macOS's system bash 3.2.
run_hook() {
  wizard "DEFAULT_TABS='$1'; TOOLS=',${2:-review},'; herdr() { :; }; write_worktree_tabs_plugin"
  : > "$T/herdr.log"
  HOME="$H" HERDR_BIN_PATH="$T/bin/herdr" HERDR_WORKSPACE_ID=w1 \
    HERDR_PLUGIN_STATE_DIR="$T/state" /bin/bash "$H/.herdr/plugins/worktree-tabs/apply-tab-layout.sh" workspace
}

# ── the question ──────────────────────────────────────────────────────────

test_suggested_tabs_are_the_default() {
  new_home
  wizard 'printf "%s" "$DEFAULT_TABS"'
  check "[[ '$(cat "$T/out")' == '$SUGGESTED' ]]" "first run starts on the three suggested tabs (got '$(cat "$T/out")')"
  cleanup
}

# saved TABS: DEFAULT_TABS as a run starts with this saved TABS choice.
saved() {
  mkdir -p "$STATE"
  printf 'TABS=%s\n' "$1" > "$STATE/choices.env"
  wizard 'printf "%s" "$DEFAULT_TABS"'
  cat "$T/out"
}

test_old_four_tab_choices_lose_their_review_tab() {
  new_home
  check "[[ '$(saved "$LEGACY")' == '$SUGGESTED' ]]" "the old suggested four become the new three"
  check "[[ '$(saved 'claude,source code,dev logs,git review')' == 'claude,source code,dev logs' ]]" \
    "renamed old four keep their names, without the old review tab"
  check "[[ '$(saved 'ai,code,srv,diff')' == 'ai,code,srv,diff' ]]" "four tabs of the user's own stay as they are"
  cleanup
}

test_one_numbered_question_shows_the_tabs_first() {
  new_home
  answer ""
  wizard 'TOOLS=,review,; ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'agents *Claude Code / Codex' '$T/out'" "shows tab 1 and what it's for"
  check "grep -q 'local server *npm run dev' '$T/out'" "shows tab 3 and what it's for"
  check "grep -q '+ git review .*always the last tab' '$T/out'" "says herdr-hunk's tab comes after them"
  check "grep -q '1) use these three' '$T/out' && grep -q '2) my own tabs, 1 to 4' '$T/out' && grep -q '3) no default tabs' '$T/out'" \
    "offers the three choices"
  check "! grep -q 'y/N' '$T/out'" "no y/N questions left"
  check "grep -qx 'RESULT=$SUGGESTED' '$T/out'" "Enter picks the suggested three"
  check "grep -qx 'TABS=$SUGGESTED' '$STATE/choices.env'" "the answer is saved"
  answer ""
  wizard 'TOOLS=,editor,; ask_default_tabs'
  check "! grep -q 'git review' '$T/out'" "no review tab promised without the review group"
  cleanup
}

test_no_default_tabs_turns_the_plugin_off_and_is_remembered() {
  new_home
  answer 3
  wizard 'ask_default_tabs; printf "RESULT=[%s]\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=\[\]' '$T/out'" "choice 3 empties DEFAULT_TABS"
  check "grep -qx 'TABS=none' '$STATE/choices.env'" "saved as none"
  : > "$T/answers"
  wizard 'printf "[%s]" "$DEFAULT_TABS"; ask_default_tabs; printf "RESULT=[%s]\n" "$DEFAULT_TABS"'
  check "grep -q '^\[\]' '$T/out'" "a later run starts with no default tabs"
  check "grep -q 'choice \[3\]' '$T/out'" "Enter now keeps 'no default tabs'"
  check "grep -qx 'RESULT=\[\]' '$T/out'" "and keeps them off"
  cleanup
}

test_my_own_tabs_takes_one_to_four_names() {
  new_home
  answer 2 " claude ,, dev logs "
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=claude,dev logs' '$T/out'" "two names, trimmed, empties dropped (got '$(grep RESULT "$T/out")')"
  check "grep -qx 'TABS=claude,dev logs' '$STATE/choices.env'" "custom tabs saved"
  answer 2 "solo"
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=solo' '$T/out'" "one tab is enough"
  answer 2 "a,b,c,d,e" "a,b,c,d"
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'at most 4' '$T/out'" "five names are refused"
  check "grep -qx 'RESULT=a,b,c,d' '$T/out'" "and asked again"
  answer ""
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'choice \[2\]' '$T/out'" "a later run defaults to 'my own tabs'"
  check "grep -q '1 agents' '$T/out'" "the list still shows the three that '1) use these three' gives"
  answer 2 ""
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q '\[a, b, c, d\]' '$T/out'" "the names question offers the saved tabs"
  check "grep -qx 'RESULT=a,b,c,d' '$T/out'" "Enter keeps them"
  answer 1
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=$SUGGESTED' '$T/out'" "choosing 1 goes back to the suggested three"
  cleanup
}

test_my_own_tabs_with_no_names_falls_back_to_the_suggested() {
  new_home
  answer 2 " , "
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'no names given' '$T/out'" "says why"
  check "grep -qx 'RESULT=$SUGGESTED' '$T/out'" "and uses the suggested three"
  cleanup
}

test_tab_names_are_never_glob_expanded() {
  new_home
  mkdir -p "$T/cwd" && touch "$T/cwd/afile"
  answer 2 "*, code"
  wizard 'cd "$T/cwd"; ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=\*,code' '$T/out'" "a tab named * stays * (got '$(grep RESULT "$T/out")')"
  cleanup
}

# ── the hook ──────────────────────────────────────────────────────────────

# review_calls: the hook's calls after it made the tabs: focus, review, focus.
review_calls() {
  grep -v '^tab create\|^tab rename\|^workspace list\|^pane list\|^plugin list' "$T/herdr.log" | tr '\n' '|'
}

test_hook_opens_just_the_users_tabs_without_hunk() {
  new_home
  fake_herdr
  run_hook "$SUGGESTED"
  check "grep -q '^tab rename w1:t1 agents' '$T/herdr.log'" "first tab renamed to agents"
  check "[[ '$(grep -c '^tab create' "$T/herdr.log")' == 2 ]]" "two more tabs created"
  check "! grep -q -- '--label git review' '$T/herdr.log'" "no git review tab"
  check "! grep -q '^plugin action' '$T/herdr.log'" "no review launched when herdr-hunk isn't installed"
  check "[[ '$(tail -n1 "$T/herdr.log")' == 'tab focus w1:t1' ]]" "lands on the first tab"
  cleanup
}

test_hook_adds_the_hunk_review_as_the_last_tab() {
  new_home
  fake_herdr hunk
  run_hook "$SUGGESTED"
  check "[[ '$(grep '^tab create' "$T/herdr.log" | tail -n1 | grep -c -- '--label git review')' == 1 ]]" \
    "the last tab created is git review"
  check "[[ '$(review_calls)' == 'tab focus w1:t4|plugin action invoke review --plugin jhochenbaum.hunkdiff|tab focus w1:t1|' ]]" \
    "default three: the review opens in tab 4, then back to tab 1 (got '$(review_calls)')"
  : > "$T/herdr.log"
  run_hook "a,b,c,d" review
  check "[[ '$(review_calls)' == 'tab focus w1:t5|plugin action invoke review --plugin jhochenbaum.hunkdiff|tab focus w1:t1|' ]]" \
    "four tabs of the user's own: the review is tab 5 (got '$(review_calls)')"
  : > "$T/herdr.log"
  run_hook "solo" review
  check "[[ '$(review_calls)' == 'tab focus w1:t2|plugin action invoke review --plugin jhochenbaum.hunkdiff|tab focus w1:t1|' ]]" \
    "one tab of their own: the review is tab 2 (got '$(review_calls)')"
  cleanup
}

test_hook_adds_no_review_tab_without_the_review_group() {
  new_home
  fake_herdr hunk
  run_hook "$SUGGESTED" editor
  check "! grep -q -- '--label git review' '$T/herdr.log' && ! grep -q '^plugin action' '$T/herdr.log'" \
    "review not selected: herdr-hunk left installed still gets no tab"
  cleanup
}

test_hook_ignores_a_duplicate_event() {
  new_home
  fake_herdr hunk
  run_hook "$SUGGESTED"
  check "[[ '$(grep -c '^tab create' "$T/herdr.log")' == 3 ]]" "the first event lays out the tabs"
  printf '4' > "$T/tabcount"
  : > "$T/herdr.log"
  run_hook "$SUGGESTED"
  check "! grep -qE '^(tab (create|rename|focus)|plugin action)' '$T/herdr.log'" \
    "a duplicate event lays out nothing (got '$(cat "$T/herdr.log")')"
  cleanup
}

run_tests "$@"
