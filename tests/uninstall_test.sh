#!/usr/bin/env bash
# Tests for --uninstall (issue 03): revert runs first, only wizard-installed
# packages are offered one by one, plugins and other-manager packages go
# through their own manager, and Node is never touched.
#
#   bash tests/uninstall_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# fake_brew_with PRESENT...: brew logs every call to $T/brew.log; `list`
# reports PRESENT as already installed, so the wizard journals the rest new.
fake_brew_with() {
  mkdir -p "$T/bin"
  {
    printf '#!/bin/sh\nlog="%s/brew.log"\npresent="%s"\n' "$T" "$*"
    cat <<'EOF'
printf '%s\n' "$*" >> "$log"
if [ "$1" = list ]; then for p in $present; do printf '%s\n' "$p"; done; fi
exit 0
EOF
  } > "$T/bin/brew"
  chmod +x "$T/bin/brew"
  PATH="$T/bin:$PATH"
}

# fake_herdr_uninstall: plugin uninstall goes through herdr and is logged.
fake_herdr_uninstall() {
  mkdir -p "$T/bin"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$T/herdr.log"
exit 0
EOF
  chmod +x "$T/bin/herdr"
  PATH="$T/bin:$PATH"
}

# fake_ya: yazi package calls are logged and succeed.
fake_ya() {
  mkdir -p "$T/bin"
  cat > "$T/bin/ya" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$T/ya.log"
exit 0
EOF
  chmod +x "$T/bin/ya"
  PATH="$T/bin:$PATH"
}

# fake_bat_log DIR: bat reports DIR as its config dir and logs every call.
fake_bat_log() {
  mkdir -p "$T/bin" "$1/themes"
  cat > "$T/bin/bat" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$T/bat.log"
[ "\$1" = --config-dir ] && echo "$1"
exit 0
EOF
  chmod +x "$T/bin/bat"
  PATH="$T/bin:$PATH"
}

# uninstall_flow_fakes: every external command a full run plus the removal
# step touches. Logs go to $T, outside HOME. Reports fd as already installed
# (so it journals pre-existing), Mocha as the only bat theme present (so
# Latte is downloaded and journals new), and writes whatever curl downloads.
uninstall_flow_fakes() {
  fake_brew_with fd
  fake_ya
  fake_herdr_uninstall
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
cfg="\$HOME/.config/herdr/config.toml"
printf '%s\n' "\$*" >> "$T/herdr.log"
case "\$1" in
  --skill) printf '# herdr skill (fake)\n'; exit 0 ;;
esac
case "\$1 \$2" in
  "plugin list") [ -e "$T/hunk-installed" ] && echo "- jhochenbaum.hunkdiff (hunk) enabled" ;;
  "plugin install") touch "$T/hunk-installed" ;;
  "plugin config-dir") echo "\$HOME/.config/herdr/plugins/config/\$3" ;;
  "plugin action")
    cp "\$cfg" "\$cfg.hunkdiff-backup"
    body=\$(awk 'index(\$0, "# BEGIN jhochenbaum.hunkdiff") == 1 { skip = 1 } !skip { print } index(\$0, "# END jhochenbaum.hunkdiff") == 1 { skip = 0 }' "\$cfg")
    printf '%s\n\n%s\n' "\$body" "# BEGIN jhochenbaum.hunkdiff" > "\$cfg"
    printf '[[keys.command]]\nkey = "prefix+shift+a"\n# END jhochenbaum.hunkdiff\n' >> "\$cfg"
    ;;
  "config check") exit 0 ;;
  "server reload-config") exit 0 ;;
  "integration status") echo "claude: current" ;;
esac
exit 0
EOF
  cat > "$T/bin/gh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$T/gh.log"
exit 0
EOF
  chmod +x "$T/bin/gh"
  cat > "$T/bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = clone ]; then
  dir="$4"
  mkdir -p "$dir/lua/config" "$dir/lua/plugins"
  printf '%s\n' '-- LazyVim starter skeleton (fake clone)' \
    'return { { "LazyVim/LazyVim", import = "lazyvim.plugins" } }' \
    > "$dir/lua/config/lazy.lua"
fi
exit 0
EOF
  chmod +x "$T/bin/git"
  cat > "$T/bin/curl" <<EOF
