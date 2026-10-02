#!/usr/bin/env bash
# Tests for the prefix-key and colour-mode choices (issue 08): the prefix
# question and its trade-offs, skipping the free-the-prefix step with Ctrl-B,
# the prefix everywhere keys are documented, and the three-way theme on
# Ghostty, herdr, Neovim and yazi.
#
#   bash tests/prefix_theme_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# fake_herdr_min: the herdr calls the herdr stage makes: config check passes,
# the agent hook is current (so nothing is installed or asked), the skill
# prints, and the tab plugin is not linked.
fake_herdr_min() {
  mkdir -p "$T/bin"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$T/herdr.log"
case "\$1 \$2" in
  "config check") exit 0 ;;
  "integration status") echo "claude: current" ;;
esac
[ "\$1" = --skill ] && printf '# herdr skill (fake)\n'
exit 0
EOF
  chmod +x "$T/bin/herdr"
  PATH="$T/bin:$PATH"
}

# herdr_run: the herdr stage alone, leaving output in $T/out and the journal
# in the state dir.
herdr_run() {
  printf '\n\n\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only herdr > "$T/out" 2>&1 || true
}

# ── the prefix question ───────────────────────────────────────────────────

test_prefix_states_both_options_and_defaults_to_ctrl_space() {
  new_home
  # banner, accept the tools, prefix/theme/prompt defaults, projects folder,
  # create it, suggested tabs.
  printf '\n\n\n\n\n%s\ny\n\n' "$H/repos" > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices > "$T/out" 2>&1
  check "grep -q 'herdr prefix key' '$T/out'" "the prefix is a question"
  check "grep -q 'keeps Ctrl-B free' '$T/out'" "Ctrl-Space's side is stated"
  check "grep -q 'no macOS changes' '$T/out'" "Ctrl-B's side is stated"
  check "grep -q 'clashes with' '$T/out'" "the clash is stated"
  check "grep -qx 'PREFIX=ctrl-space' '$STATE/choices.env'" "Enter defaults to Ctrl-Space"
  cleanup
}

test_answering_ctrl_b_saves_it() {
  new_home
  printf '\n\n2\n\n\n%s\n' "$H/repos" > "$T/answers"
  printf 'y\n\n' >> "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices > "$T/out" 2>&1
  check "grep -qx 'PREFIX=ctrl-b' '$STATE/choices.env'" "choice 2 saves Ctrl-B"
  cleanup
}

# ── skipping the free-the-prefix step ─────────────────────────────────────

test_ctrl_b_never_runs_the_free_the_prefix_step() {
  new_home
  fake_brew
  fake_herdr_min
  mkdir -p "$STATE"
  printf 'PREFIX=ctrl-b\n' > "$STATE/choices.env"
  herdr_run
  check "! grep -q 'macOS uses that key' '$T/out'" "no free-the-prefix step ran"
  check "! grep -q 'Input Sources' '$STATE/journal.tsv' 2>/dev/null" \
    "no prefix MANUAL entry journaled"
  cleanup
}

test_ctrl_space_still_frees_the_prefix() {
  new_home
  fake_brew
  fake_herdr_min
  herdr_run
  check "grep -q 'macOS uses that key' '$T/out'" "the default still runs the step"
  cleanup
}

test_the_plan_omits_freeing_with_ctrl_b() {
  new_home
  fake_brew
  mkdir -p "$STATE"
  printf 'PREFIX=ctrl-b\n' > "$STATE/choices.env"
  wizard 'show_plan'
  check "! grep -q 'free ctrl+space' '$T/out'" "no free-the-prefix stop with Ctrl-B"
  cleanup
  new_home
  fake_brew
  wizard 'show_plan'
  check "grep -q 'free ctrl+space' '$T/out'" "the stop is listed by default (PlistBuddy missing reads as taken)"
  cleanup
}

# ── the prefix everywhere keys are documented ─────────────────────────────

test_chosen_prefix_is_in_the_config_cheatsheet_and_tour() {
  new_home
  wizard 'PREFIX=ctrl-b; herdr_config'
  check "grep -qx 'prefix = \"ctrl+b\"' '$T/out'" "herdr config uses Ctrl-B"
  wizard 'PREFIX=ctrl-b; ghostty_config'
  check "grep -q 'text:\\\\x02' '$T/out'" "Ghostty sends Ctrl-B's byte"
  check "! grep -q 'x00' '$T/out'" "no Ctrl-Space byte left"
  wizard 'PREFIX=ctrl-b; cheatsheet'
  check "grep -q 'prefix.. = Ctrl-B' '$T/out'" "cheat sheet names Ctrl-B"
  wizard 'PREFIX=ctrl-b; HERDR_ENV= tour_launch'
  check "grep -q 'Press Ctrl-B c' '$T/out'" "tour names Ctrl-B for a new tab"
  wizard 'PREFIX=ctrl-b; HERDR_ENV=1 tour_launch'
  check "grep -q '(Ctrl-B, then Shift-T)' '$T/out'" "tour names Ctrl-B for naming a tab"
  check "! grep -q 'Ctrl-Space' '$T/out'" "tour never says Ctrl-Space with Ctrl-B"
  cleanup
  new_home
  wizard 'herdr_config; ghostty_config; cheatsheet'
  check "grep -qx 'prefix = \"ctrl+space\"' '$T/out'" "default herdr config is Ctrl-Space"
  check "grep -q 'text:\\\\x00' '$T/out'" "default Ghostty sends Ctrl-Space's byte"
  check "grep -q 'prefix.. = Ctrl-Space' '$T/out'" "default cheat sheet names Ctrl-Space"
  cleanup
}

