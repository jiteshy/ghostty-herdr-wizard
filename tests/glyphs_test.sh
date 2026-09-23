#!/usr/bin/env bash
# Tests for the Nerd Font glyph switch: one saved choice that every consumer
# follows, so a terminal without a Nerd Font never shows boxes.
#
#   bash tests/glyphs_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# has_nerd_glyph FILE: true if FILE contains a Nerd Font glyph. Nerd Fonts put
# every icon and powerline separator in Unicode's Private Use Areas.
has_nerd_glyph() {
  perl -CSD -ne '$found = 1 if /[\x{E000}-\x{F8FF}\x{F0000}-\x{10FFFF}]/; END { exit !$found }' "$1"
}

# ── tests ─────────────────────────────────────────────────────────────────

test_glyphs_default_to_on_when_never_chosen() {
  new_home
  wizard 'printf "%s" "$GLYPHS"'
  check "[[ '$(cat "$T/out")' == on ]]" "GLYPHS defaults to on (got '$(cat "$T/out")')"
  cleanup
}

test_glyph_choice_is_saved_for_later_runs() {
  new_home
  wizard 'choice_set GLYPHS off'
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "choice written to choices.env"
  wizard 'printf "%s" "$GLYPHS"'
  check "[[ '$(cat "$T/out")' == off ]]" "a later run starts with the saved choice (got '$(cat "$T/out")')"
  wizard 'choice_set GLYPHS on'
  check "[[ '$(grep -c GLYPHS "$STATE/choices.env")' == 1 ]]" "changing it replaces the line, not appends"
  cleanup
}

test_herdr_sidebar_uses_dots_without_glyphs() {
  new_home
  wizard 'GLYPHS=off; herdr_config'
  check "grep -qx 'status_indicators = \"dots\"' '$T/out'" "glyphs off: herdr uses its glyph-free dots"
  wizard 'GLYPHS=on; herdr_config'
  check "grep -qx 'status_indicators = \"symbols\"' '$T/out'" "glyphs on: herdr uses symbols"
  cleanup
}

test_eza_drops_icons_without_glyphs() {
  new_home
  wizard 'GLYPHS=off; zshrc_block; hproj_script'
  check "grep -q 'alias ll=.eza' '$T/out'" "glyphs off: the eza aliases are still there"
  check "! grep -q -- '--icons' '$T/out'" "glyphs off: no eza --icons in aliases or the hproj preview"
  wizard 'GLYPHS=on; zshrc_block'
  check "[[ '$(grep -c -- '--icons=auto' "$T/out")' == 3 ]]" "glyphs on: ls, ll and lt show icons"
  wizard 'GLYPHS=on; hproj_script'
  check "grep -q -- 'eza --tree .*--icons=always' '$T/out'" "glyphs on: hproj preview shows icons"
  cleanup
}

test_statusline_is_plain_text_without_glyphs() {
  if ! command -v jq >/dev/null 2>&1; then printf '  skipped: needs jq\n'; return 0; fi
  new_home
  local sample='{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp/app","git_worktree":"feature"},"cost":{"total_cost_usd":1}}'
  wizard 'GLYPHS=off; statusline_script > "$HOME/sl.sh"'
  bash "$H/sl.sh" <<<"$sample" > "$T/rendered"
  check "grep -q 'Opus' '$T/rendered' && grep -q 'worktree feature' '$T/rendered'" "glyphs off: still shows model and worktree"
  check "! has_nerd_glyph '$T/rendered'" "glyphs off: no Nerd Font icons in the status line"
  wizard 'GLYPHS=on; statusline_script > "$HOME/sl.sh"'
  bash "$H/sl.sh" <<<"$sample" > "$T/rendered"
  check "has_nerd_glyph '$T/rendered'" "glyphs on: status line shows its icons"
  cleanup
}

test_yazi_turns_off_icons_and_powerline_separators_without_glyphs() {
  new_home
  wizard 'GLYPHS=off; yazi_theme'
  local rule
  for rule in globs dirs files exts conds; do
    check "grep -Eq '^$rule *= *\[\]' '$T/out'" "glyphs off: yazi icon rule '$rule' emptied"
  done
  check "grep -Eq '^sep_left *= *\{ open = \"\", close = \"\" \}' '$T/out'" "glyphs off: status bar has no powerline separator"
  check "grep -q '^\[tabs\]' '$T/out' && grep -q '^sep_inner' '$T/out'" "glyphs off: tab separators replaced"
  check "grep -q 'catppuccin-mocha' '$T/out'" "glyphs off: still themed"
  wizard 'GLYPHS=on; yazi_theme'
  check "! grep -q '^\[icon\]' '$T/out'" "glyphs on: yazi keeps its icons"
  cleanup
}