#!/bin/sh
while [ "\$#" -gt 0 ]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; *) shift ;; esac
done
printf '# fake theme\n' > "\$out"
printf '%s\n' "\$*" >> "$T/curl.log"
exit 0
EOF
  chmod +x "$T/bin/curl"
  for tool in node nvim claude xcode-select lazygit; do
    case "$tool" in
      node) printf '#!/bin/sh\necho v22.20.1\n' > "$T/bin/$tool" ;;
      lazygit) printf '#!/bin/sh\n[ "$1" = --print-config-dir ] && echo "$HOME/.config/lazygit"\nexit 0\n' > "$T/bin/$tool" ;;
      *) printf '#!/bin/sh\nexit 0\n' > "$T/bin/$tool" ;;
    esac
    chmod +x "$T/bin/$tool"
  done
  mkdir -p "$T/batcfg/themes"
  touch "$T/batcfg/themes/Catppuccin Mocha.tmTheme"
  cat > "$T/bin/bat" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$T/bat.log"
[ "\$1" = --config-dir ] && echo "$T/batcfg"
exit 0
EOF
  chmod +x "$T/bin/bat"
  PATH="$T/bin:$PATH"
}

# seed_package_journal: a journal with one of everything uninstall handles,
# plus the things it must never touch.
seed_package_journal() {
  mkdir -p "$STATE"
  {
    printf '2026-01-01T00:00:00\tBREW\tstarship\tnew\tformula\n'
    printf '2026-01-01T00:00:01\tBREW\tfd\tpre-existing\tformula\n'
    printf '2026-01-01T00:00:02\tBREW\tghostty\tnew\tcask\n'
    printf '2026-01-01T00:00:03\tBREW\tnode\tnew\tformula\n'
    printf '2026-01-01T00:00:04\tPLUGIN\tjhochenbaum.hunkdiff\tnew\n'
    printf '2026-01-01T00:00:05\tPKG\tya:yazi-rs/flavors:catppuccin-mocha\tnew\n'
    printf '2026-01-01T00:00:06\tPKG\tbat:Catppuccin Latte.tmTheme\tnew\n'
  } >> "$STATE/journal.tsv"
}

# ── tests ─────────────────────────────────────────────────────────────────

test_brew_installs_journal_new_and_present_pre_existing() {
  new_home
  fake_brew_with fd
  wizard 'JOURNALING=1; brew_formulae fd starship'
  check "grep -q 'BREW\tfd\tpre-existing' '$STATE/journal.tsv'" "fd was already there"
  check "grep -q 'BREW\tstarship\tnew' '$STATE/journal.tsv'" "starship is the wizard's"
  check "grep -q 'install starship' '$T/brew.log'" "only the missing formula installed"
  check "! grep -q 'install fd' '$T/brew.log'" "nothing already there reinstalled"
  cleanup
}

test_uninstall_reverts_first_then_confirms_each() {
  new_home
  fake_brew_with
  fake_herdr_uninstall
  fake_ya
  fake_bat_log "$T/bat"
  touch "$T/bat/themes/Catppuccin Latte.tmTheme"
  seed_package_journal
  # Remove starship, decline ghostty, remove the rest.
  printf 'y\nn\ny\ny\ny\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --uninstall > "$T/out" 2>&1
  check "awk '/Nothing to revert|journal and the backups it used archived/{a=NR} /Remove starship/{b=NR} END{exit !(a&&b&&a<b)}' '$T/out'" \
    "revert output comes before any removal"
  check "grep -q 'uninstall starship' '$T/brew.log'" "agreed removal ran"
  check "! grep -q 'uninstall ghostty' '$T/brew.log'" "a declined cask is kept"
  check "grep -q 'plugin uninstall jhochenbaum.hunkdiff' '$T/herdr.log'" \
    "the plugin goes through herdr, not rm"
  check "grep -q 'pkg delete yazi-rs/flavors:catppuccin-mocha' '$T/ya.log'" \
    "the flavour goes through ya"
  check "[[ ! -e '$T/bat/themes/Catppuccin Latte.tmTheme' ]]" "the bat theme file is gone"
  check "grep -q 'cache --build' '$T/bat.log'" "bat rebuilds its cache through its own binary"
  check "grep -q 'keeping ghostty' '$T/out'" "declining says what is kept, and continues"
  cleanup
}

test_pre_existing_and_node_are_never_offered() {
  new_home
  fake_brew_with
  fake_herdr_uninstall
  seed_package_journal
  printf 'y\ny\ny\ny\ny\ny\ny\ny\ny\ny\n' > "$T/answers"
  CLI_INPUT="$T/answers" cli --uninstall > "$T/out" 2>&1
  check "! grep -q 'Remove fd' '$T/out'" "a pre-existing formula is never offered"
  check "! grep -qw 'uninstall fd' '$T/brew.log'" "and never uninstalled"
  check "! grep -qi 'remove.*node\|uninstall.*node' '$T/out'" "Node is never offered"
  check "! grep -qw 'node' '$T/brew.log'" "Node is never uninstalled"
  cleanup
}

