#!/usr/bin/env bash
# Clean-home revert acceptance test (issue 04): the specification's real
# acceptance criterion. Snapshot a home directory, run the wizard
# non-interactively with everything selected, run --revert, then diff the home
# directory against the snapshot. The diff should contain nothing but the
# wizard's own state directory.
#
# Two scenarios: a pristine home (every file the wizard writes is a creation)
# and a populated home (seeded user files, run twice to prove the backup store
# still holds the user's original rather than the wizard's first-run output).
#
# Only stages that need no macOS interaction or terminal relaunch run here
# (macos and tour are skipped); those four interactive points are verified by
# hand. Needs jq (the wizard's JSON helper uses it, as in journal_test.sh).
# No network, brew, sudo, VM or clean machine needed: every external tool the
# run touches is faked on PATH. Leaves no residue (KEEP=1 keeps the sandboxes).
#
#   bash tests/revert_acceptance_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

HUNK=jhochenbaum.hunkdiff

# accept_fakes: every external command a full run touches, faked on PATH.
# Logs go to $T (outside the snapshotted HOME); nothing here touches HOME.
accept_fakes() {
  mkdir -p "$T/bin"
  fake_brew
  fake_bat
  # Node new enough for herdr-hunk, so the review stage installs it.
  mkdir -p "$T/bin"
  printf '#!/bin/sh\necho v22.20.1\n' > "$T/bin/node"
  chmod +x "$T/bin/node"
  # The Xcode tools look present, so no dialog opens.
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/xcode-select"
  chmod +x "$T/bin/xcode-select"
  # Neovim and Claude Code look installed but do nothing.
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/nvim"
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/claude"
  chmod +x "$T/bin/nvim" "$T/bin/claude"
  # git clone lays a LazyVim skeleton (without the language extras, so the
  # editor stage exercises adding them); anything else succeeds quietly.
  cat > "$T/bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = clone ]; then
  dir="$4"
  mkdir -p "$dir/lua/config" "$dir/lua/plugins"
  printf '%s\n' '-- LazyVim starter skeleton (acceptance-test fake clone)' \
    'return { { "LazyVim/LazyVim", import = "lazyvim.plugins" } }' \
    > "$dir/lua/config/lazy.lua"
fi
exit 0
EOF
  chmod +x "$T/bin/git"
  # starship prints a canned preset and prompt.
  cat > "$T/bin/starship" <<'EOF'
#!/bin/sh
if [ "$1" = preset ]; then
  printf '%s\n' '# canned starship preset (acceptance-test fake)' \
    '[character]' 'success_symbol = "[>](bold green)"'
elif [ "$1" = prompt ]; then
  printf 'preview-dir on preview-branch\n'
fi
exit 0
EOF
  chmod +x "$T/bin/starship"
  # GitHub looks logged in with gh-dash missing, so the install path runs.
  cat > "$T/bin/gh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$T/gh.log"
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "extension list") exit 0 ;;
esac
exit 0
EOF
  chmod +x "$T/bin/gh"
  # yazi flavours install cleanly.
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/ya"
  chmod +x "$T/bin/ya"
  # lazygit reports its config dir; herdr behaves like review_test.sh's fake
  # plus the calls the full run makes: config check, server reload, the agent
  # hook status (current, so nothing is installed) and the skill text.
  cat > "$T/bin/lazygit" <<'EOF'
#!/bin/sh
[ "$1" = --print-config-dir ] && echo "$HOME/.config/lazygit"
exit 0
EOF
  chmod +x "$T/bin/lazygit"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
cfg="\$HOME/.config/herdr/config.toml"
printf '%s\n' "\$*" >> "$T/herdr.log"
case "\$1" in
  --skill) printf '# herdr skill (acceptance-test fake)\n'; exit 0 ;;
esac
case "\$1 \$2" in
  "plugin list") [ -e "$T/hunk-installed" ] && echo "- $HUNK (hunk) enabled" ;;
  "plugin install") touch "$T/hunk-installed" ;;
  "plugin config-dir") echo "\$HOME/.config/herdr/plugins/config/\$3" ;;
  "plugin action")
    cp "\$cfg" "\$cfg.hunkdiff-backup"
    body=\$(awk 'index(\$0, "# BEGIN $HUNK") == 1 { skip = 1 } !skip { print } index(\$0, "# END $HUNK") == 1 { skip = 0 }' "\$cfg")
    printf '%s\n\n%s\n' "\$body" "# BEGIN $HUNK" > "\$cfg"
    printf '[[keys.command]]\nkey = "prefix+shift+a"\n# END $HUNK\n' >> "\$cfg"
    ;;
  "config check") exit 0 ;;
  "server reload-config") exit 0 ;;
  "integration status") echo "claude: current" ;;
esac
exit 0
EOF
  chmod +x "$T/bin/herdr"
  PATH="$T/bin:$PATH"
}

# seed_choices: everything selected, saved as a previous run's answers, so
# --yes reuses them without asking anything.
seed_choices() {
  mkdir -p "$STATE" "$H/repos"
  cat > "$STATE/choices.env" <<EOF
GLYPHS=on
TOOLS=prompt,jumper,typing,editor,review,files,github,statusline
PROMPT_STYLE=pure
TABS=agents,source code,local server
PROJECTS_DIR=$H/repos
EOF
}

