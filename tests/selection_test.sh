#!/usr/bin/env bash
# Tests for the tool selection screen: Ghostty, herdr and terminal-notifier are
# always installed; everything else is a checkbox per group of tools that
# depend on each other, and a declined group skips its install and its stage.
#
#   bash tests/selection_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# choices_run LINE...: run the choices stage alone, answering with these lines
# (the first is the opening banner's Enter).
choices_run() {
  printf '%s\n' "$@" > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
}

# RECOMMENDED: every group but icons, the default when never chosen.
RECOMMENDED=prompt,jumper,typing,editor,review,files,github,statusline

# saved_tools: the TOOLS line of choices.env.
saved_tools() { grep '^TOOLS=' "$STATE/choices.env" | cut -d= -f2-; }

# ── tests ─────────────────────────────────────────────────────────────────

test_everything_is_ticked_by_default() {
  new_home
  # banner, Enter on the selection screen, colours, prompt, projects folder, create it, suggested tabs
  choices_run '' '' '' '' "$H/repos" y ''
  check "grep -q 'Ghostty, herdr and terminal-notifier' '$T/out'" "the mandatory three are named"
  check "[[ '$(saved_tools)' == $RECOMMENDED ]]" \
    "Enter keeps the recommended set (got '$(saved_tools)')"
  check "grep -qx 'GLYPHS=on' '$STATE/choices.env'" "icons are on by default"
  cleanup
}

test_each_tool_in_a_group_is_explained() {
  new_home
  choices_run '' '' '' '' "$H/repos" y ''
  local tool
  for tool in starship fzf fd eza bat zsh-autosuggestions zsh-syntax-highlighting \
    neovim tree-sitter-cli ripgrep LazyVim lazygit yazi poppler resvg gh gh-dash; do
    check "grep -qE '^ +$tool +[a-zA-Z]' '$T/out'" "$tool is listed with what it gives you"
  done
  cleanup
}

test_numbers_untick_and_tick_groups() {
  new_home
  # untick icons, yazi and GitHub, then tick GitHub again; colours, prompt, folder, create it, tabs
  choices_run '' '1 7 8' 8 '' '' '' "$H/repos" y ''
  check "[[ '$(saved_tools)' == 'prompt,jumper,typing,editor,review,github,statusline' ]]" \
    "unticked groups are left out (got '$(saved_tools)')"
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "unticking icons is the plain-text switch"
  check "grep -q '\[ \] file manager' '$T/out'" "the screen redraws with the group unticked"
  cleanup
}

test_a_leading_zero_is_still_a_group_number() {
  new_home
  # 08 unticks GitHub (not a bad octal number); 0 and 42 are ignored
  choices_run '' '08 0 42' '' '' '' "$H/repos" y ''
  check "[[ '$(saved_tools)' == 'prompt,jumper,typing,editor,review,files,statusline' ]]" \
    "08 is group 8 (got '$(saved_tools)')"
  check "! grep -q 'value too great' '$T/out'" "no arithmetic error"
  cleanup
}

test_nothing_selected_is_saved_as_none() {
  new_home
  # no prompt or project jumper, so only the colours and tabs questions
  choices_run '' '2 3 4 5 6 7 8 9' '' '' ''
  check "[[ '$(saved_tools)' == none ]]" "no groups is saved as none (got '$(saved_tools)')"
  check "! grep -q 'Projects folder' '$T/out'" "without the project jumper there is no folder to ask about"
  cleanup
}