test_uninstall_flag_parses_and_yes_is_rejected() {
  new_home
  wizard 'parse_args --uninstall; printf "%s" "$MODE"'
  check "[[ '$(cat "$T/out")' == uninstall ]]" "--uninstall is a mode"
  wizard 'parse_args --yes --uninstall || echo usage-error'
  check "grep -qx usage-error '$T/out'" "--yes never skips per-package confirms"
  cleanup
}

test_uninstall_after_a_full_run_leaves_no_dangling_references() {
  new_home
  uninstall_flow_fakes
  mkdir -p "$STATE" "$H/repos"
  cat > "$STATE/choices.env" <<EOF
GLYPHS=on
TOOLS=prompt,jumper,typing,editor,review,files,github,statusline
PROMPT_STYLE=pure
TABS=agents,source code,local server
PROJECTS_DIR=$H/repos
EOF
  printf '# my own aliases\nalias gs="git status"\n' > "$H/.zshrc"
  cp "$H/.zshrc" "$T/orig-zshrc"
  # The full run, non-interactively with everything selected.
  { for _ in $(seq 40); do printf '\n'; done; } > "$T/answers"
  CLI_INPUT="$T/answers" cli --yes --skip macos,tour > "$T/run-out" 2>&1
  # Then uninstall, agreeing to every removal.
  { for _ in $(seq 40); do printf 'y\n'; done; } > "$T/answers"
  CLI_INPUT="$T/answers" cli --uninstall > "$T/out" 2>&1
  check "grep -q 'BREW\tghostty\t\\(new\\|pre-existing\\)\tcask' $STATE/archive/*/journal.tsv" \
    "the run journaled the Ghostty cask either way (this machine may have the app)"
  check "grep -q 'BREW\tfont-jetbrains-mono-nerd-font\tnew\tcask' $STATE/archive/*/journal.tsv" \
    "the run journaled the cask it installed"
  check "grep -q 'PLUGIN\tjhochenbaum.hunkdiff\tnew' $STATE/archive/*/journal.tsv" \
    "the run journaled the plugin it installed"
  check "grep -q 'PKG\tya:yazi-rs/flavors:catppuccin-mocha\tnew' $STATE/archive/*/journal.tsv" \
    "the run journaled the flavour it installed"
  check "grep -q 'PKG\tbat:Catppuccin Latte.tmTheme\tnew' $STATE/archive/*/journal.tsv" \
    "the run journaled the theme it downloaded"
  check "grep -q 'uninstall starship' '$T/brew.log'" "an installed formula is removed"
  check "grep -q 'uninstall --cask font-jetbrains-mono-nerd-font' '$T/brew.log'" \
    "an installed cask is removed with --cask"
  check "! grep -qw 'uninstall fd' '$T/brew.log'" "the pre-existing formula is kept"
  check "grep -q 'plugin uninstall jhochenbaum.hunkdiff' '$T/herdr.log'" "the plugin is uninstalled"
  check "[[ '$(grep -c 'pkg delete' "$T/ya.log")' == 2 ]]" "both flavours go through ya"
  check "[[ ! -e '$T/batcfg/themes/Catppuccin Latte.tmTheme' ]]" "the downloaded theme is gone"
  check "[[ -f '$T/batcfg/themes/Catppuccin Mocha.tmTheme' ]]" "the pre-existing theme is kept"
  same_bytes "$H/.zshrc" "$T/orig-zshrc" "the shell startup file is the user's own again"
  check "! grep -qE 'starship|fzf|eza|bat |nvim|lazygit|yazi|hproj|gh ' '$H/.zshrc'" \
    "and references no removed binary"
  check "[[ ! -e '$H/.config/ghostty/config' ]]" "the Ghostty config the run created is gone"
  check "[[ ! -e '$H/.config/herdr/config.toml' ]]" "the herdr config the run created is gone"
  if command -v zsh >/dev/null 2>&1; then
    HOME="$H" ZDOTDIR="$H" zsh -i -c true > "$T/zsh.out" 2> "$T/zsh.err"
    check "[[ ! -s '$T/zsh.err' ]]" "a new shell starts without errors or warnings"
  else
    printf '  skipped: needs zsh\n'
  fi
  cleanup
}

test_uninstall_with_nothing_installed_exits_cleanly() {
  new_home
  : > "$T/answers"
  CLI_INPUT="$T/answers" cli --uninstall > "$T/out" 2>&1
  check "[[ $? == 0 ]]" "clean exit"
  check "grep -q 'Nothing to revert' '$T/out'" "empty revert says so"
  check "grep -qi 'nothing.*to remove' '$T/out'" "and so does the removal step"
  cleanup
}

run_tests "$@"