test_lazygit_drops_nerd_font_icons_without_glyphs() {
  new_home
  wizard 'GLYPHS=off; lazygit_config'
  check "grep -q 'editPreset: nvim' '$T/out'" "glyphs off: rest of the lazygit config intact"
  check "grep -q 'nerdFontsVersion: \"\"' '$T/out'" "glyphs off: lazygit shows no Nerd Font icons"
  wizard 'GLYPHS=on; lazygit_config'
  check "grep -q 'nerdFontsVersion: \"3\"' '$T/out'" "glyphs on: lazygit uses Nerd Font v3 icons"
  cleanup
}

test_neovim_icons_fall_back_to_ascii_without_glyphs() {
  new_home
  wizard 'GLYPHS=off; nvim_icons_plugin'
  check "grep -q 'nvim-mini/mini.icons' '$T/out'" "configures LazyVim's icon provider"
  check "grep -q 'style = \"ascii\"' '$T/out'" "glyphs off: Neovim uses ASCII icons"
  wizard 'GLYPHS=on; nvim_icons_plugin'
  check "grep -q 'style = \"glyph\"' '$T/out'" "glyphs on: Neovim uses Nerd Font icons"
  cleanup
}

test_starship_prompt_has_no_nerd_glyphs_without_glyphs() {
  if ! command -v starship >/dev/null 2>&1; then printf '  skipped: needs starship\n'; return 0; fi
  new_home
  # Rendered inside this repo, so the git branch segment shows too: starship's
  # own default branch symbol is a Nerd Font glyph.
  wizard 'GLYPHS=off; starship_config'
  STARSHIP_CONFIG="$T/out" STARSHIP_SHELL=bash starship prompt --path "$ROOT" > "$T/prompt" 2>/dev/null
  check "grep -q 'git' '$T/prompt'" "glyphs off: prompt still shows the git branch"
  check "! has_nerd_glyph '$T/prompt'" "glyphs off: no Nerd Font glyphs in the prompt"
  wizard 'GLYPHS=on; starship_config'
  STARSHIP_CONFIG="$T/out" STARSHIP_SHELL=bash starship prompt --path "$ROOT" > "$T/prompt" 2>/dev/null
  check "has_nerd_glyph '$T/prompt'" "glyphs on: pastel powerline prompt keeps its glyphs"
  cleanup
}

# End to end: a saved "off" is honoured by a later --only run with no questions.
test_ghostty_stage_follows_the_saved_choice() {
  new_home
  mkdir -p "$STATE"
  printf 'GLYPHS=off\n' > "$STATE/choices.env"
  cli --only 3
  check "[[ -f '$H/.config/ghostty/config' ]]" "stage 3 wrote the Ghostty config"
  check "! grep -q 'Nerd Font' '$H/.config/ghostty/config'" "glyphs off: Ghostty isn't pointed at a Nerd Font"
  printf 'GLYPHS=on\n' > "$STATE/choices.env"
  cli --only 3
  check "grep -q '^font-family = JetBrainsMono Nerd Font' '$H/.config/ghostty/config'" "glyphs on: Ghostty uses the Nerd Font"
  cleanup
}

test_choosing_plain_text_saves_it_and_skips_the_font() {
  new_home
  local saved_path="$PATH"
  fake_brew
  printf '\n2\n\n\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only 2
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "answer 2 saves plain text"
  check "! grep -q 'font-jetbrains-mono-nerd-font' '$T/brew.log' 2>/dev/null" "plain text: no Nerd Font install"
  printf '\n\n\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only 2
  check "grep -qx 'GLYPHS=off' '$STATE/choices.env'" "Enter on a re-run keeps the saved answer"
  printf '\n1\n\n\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --only 2
  check "grep -qx 'GLYPHS=on' '$STATE/choices.env'" "answer 1 saves icons"
  check "grep -q 'font-jetbrains-mono-nerd-font' '$T/brew.log'" "icons: installs the Nerd Font"
  PATH="$saved_path"
  cleanup
}

# ── runner ──────────────────────────────────────────────────────────────────

run_tests
