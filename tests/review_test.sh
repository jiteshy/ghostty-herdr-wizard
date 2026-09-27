#!/usr/bin/env bash
# Tests for the review stage's herdr-hunk: the Node version gate (checked on the
# selection screen, never fixed for you), the prefix+shift+a key collision, and
# the herdr config the plugin's setup-keys edits, which the wizard re-absorbs.
#
#   bash tests/review_test.sh

# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

HUNK=jhochenbaum.hunkdiff
BEGIN="# BEGIN $HUNK — managed by \`setup-keys\`; edit via the plugin, not by hand"
CFG_REL=.config/herdr/config.toml

# fake_node VERSION [DIR]: a node on PATH that reports VERSION, living in DIR
# (default $T/bin), which is how the wizard tells which manager installed it.
fake_node() {
  local dir="${2:-$T/bin}"
  mkdir -p "$dir"
  printf '#!/bin/sh\necho %s\n' "$1" > "$dir/node"
  chmod +x "$dir/node"
  PATH="$dir:$PATH"
}

# no_node: take every node off PATH.
no_node() {
  local d keep="" IFS=:
  for d in $PATH; do
    [[ -x "$d/node" ]] || keep+="$d:"
  done
  PATH="${keep%:}"
}

# fake_herdr: a herdr (and lazygit) on PATH for the review stage. Each call is
# logged to $T/herdr.log. `plugin install` makes herdr-hunk show in `plugin
# list`, and setup-keys edits the herdr config the way the real plugin does: a
# copy to config.toml.hunkdiff-backup, then its managed block after one blank line.
fake_herdr() {
  mkdir -p "$T/bin"
  cat > "$T/bin/herdr" <<EOF
#!/bin/bash
cfg="\$HOME/$CFG_REL"
printf '%s\n' "\$*" >> "$T/herdr.log"
case "\$1 \$2" in
  "plugin list") [ -e "$T/hunk-installed" ] && echo "- $HUNK (hunk) enabled" ;;
  "plugin install") touch "$T/hunk-installed" ;;
  "plugin config-dir") echo "\$HOME/.config/herdr/plugins/config/\$3" ;;
  "plugin action")
    [ "\$4" = setup-keys ] || exit 0
    cp "\$cfg" "\$cfg.hunkdiff-backup"
    body=\$(awk 'index(\$0, "# BEGIN $HUNK") == 1 { skip = 1 } !skip { print } index(\$0, "# END $HUNK") == 1 { skip = 0 }' "\$cfg")
    printf '%s\n\n%s\n' "\$body" '$BEGIN' > "\$cfg"
    printf '[[keys.command]]\nkey = "prefix+shift+a"\ntype = "plugin_action"\ncommand = "$HUNK.review:staged"\n# END $HUNK\n' >> "\$cfg"
    ;;
esac
exit 0
EOF
  cat > "$T/bin/lazygit" <<'EOF'
#!/bin/sh
[ "$1" = --print-config-dir ] && echo "$HOME/.config/lazygit"
exit 0
EOF
  chmod +x "$T/bin/herdr" "$T/bin/lazygit"
  PATH="$T/bin:$PATH"
}

# review_run CODE: a wizard run with journaling on, then CODE.
review_run() {
  wizard "journal_init; JOURNALING=1; $1"
}

# What the herdr stage writes, the way it writes it.
WRITE_HERDR_CONFIG='install_file "$HOME/.config/herdr/config.toml" < <(herdr_config)'

# journal_has TYPE FIELD3 [FIELD4]: true if the journal has such a line.
journal_has() {
  awk -F'\t' -v t="$1" -v a="$2" -v b="${3:-}" '$2 == t && $3 == a && (b == "" || $4 == b) { found = 1 } END { exit !found }' \
    "$STATE/journal.tsv" 2>/dev/null
}

# stage_setup: a sandbox with fake brew, herdr and lazygit, and Node VERSION.
stage_setup() {
  new_home
  fake_brew
  fake_herdr
  fake_node "$@"
}

# ── the Node gate ─────────────────────────────────────────────────────────

test_node_22_12_or_newer_passes_the_gate() {
  local v
  for v in v22.12.0 v22.20.1 v23.0.0 v24.3.0; do
    new_home
    fake_node "$v"
    wizard 'node_ok && echo PASS'
    check "grep -qx PASS '$T/out'" "Node $v is new enough"
    cleanup
  done
}

test_older_or_missing_node_fails_the_gate() {
  local v saved="$PATH"
  for v in v22.11.9 v20.19.2 v18.0.0; do
    new_home
    fake_node "$v"
    wizard 'node_ok || echo BLOCKED'
    check "grep -qx BLOCKED '$T/out'" "Node $v is too old"
    cleanup
    PATH="$saved"
  done
  new_home
  no_node
  wizard 'node_ok || echo BLOCKED; node_gate'
  PATH="$saved"
  check "grep -qx BLOCKED '$T/out'" "no Node at all fails the gate"
  check "grep -q 'needs Node 22.12+, none found' '$T/out'" "and says none was found"
  cleanup
}

