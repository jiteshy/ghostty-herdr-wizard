#!/usr/bin/env bash
# Tests for the colours question (follow macOS light/dark, always dark, or leave
# themes alone) and the prompt question (two hand-written minimal starship
# configs, previewed before the choice).
#
#   bash tests/theme_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# has_nerd_glyph FILE: true if FILE contains a Nerd Font glyph (Unicode's
# Private Use Areas).
has_nerd_glyph() {
  perl -CSD -ne '$found = 1 if /[\x{E000}-\x{F8FF}\x{F0000}-\x{10FFFF}]/; END { exit !$found }' "$1"
}

# answer LINE...: the lines the next wizard run reads from stdin.
answer() { printf '%s\n' "$@" > "$T/answers"; }

# git_repo DIR: a repo on branch "main" with one commit, for prompt previews.
git_repo() {
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# ── the colours question ──────────────────────────────────────────────────

test_theme_follows_macos_when_never_chosen() {
  new_home
  wizard 'printf "%s" "$THEME"'
  check "[[ '$(cat "$T/out")' == auto ]]" "THEME defaults to auto (got '$(cat "$T/out")')"
  cleanup
}

test_one_numbered_question_picks_the_theme() {
  new_home
  answer ""
  wizard 'ask_theme; printf "RESULT=%s\n" "$THEME"'
  check "grep -q '1) follow macOS light/dark' '$T/out'" "offers following macOS"
  check "grep -q '2) always dark' '$T/out'" "offers always dark"
  check "grep -q '3) leave my themes alone' '$T/out'" "offers leaving themes alone"
  check "grep -qx 'RESULT=auto' '$T/out'" "Enter follows macOS"
  check "grep -qx 'THEME=auto' '$STATE/choices.env'" "the answer is saved"
  check "grep -q 'Neovim' '$T/out' && grep -q 'restart' '$T/out'" "warns an open Neovim may need a restart"
  answer 2
  wizard 'ask_theme; printf "RESULT=%s\n" "$THEME"'
  check "grep -qx 'THEME=dark' '$STATE/choices.env'" "2 saves always dark"
  : > "$T/answers"
  wizard 'ask_theme; printf "RESULT=%s\n" "$THEME"'
  check "grep -q 'choice \[2\]' '$T/out'" "a re-run offers the saved answer"
  check "grep -qx 'RESULT=dark' '$T/out'" "and Enter keeps it"
  answer 3
  wizard 'ask_theme'
  check "grep -qx 'THEME=none' '$STATE/choices.env'" "3 saves none"
  cleanup
}

# ── every themed config follows it ────────────────────────────────────────

test_ghostty_theme_follows_the_choice() {
  new_home
  wizard 'THEME=auto; ghostty_config'
  check "grep -qx 'theme = light:Catppuccin Latte,dark:Catppuccin Mocha' '$T/out'" "auto: Ghostty switches with macOS"
  wizard 'THEME=dark; ghostty_config'
  check "grep -qx 'theme = Catppuccin Mocha' '$T/out'" "dark: Ghostty is always Mocha"
  wizard 'THEME=none; ghostty_config'
  check "! grep -q '^theme' '$T/out'" "none: Ghostty gets no theme line"
  check "grep -q '^font-size' '$T/out'" "none: the rest of the config is still there"
  cleanup
}

test_herdr_theme_follows_the_choice() {
  new_home
  wizard 'THEME=auto; herdr_config'
  check "grep -qx 'auto_switch = true' '$T/out'" "auto: herdr follows the terminal"
  check "grep -qx 'dark_name = \"catppuccin\"' '$T/out' && grep -qx 'light_name = \"catppuccin-latte\"' '$T/out'" \
    "auto: Mocha when dark, Latte when light"
  wizard 'THEME=dark; herdr_config'
  check "grep -qx 'name = \"catppuccin\"' '$T/out' && grep -qx 'auto_switch = false' '$T/out'" "dark: herdr is always Mocha"
  wizard 'THEME=none; herdr_config'
  check "! grep -q '^\[theme\]' '$T/out'" "none: herdr keeps its own theme"
  check "grep -q '^\[keys\]' '$T/out'" "none: the rest of the config is still there"
  cleanup
}

test_bat_theme_follows_the_choice() {
  new_home
  wizard 'THEME=auto; zprofile_block "$HOME/repos"'
  check "grep -qx 'export BAT_THEME=\"auto:system\"' '$T/out'" "auto: bat asks macOS"
  check "grep -qx 'export BAT_THEME_DARK=\"Catppuccin Mocha\"' '$T/out'" "auto: Mocha when dark"
  check "grep -qx 'export BAT_THEME_LIGHT=\"Catppuccin Latte\"' '$T/out'" "auto: Latte when light"
  wizard 'THEME=dark; zprofile_block "$HOME/repos"'
  check "grep -qx 'export BAT_THEME=\"Catppuccin Mocha\"' '$T/out'" "dark: bat is always Mocha"
  check "! grep -q 'BAT_THEME_' '$T/out'" "dark: no light/dark pair"
  wizard 'THEME=none; zprofile_block "$HOME/repos"'
  check "! grep -q 'BAT_THEME' '$T/out'" "none: bat keeps its own theme"
  check "grep -q 'PROJECTS_DIR' '$T/out'" "none: the rest of the block is still there"
  cleanup
}

test_yazi_theme_follows_the_choice() {
  new_home
  wizard 'THEME=auto; yazi_theme'
  check "grep -qx 'dark = \"catppuccin-mocha\"' '$T/out' && grep -qx 'light = \"catppuccin-latte\"' '$T/out'" \
    "auto: yazi uses Latte in light mode (it used to be Mocha in both)"
  wizard 'THEME=dark; yazi_theme'
  check "grep -qx 'light = \"catppuccin-mocha\"' '$T/out'" "dark: Mocha in light mode too"
  wizard 'THEME=none; GLYPHS=on; yazi_theme'
  check "[[ ! -s '$T/out' ]]" "none, icons on: nothing to write"
  wizard 'THEME=none; GLYPHS=off; yazi_theme'
  check "! grep -q '^\[flavor\]' '$T/out' && grep -q '^\[icon\]' '$T/out'" "none, icons off: plain text but no flavour"
  cleanup
}

test_neovim_colorscheme_follows_the_choice() {
  new_home
  wizard 'THEME=auto; nvim_colorscheme'
  check "grep -q 'flavour = \"auto\"' '$T/out'" "auto: catppuccin.nvim picks its flavour"
  check "grep -q 'light = \"latte\"' '$T/out' && grep -q 'dark = \"mocha\"' '$T/out'" "auto: Latte in light, Mocha in dark"
  check "grep -q 'colorscheme = \"catppuccin\"' '$T/out'" "auto: LazyVim uses the switching colorscheme"
  if command -v nvim >/dev/null 2>&1; then
    cp "$T/out" "$T/colorscheme.lua"
    check "nvim -l '$T/colorscheme.lua' >/dev/null 2>&1" "auto: the Neovim file is valid Lua"
  fi
  wizard 'THEME=dark; nvim_colorscheme'
  check "grep -q 'colorscheme = \"catppuccin-mocha\"' '$T/out'" "dark: always Mocha"
  wizard 'THEME=none; nvim_colorscheme'
  check "[[ ! -s '$T/out' ]]" "none: no colorscheme file"
  cleanup
}

# ── the prompt question ───────────────────────────────────────────────────

test_pure_is_the_default_prompt() {
  new_home
  wizard 'printf "%s" "$(prompt_style)"'
  check "[[ '$(cat "$T/out")' == pure ]]" "PROMPT defaults to pure (got '$(cat "$T/out")')"
  cleanup
}

test_both_configs_hold_only_the_folder_and_the_git_branch() {
  new_home
  local style modules
  for style in pure tokyo; do
    wizard "GLYPHS=on; starship_config $style"
    modules=$(grep -E '^\[[a-z_.]+\]$' "$T/out" | tr -d '[]' | sort | tr '\n' ' ')
    check "[[ '$modules' == 'character directory git_branch ' || '$modules' == 'directory git_branch ' ]]" \
      "$style: only directory and git_branch (got '$modules')"
    check "(( $(grep -c . "$T/out") <= 25 ))" "$style: a short hand-written config ($(grep -c . "$T/out") lines)"
  done
  wizard 'GLYPHS=on; starship_config pure'
  check "! has_nerd_glyph '$T/out'" "pure: no Nerd Font glyphs, so it works in any font"
  wizard 'GLYPHS=on; starship_config tokyo'
  check "has_nerd_glyph '$T/out'" "tokyo night: powerline segments and icons"
  cleanup
}

test_both_prompts_render_the_folder_and_branch() {
  if ! command -v starship >/dev/null 2>&1; then printf '  skipped: needs starship\n'; return 0; fi
  new_home
  git_repo "$H/app"
  local style
  for style in pure tokyo; do
    wizard "GLYPHS=on; starship_config $style"
    STARSHIP_CONFIG="$T/out" STARSHIP_SHELL=bash starship prompt --path "$H/app" --logical-path "$H/app" > "$T/prompt" 2>/dev/null
    check "grep -q 'app' '$T/prompt' && grep -q 'main' '$T/prompt'" "$style: shows the folder and the branch"
    check "! grep -qiE 'v[0-9]+\.[0-9]|via|on ' '$T/prompt'" "$style: nothing else (no versions)"
  done
  cleanup
}

test_one_numbered_question_previews_both_prompts_in_this_folder() {
  new_home
  git_repo "$H/app"
  answer ""
  # No starship yet (it's installed after the choices): a hand-drawn preview.
  wizard 'GLYPHS=on; PATH=/usr/bin:/bin; cd "$HOME/app"; ask_prompt; printf "RESULT=%s\n" "$PROMPT"'
  check "grep -q '1) pure' '$T/out' && grep -q '2) tokyo night' '$T/out'" "offers both prompts"
  check "grep -q '3) leave my prompt alone' '$T/out'" "offers leaving the prompt alone"
  check "[[ '$(grep -c '~/app main' "$T/out")' -ge 1 ]]" "pure preview shows this folder and branch"
  check "grep -q '❯' '$T/out'" "pure preview shows its ❯"
  check "[[ '$(grep -c '~/app.*main' "$T/out")' -ge 2 ]]" "tokyo night preview too"
  check "grep -qx 'RESULT=pure' '$T/out'" "Enter picks pure"
  check "grep -qx 'PROMPT=pure' '$STATE/choices.env'" "the answer is saved"
  git_repo "$H/a/b/c/app"
  wizard 'GLYPHS=on; PATH=/usr/bin:/bin; cd "$HOME/a/b/c/app"; ask_prompt'
  check "grep -q '…/b/c/app main' '$T/out'" "a deep folder shows its last three, as starship does"
  answer 2
  wizard 'GLYPHS=on; PATH=/usr/bin:/bin; ask_prompt'
  check "grep -qx 'PROMPT=tokyo' '$STATE/choices.env'" "2 saves tokyo night"
  answer 3
  wizard 'GLYPHS=on; PATH=/usr/bin:/bin; ask_prompt'
  check "grep -qx 'PROMPT=none' '$STATE/choices.env'" "3 saves none"
  cleanup
}

test_live_preview_uses_starship_when_it_is_there() {
  if ! command -v starship >/dev/null 2>&1; then printf '  skipped: needs starship\n'; return 0; fi
  new_home
  git_repo "$H/app"
  answer ""
  wizard 'GLYPHS=on; cd "$HOME/app"; ask_prompt'
  check "grep -q '~/app' '$T/out' && grep -q 'main' '$T/out'" "starship renders both in this folder, from ~"
  check "! grep -q '\\\\\[' '$T/out'" "no bash prompt escapes leak into the preview"
  cleanup
}

test_tokyo_night_needs_icons() {
  new_home
  answer ""
  wizard 'GLYPHS=off; PATH=/usr/bin:/bin; ask_prompt'
  check "! grep -q 'tokyo night' '$T/out' || grep -q 'needs' '$T/out'" "icons off: tokyo night isn't offered"
  check "grep -q '2) leave my prompt alone' '$T/out'" "icons off: pure or leave it alone"
  answer 2
  wizard 'GLYPHS=off; PATH=/usr/bin:/bin; ask_prompt'
  check "grep -qx 'PROMPT=none' '$STATE/choices.env'" "icons off: 2 leaves the prompt alone"
  # tokyo saved earlier, icons switched off since: pure, not a broken powerline
  wizard 'choice_set PROMPT tokyo'
  wizard 'GLYPHS=off; prompt_style; printf "\n"; starship_config'
  check "grep -qx pure '$T/out'" "a saved tokyo night falls back to pure without icons"
  check "! has_nerd_glyph '$T/out'" "and its config has no glyphs"
  cleanup
}

test_prompt_stage_writes_the_chosen_config_or_nothing() {
  new_home
  wizard 'brew_formulae() { :; }; PROMPT=tokyo; GLYPHS=on; stage_prompt; starship_config tokyo > "$HOME/expected"'
  same_bytes "$H/.config/starship.toml" "$H/expected" "tokyo night: its config is written"
  rm -f "$H/.config/starship.toml"
  wizard 'brew_formulae() { :; }; PROMPT=none; stage_prompt'
  check "[[ ! -e '$H/.config/starship.toml' ]]" "none: no starship.toml written"
  check "grep -qi 'left alone\|leave' '$T/out'" "none: says the prompt is left alone"
  cleanup
}

# ── the choices stage ─────────────────────────────────────────────────────

test_choices_stage_asks_theme_and_prompt_and_shows_them_on_rerun() {
  new_home
  # banner, accept tools, always dark, tokyo night, projects folder, create it, suggested tabs
  printf '%s\n' '' '' 2 2 "$H/repos" y '' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
  check "grep -qx 'THEME=dark' '$STATE/choices.env'" "theme saved"
  check "grep -qx 'PROMPT=tokyo' '$STATE/choices.env'" "prompt saved"
  printf '%s\n' '' y > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
  check "grep -qE 'colours +always dark' '$T/out'" "re-run shows the theme"
  check "grep -qE 'prompt +tokyo night' '$T/out'" "re-run shows the prompt"
  cleanup
}

test_prompt_is_not_asked_without_starship_selected() {
  new_home
  # banner, untick starship (2), accept, follow macOS, projects folder, create it, suggested tabs
  printf '%s\n' '' 2 '' '' "$H/repos" y '' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only choices
  check "! grep -q 'leave my prompt alone' '$T/out'" "no prompt question"
  check "grep -qx 'PROJECTS_DIR=$H/repos' '$STATE/choices.env'" "the answers after it still line up"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests "$@"