# accept_answers: stdin for the run. With --yes and saved choices the only
# question left is the editor stage's replace confirm (populated home) and the
# fresh-Neovim wait; both accept anything, so y-then-Enters covers all cases.
accept_answers() {
  { printf 'y\n'; for _ in $(seq 30); do printf '\n'; done; } > "$T/answers"
  printf 'y\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\n' > "$T/tty"
}

# accept_run: the full non-interactive run with everything selected.
accept_run() {
  accept_answers
  CLI_INPUT="$T/answers" cli --yes --skip macos,tour
}

# accept_revert: --revert, answering Enter to anything it asks.
accept_revert() {
  for _ in $(seq 30); do printf '\n'; done > "$T/answers"
  CLI_INPUT="$T/answers" cli --revert
}

# snapshot_home DIR: manifest of every path under HOME (except the wizard's
# own state dir and Library) plus sha256 of every file, for diffing later.
# Library is excluded: no stage target lives there, but a host with the real
# Ghostty app installed gets its sentry telemetry under Library/Caches when
# the ghostty stage queries the binary's theme list.
snapshot_home() {
  mkdir -p "$1"
  ( cd "$H" && find . -path ./.ghostty-herdr-wizard -prune -o -path ./Library -prune -o -print | LC_ALL=C sort > "$1/manifest" )
  ( cd "$H" && find . -path ./.ghostty-herdr-wizard -prune -o -path ./Library -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$1/sums" )
}

# diff_home DIR NAME: true when HOME still matches the snapshot in DIR,
# printing the offending diffs (not just pass/fail) when it doesn't.
diff_home() {
  local now="$T/now-$2" ok=true
  mkdir -p "$now"
  ( cd "$H" && find . -path ./.ghostty-herdr-wizard -prune -o -path ./Library -prune -o -print | LC_ALL=C sort > "$now/manifest" )
  ( cd "$H" && find . -path ./.ghostty-herdr-wizard -prune -o -path ./Library -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > "$now/sums" )
  diff -u "$1/manifest" "$now/manifest" > "$T/manifest.diff" 2>&1 || ok=false
  diff -u "$1/sums" "$now/sums" > "$T/sums.diff" 2>&1 || ok=false
  if $ok; then
    return 0
  fi
  printf '  home differs from snapshot:\n'
  sed 's/^/    /' "$T/manifest.diff" "$T/sums.diff"
  return 1
}

# ── pristine home: every file the wizard writes is a creation ──────────────

test_pristine_home_revert_leaves_no_trace() {
  new_home
  accept_fakes
  seed_choices
  snapshot_home "$T/snap"
  accept_run
  check "[[ -s '$STATE/journal.tsv' ]]" "the run journaled its changes"
  accept_revert
  check "diff_home '$T/snap' pristine" "after revert, home differs only by the state dir"
  cleanup
}

# ── populated home: seeded user files, run twice, then reverted ─────────────

seed_populated() {
  mkdir -p "$H/.config/ghostty" "$H/.config/nvim" "$H/.claude" "$H/repos"
  printf '# my own aliases\nalias gs="git status"\n' > "$H/.zshrc"
  printf 'export PATH="$HOME/.local/bin:$PATH"\n' > "$H/.zprofile"
  printf '[user]\n\tname = Me\n' > "$H/.gitconfig"
  printf 'theme = "my-theme"\nfont-size = 14\n' > "$H/.config/ghostty/config"
  printf 'vim.opt.number = true\n' > "$H/.config/nvim/init.lua"
  # Written with jq so the seed is byte-stable across the wizard's own
  # jq round-trips (add the statusLine key, revert it away).
  jq -n '{"permissions":{"allow":["Bash(git status)"]},"model":"opus"}' > "$H/.claude/settings.json"
  mkdir -p "$T/orig"
  cp "$H/.zshrc" "$H/.zprofile" "$H/.gitconfig" "$H/.config/ghostty/config" \
    "$H/.config/nvim/init.lua" "$H/.claude/settings.json" "$T/orig/"
}

test_populated_home_revert_restores_every_seed() {
  new_home
  accept_fakes
  seed_choices
  seed_populated
  snapshot_home "$T/snap"
  accept_run
  accept_run
  check "cmp -s '$STATE/backups/.config/ghostty/config' '$T/orig/config'" \
    "two runs later, the backup still holds the user's original, not run-1 output"
  accept_revert
  same_bytes "$H/.zshrc" "$T/orig/.zshrc" "shell startup file is byte-identical"
  same_bytes "$H/.zprofile" "$T/orig/.zprofile" "shell profile is byte-identical"
  same_bytes "$H/.gitconfig" "$T/orig/.gitconfig" "git config is byte-identical"
  same_bytes "$H/.config/ghostty/config" "$T/orig/config" "Ghostty config is byte-identical"
  same_bytes "$H/.config/nvim/init.lua" "$T/orig/init.lua" "hand-rolled Neovim config is back, not destroyed"
  check "cmp -s '$H/.claude/settings.json' '$T/orig/settings.json'" \
    "Claude Code settings are byte-identical (permissions and model untouched)"
  check "diff_home '$T/snap' populated" "nothing else lingers outside the state dir"
  cleanup
}

run_tests "$@"