test_the_gate_names_the_manager_and_its_exact_command() {
  local saved="$PATH"
  new_home
  fake_node v20.19.2 "$H/.nvm/versions/node/v20.19.2/bin"
  wizard 'node_gate'
  check "grep -q 'needs Node 22.12+, you have v20.19.2 (via nvm)' '$T/out'" "names the version and nvm"
  check "grep -q 'nvm install 22 && nvm use 22' '$T/out'" "gives nvm's command"
  cleanup; PATH="$saved"

  new_home
  fake_node v20.19.2 "$H/.volta/bin"
  wizard 'node_gate'
  check "grep -q '(via volta)' '$T/out' && grep -q 'volta install node@22' '$T/out'" "volta, with its command"
  cleanup; PATH="$saved"

  new_home
  fake_node v20.19.2 "$H/.local/state/fnm_multishells/123_456/bin"
  wizard 'node_gate'
  check "grep -q '(via fnm)' '$T/out' && grep -q 'fnm install 22' '$T/out'" "fnm, with its command"
  cleanup; PATH="$saved"

  new_home
  fake_node v20.19.2 "$T/brew/opt/node@20/bin"
  wizard "BREW_PREFIX='$T/brew'; node_gate"
  check "grep -q '(via Homebrew node@20)' '$T/out' && grep -q 'brew install node@22' '$T/out'" \
    "a versioned Homebrew node, with its command (got: $(tr '\n' '|' < "$T/out"))"
  cleanup; PATH="$saved"
}

test_the_wizard_never_runs_a_node_manager() {
  local bad
  # Any line that would run one, rather than print it for the user.
  bad=$(grep -nE '(nvm (install|use|alias)|volta install|fnm (install|use|default)|mise use|asdf (install|set)|brew (install|upgrade) node)' "$WIZARD" |
    grep -vE "^[0-9]+:[[:space:]]*(#|\"|[a-z]+\)[[:space:]]*(fix|printf))|printf|echo|note|say|step" || true)
  check "[[ -z \"\$bad\" ]]" "the Node commands are only ever printed: $bad"
}

# ── the selection screen ──────────────────────────────────────────────────

test_selection_lists_herdr_hunk_in_the_review_group() {
  new_home
  fake_node v22.12.0
  wizard 'show_clusters'
  check "grep -qE '^ +herdr-hunk +review the agent.s diff hunk by hunk' '$T/out'" "herdr-hunk is listed with what it gives you"
  check "! grep -q 'needs newer Node' '$T/out'" "no warning with Node new enough"
  cleanup
}

test_selection_greys_out_herdr_hunk_when_node_is_too_old() {
  new_home
  fake_node v20.19.2 "$H/.nvm/versions/node/v20.19.2/bin"
  wizard 'show_clusters'
  check "grep -qE '^ +herdr-hunk +needs newer Node' '$T/out'" "herdr-hunk says it needs newer Node"
  check "grep -q 'you have v20.19.2 (via nvm)' '$T/out'" "names the Node found"
  check "grep -q 'nvm install 22 && nvm use 22' '$T/out'" "with the command to fix it"
  check "grep -q 'then: bash .* --only review' '$T/out'" "and how to add it afterwards"
  check "grep -q 'tab 4 stays a plain shell for now' '$T/out'" "and what that means for the tabs"
  check "grep -qE '^ +lazygit +a git UI' '$T/out'" "lazygit is still on offer"
  cleanup
}

# ── the key collision ─────────────────────────────────────────────────────

test_herdr_config_frees_prefix_shift_a_for_hunk() {
  new_home
  wizard 'herdr_config'
  check "grep -qx 'previous_agent = \"prefix+shift+v\"' '$T/out'" "previous agent moves to prefix+shift+v"
  check "! grep -q 'prefix+shift+a' '$T/out'" "nothing of the wizard's is on prefix+shift+a"
  cleanup
}

test_cheat_sheet_and_tour_follow_the_new_key() {
  new_home
  wizard 'cheatsheet; tour_navigation; tour_agents'
  check "grep -q 'prefix \`a\` / \`Shift-V\`' '$T/out'" "cheat sheet: previous agent is Shift-V"
  check "grep -q 'prefix Shift-V' '$T/out'" "the tour names Shift-V"
  check "! grep -qE 'prefix a / A|prefix A goes back|/ \`A\` ' '$T/out'" "no mention of the old key"
  cleanup
}

# ── the review stage ──────────────────────────────────────────────────────

