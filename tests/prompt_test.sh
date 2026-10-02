#!/usr/bin/env bash
# Tests for the prompt style choice (issue 07): two hand-written configs with
# only directory and git branch, live previews before the choice, a leave-alone
# third option, and plain-only when glyphs are off.
#
#   bash tests/prompt_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# fake_starship_preview: a starship that marks every live preview render, so
# the test can tell the previews ran before the choice was asked.
fake_starship_preview() {
  mkdir -p "$T/bin"
  printf '#!/bin/sh\necho "LIVE-PREVIEW rendered"\nexit 0\n' > "$T/bin/starship"
  chmod +x "$T/bin/starship"
  PATH="$T/bin:$PATH"
}

# ── tests ─────────────────────────────────────────────────────────────────

test_prompt_style_defaults_to_pure() {
  new_home
  wizard 'printf "%s" "$PROMPT_STYLE"'
  check "[[ '$(cat "$T/out")' == pure ]]" "PROMPT_STYLE defaults to pure (got '$(cat "$T/out")')"
  wizard 'PROMPT_STYLE=bogus; printf "%s" "$PROMPT_STYLE"'
  check "[[ '$(cat "$T/out")' == bogus ]]" "assignment still works for the test harness"
  cleanup
}

test_prompt_configs_show_only_directory_and_branch() {
  new_home
  local style sections
  for style in pure tokyo; do
    wizard "PROMPT_STYLE=$style; prompt_config"
    sections=$(grep -o '^\[[a-z_]*\]' "$T/out" | tr '\n' ' ')
    check "[[ '$sections' == '[directory] [git_branch] [character] ' ]]" \
      "$style: only directory, git_branch and character (got '$sections')"
    check "! grep -qE 'username|hostname|nodejs|python|deno|bun|time' '$T/out'" \
      "$style: no runtime, user, host or time modules"
  done
  check "! grep -q 'starship preset' '$WIZARD'" \
    "the wizard no longer depends on upstream preset internals"
  cleanup
}

test_prompt_choice_previews_both_live_before_asking() {
  new_home
  fake_brew
  fake_starship_preview
  printf '1\n' > "$T/answers"
  wizard 'ask_prompt_style'
  check "[[ '$(grep -c LIVE-PREVIEW "$T/out")' == 2 ]]" \
    "both styles previewed live (got '$(grep -c LIVE-PREVIEW "$T/out")')"
  check "grep -q 'choice \[1\]' '$T/out'" "then the choice is asked"
  check "awk '/LIVE-PREVIEW/{m=NR} /choice \[1\]/{c=NR} END{exit !(m && c && m<c)}' '$T/out'" \
    "previews come before the choice, not after installation"
  check "grep -qx 'PROMPT_STYLE=pure' '$STATE/choices.env'" "choice 1 saves pure"
  cleanup
}

test_glyphs_off_offers_only_plain() {
  new_home
  fake_brew
  fake_starship_preview
  printf '2\n' > "$T/answers"
  wizard 'GLYPHS=off; ask_prompt_style'
  check "! grep -qi 'tokyo' '$T/out'" "no powerline style without glyphs"
  check "grep -qx 'PROMPT_STYLE=leave' '$STATE/choices.env'" "choice 2 leaves the prompt alone"
  cleanup
}

test_leave_writes_nothing() {
  new_home
  mkdir -p "$STATE"
  printf 'TOOLS=prompt\nPROMPT_STYLE=leave\n' > "$STATE/choices.env"
  wizard 'JOURNALING=1; stage_prompt'
  check "[[ ! -e '$H/.config/starship.toml' ]]" "no prompt config written"
  check "[[ ! -f '$STATE/journal.tsv' ]] || ! grep -q 'starship' '$STATE/journal.tsv'" \
    "nothing journaled"
  wizard 'zshrc_block'
  check "! grep -q 'starship init' '$T/out'" "the shell does not initialise a prompt left alone"
  cleanup
}

test_chosen_prompt_is_journaled() {
  new_home
  fake_brew
  fake_starship_preview
  wizard 'JOURNALING=1; PROMPT_STYLE=pure; stage_prompt'
  check "grep -q 'CREATE.*starship.toml' '$STATE/journal.tsv'" "the chosen config is journaled"
  wizard 'PROMPT_STYLE=pure; prompt_config'
  cp "$T/out" "$T/expected"
  same_bytes "$H/.config/starship.toml" "$T/expected" "the written file is the chosen config"
  cleanup
}

test_prompt_style_is_required_when_prompt_is_selected() {
  new_home
  mkdir -p "$STATE"
  printf 'GLYPHS=on\nTOOLS=prompt\nTABS=none\n' > "$STATE/choices.env"
  wizard 'choices_saved && echo saved || echo incomplete'
  check "grep -qx incomplete '$T/out'" "a saved prompt group without a style is incomplete"
  printf 'PROMPT_STYLE=pure\n' >> "$STATE/choices.env"
  wizard 'choices_saved && echo saved || echo incomplete'
  check "grep -qx saved '$T/out'" "complete once the style is saved"
  cleanup
}

run_tests "$@"