# formulae [TOOLS]: what the install stage would brew, space-separated, with
# the TOOLS choice saved as given (unset: never chosen).
formulae() {
  mkdir -p "$STATE"
  : > "$STATE/choices.env"
  [[ $# == 0 ]] || printf 'TOOLS=%s\n' "$1" > "$STATE/choices.env"
  wizard 'install_formulae'
  tr '\n' ' ' < "$T/out"
}

test_install_brews_only_the_selected_groups() {
  new_home
  check "[[ '$(formulae none)' == 'herdr terminal-notifier ' ]]" \
    "nothing selected: just the mandatory formulae (got '$(formulae none)')"
  check "[[ '$(formulae files,github)' == 'herdr terminal-notifier yazi poppler resvg gh ' ]]" \
    "a group's formulae come with it (got '$(formulae files,github)')"
  check "[[ '$(formulae typing)' == 'herdr terminal-notifier zsh-autosuggestions zsh-syntax-highlighting ' ]]" \
    "one of the two shell groups brings only its own tools (got '$(formulae typing)')"
  check "[[ '$(formulae statusline)' == 'herdr terminal-notifier jq ' ]]" "jq comes silently with the status line"
  cleanup
}

test_fd_is_brewed_once_when_two_groups_need_it() {
  new_home
  check "[[ '$(formulae jumper,editor)' == 'herdr terminal-notifier fzf fd eza bat neovim tree-sitter-cli ripgrep ' ]]" \
    "fd is listed once (got '$(formulae jumper,editor)')"
  cleanup
}

test_cut_tools_are_never_installed() {
  new_home
  local all
  all=$(formulae)
  check "[[ '$all' == 'herdr terminal-notifier starship fzf fd eza bat zsh-autosuggestions zsh-syntax-highlighting neovim tree-sitter-cli ripgrep lazygit yazi poppler resvg gh jq ' ]]" \
    "the recommended set, and nothing else (got '$all')"
  check "! grep -qE 'git-delta|difftastic|zoxide|btop|glow|jless|tlrc' '$WIZARD'" \
    "the script never mentions the seven cut tools"
  cleanup
}

# with_tools TOOLS CODE: run CODE in the wizard with TOOLS as the saved choice.
with_tools() {
  mkdir -p "$STATE"
  printf 'TOOLS=%s\n' "$1" > "$STATE/choices.env"
  wizard "$2"
}

test_shell_block_holds_only_what_was_selected() {
  new_home
  with_tools typing 'zshrc_block'
  check "grep -q zsh-autosuggestions '$T/out' && grep -q zsh-syntax-highlighting '$T/out'" "typing help is sourced"
  check "! grep -qE 'fzf|eza|bat |hproj|starship|nvim|lazygit|yazi' '$T/out'" "no line for a declined tool"
  check "grep -q 'ghostty-integration' '$T/out' && grep -q 'HISTSIZE' '$T/out'" "shell integration and history stay"
  check "grep -q \"alias keys='less\" '$T/out'" "keys falls back to less without bat"
  with_tools prompt,jumper,editor,review,files 'zshrc_block'
  check "grep -q 'starship init' '$T/out' && grep -q 'fzf --zsh' '$T/out' && grep -q 'eza' '$T/out'" \
    "prompt and jumper lines are there"
  check "grep -q \"alias v='nvim'\" '$T/out' && grep -q \"alias lg='lazygit'\" '$T/out' && grep -q '^y()' '$T/out'" \
    "editor, review and file manager shortcuts are there"
  check "grep -q '^p()' '$T/out' && grep -q \"alias keys='bat\" '$T/out'" "p, and keys through bat"
  check "! grep -q zsh-autosuggestions '$T/out'" "declined typing help is not sourced"
  cleanup
}

test_zprofile_sets_editor_and_projects_only_when_selected() {
  new_home
  ( # subshell: the fake brew and bat on PATH never outlive this test
    fake_brew
    fake_bat
    mkdir -p "$STATE"
    printf 'TOOLS=typing\n' > "$STATE/choices.env"
    cli --only shell
    check "! grep -qE 'EDITOR|PROJECTS_DIR|BAT_THEME' '$H/.zprofile'" "no editor, projects folder or bat theme"
    check "[[ ! -e '$H/.local/bin/hproj' ]]" "no project picker"
    check "grep -q 'local/bin' '$H/.zprofile'" "PATH still gets ~/.local/bin"
    printf 'TOOLS=jumper,editor\nPROJECTS_DIR=%s\n' "$H/repos" > "$STATE/choices.env"
    cli --only shell
    check "grep -q 'EDITOR=nvim' '$H/.zprofile' && grep -q 'PROJECTS_DIR=' '$H/.zprofile' && grep -q BAT_THEME '$H/.zprofile'" \
      "all three with the editor and the jumper"
    check "[[ -x '$H/.local/bin/hproj' ]]" "and the project picker"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

# popup_keys: the keys of the herdr config's popups in $T/out, space-separated.
popup_keys() { grep -A1 '^\[\[keys.command\]\]' "$T/out" | sed -n 's/^key = "\(.*\)"/\1/p' | tr '\n' ' '; }

test_herdr_popups_only_open_selected_tools() {
  new_home
  with_tools none 'herdr_config'
  check "[[ -z '$(popup_keys)' ]]" "nothing selected: no popup keys that open nothing (got '$(popup_keys)')"
  with_tools jumper,review,files,github 'herdr_config'
  check "[[ '$(popup_keys)' == 'prefix+m prefix+d prefix+f prefix+i ' ]]" \
    "projects, lazygit, yazi and gh-dash each get their key (got '$(popup_keys)')"
  with_tools files 'herdr_config'
  check "[[ '$(popup_keys)' == 'prefix+f ' ]]" "only the selected ones (got '$(popup_keys)')"
  check "! grep -q 'prefix+t' '$T/out'" "the btop popup is gone"
  check "grep -q '^\[ui\]' '$T/out'" "the rest of the config follows"
  cleanup
}

test_stage_count_follows_the_selection() {
  new_home
  with_tools none 'printf "%s" "$TOTAL_STAGES"'
  check "[[ '$(cat "$T/out")' == 7 ]]" \
    "nothing selected: the 5 fixed stages, shell and the tour (got '$(cat "$T/out")')"
  with_tools jumper,typing,prompt 'printf "%s" "$TOTAL_STAGES"'
  check "[[ '$(cat "$T/out")' == 8 ]]" "both shell groups share the shell stage (got '$(cat "$T/out")')"
  with_tools "$RECOMMENDED" 'printf "%s" "$TOTAL_STAGES"'
  check "[[ '$(cat "$T/out")' == 13 ]]" "everything selected: all 13 (got '$(cat "$T/out")')"
  cleanup
}

test_a_declined_groups_stage_does_not_run() {
  new_home
  ( # subshell: the fake brew on PATH never outlives this test
    fake_brew
    mkdir -p "$STATE"
    printf 'TOOLS=github\n' > "$STATE/choices.env"
    cli --only yazi
    check "grep -q 'yazi: not selected' '$T/out'" "--only on a declined stage says why nothing ran"
    check "! grep -q 'Stage' '$T/out'" "and runs no stage"
    check "! grep -q install '$T/brew.log'" "and installs nothing"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

test_review_leaves_gitconfig_alone() {
  new_home
  ( # subshell: the fakes on PATH never outlive this test
    fake_brew
    printf '#!/bin/sh\necho "%s/lazygit"\n' "$T" > "$T/bin/lazygit"
    chmod +x "$T/bin/lazygit"
    cli --only review
    check "[[ ! -e '$H/.gitconfig' ]]" "no git settings are written"
    check "! grep -q GITKEY '$STATE/journal.tsv'" "so none are journaled"
    check "[[ -f '$T/lazygit/config.yml' ]]" "lazygit's config is still written"
    check "! grep -qE 'delta|difft' '$T/lazygit/config.yml'" "with no diff renderers for the cut tools"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

# The status line is ticked on the selection screen, so its stage asks nothing.
test_selected_status_line_is_set_up_without_asking_again() {
  new_home
  ( # subshell: the fakes on PATH never outlive this test
    fake_brew
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/claude"
    chmod +x "$T/bin/claude"
    cli --only statusline
    check "! grep -q 'Set up this status line' '$T/out'" "no second question"
    check "[[ -x '$H/.claude/statusline.sh' ]]" "the script is written"
    check "grep -q statusline.sh '$H/.claude/settings.json'" "and wired into Claude Code's settings"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

test_ghostty_cmd_keys_only_open_selected_popups() {
  new_home
  with_tools none 'ghostty_config'
  check "! grep -qE 'cmd\+(o|e|shift\+g)=' '$T/out'" "nothing selected: no Cmd key for a missing popup"
  check "grep -q 'cmd+d=text' '$T/out'" "herdr's own keys stay"
  with_tools jumper,files,review 'ghostty_config'
  check "grep -q 'cmd+o=text:.x00m' '$T/out' && grep -q 'cmd+e=text:.x00f' '$T/out' && grep -q 'cmd+shift+g=text:.x00d' '$T/out'" \
    "Cmd-O, Cmd-E and Cmd-Shift-G come with the jumper, file manager and review"
  cleanup
}

# Other groups (starship, the editor, lazygit, yazi) also put lines in the
# shell block, and Ghostty integration and history belong to every setup.
test_shell_stage_runs_without_either_shell_group() {
  new_home
  ( # subshell: the fake brew on PATH never outlives this test
    fake_brew
    mkdir -p "$STATE"
    printf 'TOOLS=prompt,editor\n' > "$STATE/choices.env"
    cli --only shell
    check "grep -q 'starship init' '$H/.zshrc' && grep -q \"alias v='nvim'\" '$H/.zshrc'" \
      "starship and the editor alias are written"
    check "grep -q 'EDITOR=nvim' '$H/.zprofile'" "and EDITOR"
    check "grep -q 'ghostty-integration' '$H/.zshrc'" "with Ghostty's shell integration"
    check "[[ -f '$H/.config/ghostty-herdr-cheatsheet.md' ]]" "and the cheat sheet keys opens"
    check "! grep -q '^install' '$T/brew.log'" "without installing either shell group's tools"
    printf '%s %s\n' "$PASSES" "$FAILS" > "$T/tally"
  )
  read -r PASSES FAILS < "$T/tally"
  cleanup
}

test_cheat_sheet_lists_only_selected_tools() {
  new_home
  with_tools none 'cheatsheet'
  check "! grep -qE 'Popups|lazygit|yazi|gh dash|LazyVim|Cmd-O|fuzzy|\{' '$T/out'" \
    "nothing selected: no shortcut for a missing tool, and no tags left"
  check "grep -q '## Workspaces and agents' '$T/out' && grep -q '| \`gd\` | git diff |' '$T/out'" \
    "herdr's own keys and plain git stay"
  with_tools files,editor 'cheatsheet'
  check "grep -q '## Popups' '$T/out' && grep -q 'prefix \`f\` · Cmd-E' '$T/out' && grep -q '## Neovim' '$T/out'" \
    "a selected tool's rows and sections are there"
  check "! grep -qE 'prefix \`d\`|prefix \`i\`|## lazygit' '$T/out'" "the declined ones' are not"
  check "[[ '$(grep -c '^$' "$T/out")' -gt 10 ]] && ! grep -q '^ ' '$T/out'" "blank lines survive, untagged"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
