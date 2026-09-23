# herdr-hunk review stage: Node gate, setup-keys, key collision

Status: ready-for-agent

## What to build

The one git tool that survives the cut, installed as a multiplexer plugin rather than a brew formula, with two real obstacles to handle.

**Node prerequisite, detected but never touched.** The plugin requires a Node version newer than what the development machine currently runs, so this is not a hypothetical branch. Installing Node via brew is not an option: Node is usually managed outside brew by a version manager, a brew-installed Node alongside one of those creates a resolution mess, and a global upgrade breaks projects pinned to an older version. Neither is something the revert can undo, because a version manager's state is not a file the wizard backed up.

Check the version **during selection**, not halfway through the install. If it is too old or absent, grey the item out in the picker and show: what version is required, what version is present, which version manager appears to be in use, the exact command for that manager, and the single command to re-run just this stage afterwards. The run continues; tab 4 falls back to a plain shell.

**Keybinding collision.** The plugin's key-setup action claims a chord that the wizard's own config already assigns to cycling backwards through agents. That binding must move to a free chord before the plugin is installed.

**Config file ownership.** The key-setup action writes into the multiplexer's config file, which the wizard owns as a whole file. Left alone, this means a second run shows a diff and offers to replace the file, wiping the plugin's bindings, while the revert drift-check blames the user for an edit the plugin made.

Resolution: let the plugin own its binding syntax, then re-absorb the result. Write the config with the conflicting binding moved, install the plugin, run its key-setup action, re-hash the resulting file into the journal as the wizard's new baseline, then reload the running server. Hand-writing the bindings instead would mean guessing at a syntax upstream can change; re-absorbing costs one hash.

Revert is unaffected either way, since it restores the user's true pre-wizard config.

## Acceptance criteria

- [ ] The Node version is checked during selection, before any install begins
- [ ] An insufficient version greys the item out with required version, present version, detected version manager, its upgrade command, and the re-run command
- [ ] An insufficient version never blocks or aborts the rest of the run
- [ ] Node is never installed, upgraded, or modified by any code path
- [ ] The conflicting agent-cycling binding is moved to a free chord before the plugin is installed
- [ ] No two actions share a chord in the resulting config, verified by the multiplexer's own config check
- [ ] The plugin's key-setup action is invoked rather than its bindings being hand-written
- [ ] After key-setup, the config file is re-hashed into the journal
- [ ] A second full run shows no diff on the config file and does not offer to replace it
- [ ] Revert restores the user's pre-wizard config regardless of the plugin's edits
- [ ] The running server picks up the new config without a restart
- [ ] The plugin is journaled so uninstall removes it

## Blocked by

- `06-choices-stage-and-tool-picker`
- `09-tab-layout-and-prompt`