# ── colour mode ───────────────────────────────────────────────────────────

test_theme_is_a_three_way_question_defaulting_to_system() {
  new_home
  printf '\n\n\n\n\n%s\n' "$H/repos" > "$T/answers"
  printf 'y\n\n' >> "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices > "$T/out" 2>&1
  check "grep -q 'Colour mode' '$T/out'" "colour is a question"
  check "grep -q 'follow the system appearance' '$T/out'" "following is offered"
  check "grep -q 'always dark' '$T/out'" "fixed dark is offered"
  check "grep -q 'leave my themes alone' '$T/out'" "leaving alone is offered"
  check "grep -qx 'THEME=system' '$STATE/choices.env'" "Enter defaults to following the system"
  check "grep -q 'may need a restart to repaint' '$T/out'" "the editor-repaint caveat is printed"
  cleanup
}

test_system_theme_is_on_all_four_surfaces() {
  new_home
  wizard 'THEME=system; ghostty_config'
  check "grep -qx 'theme = light:Catppuccin Latte,dark:Catppuccin Mocha' '$T/out'" \
    "Ghostty follows macOS"
  wizard 'THEME=system; herdr_config'
  check "grep -qx 'auto_switch = true' '$T/out'" "herdr follows macOS"
  wizard 'THEME=system; nvim_colorscheme'
  check "grep -q 'system_appearance' '$T/out'" "Neovim reads the system appearance"
  check "grep -q 'light = \"latte\", dark = \"mocha\"' '$T/out'" "Neovim maps background to flavours"
  wizard 'THEME=system; yazi_theme'
  check "grep -qx 'light = \"catppuccin-latte\"' '$T/out'" "yazi's light flavour is light"
  check "grep -qx 'dark = \"catppuccin-mocha\"' '$T/out'" "yazi's dark flavour is dark"
  cleanup
}

test_dark_pins_all_four_surfaces() {
  new_home
  wizard 'THEME=dark; ghostty_config'
  check "grep -qx 'theme = Catppuccin Mocha' '$T/out'" "Ghostty pins Mocha"
  check "! grep -q 'light:' '$T/out'" "no system qualifier"
  wizard 'THEME=dark; herdr_config'
  check "grep -qx 'auto_switch = false' '$T/out'" "herdr stays dark"
  wizard 'THEME=dark; nvim_colorscheme'
  check "grep -q 'catppuccin-mocha' '$T/out'" "Neovim pins Mocha"
  check "! grep -q 'system_appearance' '$T/out'" "no appearance watching"
  wizard 'THEME=dark; yazi_theme'
  check "grep -qx 'light = \"catppuccin-mocha\"' '$T/out'" "yazi pins dark in both flavours"
  cleanup
}

test_leave_writes_no_theme_setting() {
  new_home
  wizard 'THEME=leave; ghostty_config'
  check "! grep -q 'theme' '$T/out'" "Ghostty gets no theme line"
  wizard 'THEME=leave; herdr_config'
  check "! grep -q '\\[theme\\]' '$T/out'" "herdr gets no theme section"
  check "grep -qx 'prefix = \"ctrl+space\"' '$T/out'" "the rest of the config is intact"
  wizard 'THEME=leave; nvim_colorscheme'
  check "[[ ! -s '$T/out' ]]" "no Neovim colourscheme"
  wizard 'THEME=leave; yazi_theme'
  check "[[ ! -s '$T/out' ]]" "no yazi theme (glyphs on: nothing to say)"
  wizard 'THEME=leave; stage_targets yazi'
  check "[[ ! -s '$T/out' ]]" "no yazi target, so no badge and no plan entry"
  cleanup
}

test_badges_follow_the_theme_choice() {
  new_home
  mkdir -p "$H/.config/nvim/lua/config" "$H/.config/nvim/lua/plugins"
  printf 'return { { "LazyVim/LazyVim", import = "lazyvim.plugins" } }\n' > "$H/.config/nvim/lua/config/lazy.lua"
  wizard 'THEME=leave; stage_targets editor'
  check "! grep -q 'colorscheme' '$T/out'" "leave: no colourscheme target"
  check "grep -q 'icons.lua' '$T/out'" "leave: icon and plugin targets stay"
  wizard 'THEME=dark; stage_targets editor'
  check "grep -q 'colorscheme.lua' '$T/out'" "dark: the colourscheme target is back"
  cleanup
}

# ── persistence ───────────────────────────────────────────────────────────

test_both_choices_are_recorded_and_survive_a_rerun() {
  new_home
  printf '\n\n2\n3\n\n%s\n' "$H/repos" > "$T/answers"
  printf 'y\n\n' >> "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices > /dev/null 2>&1
  check "grep -qx 'PREFIX=ctrl-b' '$STATE/choices.env'" "prefix saved"
  check "grep -qx 'THEME=leave' '$STATE/choices.env'" "theme saved"
  wizard 'printf "%s|%s" "$PREFIX" "$THEME"'
  check "[[ '$(cat "$T/out")' == 'ctrl-b|leave' ]]" "a later run reads them back (got '$(cat "$T/out")')"
  cleanup
  new_home
  mkdir -p "$STATE"
  printf 'PREFIX=bogus\nTHEME=bogus\n' > "$STATE/choices.env"
  wizard 'printf "%s|%s" "$PREFIX" "$THEME"'
  check "[[ '$(cat "$T/out")' == 'ctrl-space|system' ]]" "bad values fall back to the defaults"
  cleanup
}

run_tests "$@"
