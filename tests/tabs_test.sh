#!/usr/bin/env bash
# Tests for the default tabs: the one numbered question that picks them, and the
# herdr hook that opens them (and the hunk review in tab 4) in new workspaces.
#
#   bash tests/tabs_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

SUGGESTED="agents,source code,local server,git review"

# answer LINE...: the lines the next wizard run reads from stdin.
answer() { printf '%s\n' "$@" > "$T/answers"; }

# fake_herdr [hunk]: a herdr on PATH for the tab hook. Every call is logged to
# $T/herdr.log; the one workspace is new, on its single starting tab. With
# "hunk", the herdr-hunk plugin shows up in `plugin list`.
fake_herdr() {
  mkdir -p "$T/bin"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$T/herdr.log"
case "\$1 \$2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","active_tab_id":"w1:t1","tab_count":1}]}}' ;;
  "pane list") echo '{"result":{"panes":[{"cwd":"/tmp/repo"}]}}' ;;
  "tab create") n=\$(grep -c '^tab create' "$T/herdr.log"); echo "{\"result\":{\"tab\":{\"tab_id\":\"w1:t\$((n + 1))\"}}}" ;;
  "plugin list") echo "1 plugin installed:"; [ "${1:-}" = hunk ] && echo "- jhochenbaum.hunkdiff (hunk) enabled" ;;
esac
exit 0
EOF
  chmod +x "$T/bin/herdr"
}

# run_hook: write the plugin for DEFAULT_TABS, then fire its workspace hook the
# way herdr would: under macOS's system bash 3.2.
run_hook() {
  wizard "DEFAULT_TABS='$1'; herdr() { :; }; write_worktree_tabs_plugin"
  : > "$T/herdr.log"
  HOME="$H" HERDR_BIN_PATH="$T/bin/herdr" HERDR_WORKSPACE_ID=w1 \
    HERDR_PLUGIN_STATE_DIR="$T/state" /bin/bash "$H/.herdr/plugins/worktree-tabs/apply-tab-layout.sh" workspace
}

# ── the question ──────────────────────────────────────────────────────────

test_suggested_tabs_are_the_default() {
  new_home
  wizard 'printf "%s" "$DEFAULT_TABS"'
  check "[[ '$(cat "$T/out")' == '$SUGGESTED' ]]" "first run starts on the four suggested tabs (got '$(cat "$T/out")')"
  cleanup
}

test_one_numbered_question_shows_the_tabs_first() {
  new_home
  answer ""
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'agents *Claude Code / Codex' '$T/out'" "shows tab 1 and what it's for"
  check "grep -q 'git review *hunk-by-hunk review' '$T/out'" "shows tab 4 and what it's for"
  check "grep -q '1) use these four' '$T/out' && grep -q '3) no default tabs' '$T/out'" "offers the three choices"
  check "! grep -q 'y/N' '$T/out'" "no y/N questions left"
  check "grep -qx 'RESULT=$SUGGESTED' '$T/out'" "Enter picks the suggested four"
  check "grep -qx 'TABS=$SUGGESTED' '$STATE/choices.env'" "the answer is saved"
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

test_my_names_renames_each_of_the_four() {
  new_home
  answer 2 "claude" "" "dev, logs" ""
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -qx 'RESULT=claude,source code,dev logs,git review' '$T/out'" "Enter keeps a name, commas are dropped (got '$(grep RESULT "$T/out")')"
  check "grep -qx 'TABS=claude,source code,dev logs,git review' '$STATE/choices.env'" "custom names saved"
  answer ""
  wizard 'ask_default_tabs; printf "RESULT=%s\n" "$DEFAULT_TABS"'
  check "grep -q 'choice \[2\]' '$T/out'" "a later run defaults to 'my names'"
  check "grep -q '1 claude' '$T/out'" "and shows the saved names"
  check "grep -qx 'RESULT=claude,source code,dev logs,git review' '$T/out'" "Enter keeps the custom names"
  cleanup
}

# ── the hook ──────────────────────────────────────────────────────────────

test_hook_opens_the_four_tabs_as_plain_shells_without_hunk() {
  new_home
  fake_herdr
  run_hook "$SUGGESTED"
  check "grep -q '^tab rename w1:t1 agents' '$T/herdr.log'" "first tab renamed to agents"
  check "[[ '$(grep -c '^tab create' "$T/herdr.log")' == 3 ]]" "three more tabs created"
  check "grep -q -- '--label git review' '$T/herdr.log'" "tab 4 is git review"
  check "! grep -q '^plugin action' '$T/herdr.log'" "no review launched when herdr-hunk isn't installed"
  check "[[ '$(tail -n1 "$T/herdr.log")' == 'tab focus w1:t1' ]]" "lands on the first tab"
  cleanup
}

test_hook_launches_the_hunk_review_in_tab_4() {
  new_home
  fake_herdr hunk
  run_hook "$SUGGESTED"
  local after_tabs; after_tabs=$(grep -v '^tab create\|^tab rename\|^workspace list\|^pane list\|^plugin list' "$T/herdr.log" | tr '\n' '|')
  check "[[ '$after_tabs' == 'tab focus w1:t4|plugin action invoke review --plugin jhochenbaum.hunkdiff|tab focus w1:t1|' ]]" \
    "focus tab 4, open the review there, back to tab 1 (got '$after_tabs')"
  cleanup
}

test_hook_skips_the_review_when_there_is_no_tab_4() {
  new_home
  fake_herdr hunk
  run_hook "agents,code"
  check "! grep -q '^plugin action' '$T/herdr.log'" "fewer than four tabs: no review"
  cleanup
}

run_tests "$@"