test_review_stage_installs_hunk_then_its_keys_then_reloads() {
  stage_setup v22.12.0
  review_run "$WRITE_HERDR_CONFIG; stage_review"
  local calls; calls=$(grep -vE '^plugin (list|config-dir)' "$T/herdr.log" | tr '\n' '|')
  check "[[ '$calls' == 'plugin install jhochenbaum/herdr-hunk-diff|plugin action invoke setup-keys --plugin $HUNK|server reload-config|' ]]" \
    "install, setup-keys, reload, in that order (got '$calls')"
  check "grep -qF '# BEGIN $HUNK' '$H/$CFG_REL'" "the plugin's keys are in the herdr config"
  check "grep -qx 'placement = \"overlay\"' '$H/.config/herdr/plugins/config/$HUNK/config.toml'" \
    "hunk's review opens over tab 4's pane, not beside it"
  check "journal_has PLUGIN $HUNK new" "the plugin is journaled as new"
  cleanup
}

test_the_herdr_config_is_rehashed_after_setup_keys() {
  stage_setup v22.12.0
  review_run "$WRITE_HERDR_CONFIG; stage_review"
  local last
  last=$(awk -F'\t' -v p="$H/$CFG_REL" '$3 == p { l = $NF } END { print l }' "$STATE/journal.tsv")
  check "[[ '$last' == '$(sha "$H/$CFG_REL")' ]]" "the journal's latest sha is the file with hunk's keys"
  check "journal_has CREATE '$H/$CFG_REL.hunkdiff-backup'" "the plugin's own backup file is journaled as created"
  cleanup
}

test_a_rerun_shows_no_spurious_diff() {
  stage_setup v22.12.0
  review_run "$WRITE_HERDR_CONFIG; stage_review"
  local before; before=$(sha "$H/$CFG_REL")
  printf 'n\nn\nn\n' > "$T/tty"   # refuse any replace prompt
  review_run "$WRITE_HERDR_CONFIG"
  check "grep -q 'unchanged: $H/$CFG_REL' '$T/out'" "the herdr stage keeps hunk's keys (got: $(head -3 "$T/out" | tr '\n' '|'))"
  check "! grep -q 'already exists and differs' '$T/out'" "no diff offered"
  review_run 'stage_review'
  check "[[ '$(sha "$H/$CFG_REL")' == '$before' ]]" "a second setup-keys changes nothing"
  check "[[ '$(grep -c '^plugin install' "$T/herdr.log")' == 1 ]]" "the plugin is installed once"
  check "[[ '$(grep -c 'PLUGIN' "$STATE/journal.tsv")' == 1 ]]" "and journaled once"
  cleanup
}

test_revert_restores_the_true_pre_wizard_herdr_config() {
  stage_setup v22.12.0
  mkdir -p "$H/.config/herdr"
  printf 'prefix = "ctrl+b"\n' > "$H/$CFG_REL"
  cp "$H/$CFG_REL" "$T/original"
  review_run "$WRITE_HERDR_CONFIG; stage_review"
  : > "$T/answers"
  review_run 'revert_all'
  same_bytes "$H/$CFG_REL" "$T/original" "the user's own herdr config is back"
  check "! grep -q 'kept your version' '$T/out'" "the plugin's edit isn't blamed on the user"
  check "[[ ! -e '$H/$CFG_REL.hunkdiff-backup' ]]" "the plugin's backup file is moved away"
  check "! grep -q 'unrecognised journal entry' '$T/out'" "the PLUGIN entry is understood"
  check "grep -q '$HUNK' '$T/out'" "revert says the plugin stays installed"
  cleanup
}

test_an_already_installed_hunk_is_not_reinstalled() {
  stage_setup v22.12.0
  touch "$T/hunk-installed"
  review_run "$WRITE_HERDR_CONFIG; stage_review"
  check "! grep -q '^plugin install' '$T/herdr.log'" "no second install"
  check "journal_has PLUGIN $HUNK pre-existing" "journaled as pre-existing"
  cleanup
}

test_review_stage_skips_hunk_when_node_is_too_old() {
  stage_setup v20.19.2 "$H/.nvm/versions/node/v20.19.2/bin"
  review_run "$WRITE_HERDR_CONFIG; stage_review; printf 'SKIPPED=%s\n' \"\${SKIPPED[@]}\""
  check "! grep -qsE '^plugin (install|action)' '$T/herdr.log'" "nothing is installed"
  check "grep -q 'nvm install 22 && nvm use 22' '$T/out'" "the fix is printed"
  check "grep -q 'SKIPPED=.*--only review' '$T/out'" "the closing summary says how to add it later"
  check "[[ -f '$H/.config/lazygit/config.yml' ]]" "lazygit is still set up"
  check "! journal_has PLUGIN $HUNK" "no plugin journaled"
  cleanup
}

test_no_default_tabs_leaves_hunk_placement_alone() {
  stage_setup v22.12.0
  review_run "DEFAULT_TABS=''; $WRITE_HERDR_CONFIG; stage_review"
  check "[[ ! -e '$H/.config/herdr/plugins/config/$HUNK/config.toml' ]]" "no tab 4, so hunk keeps its own placement"
  cleanup
}

run_tests "$@"
