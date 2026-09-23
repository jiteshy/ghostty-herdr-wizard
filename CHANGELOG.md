# Changelog

## Unreleased

- `--revert` puts back the Ghostty config the wizard replaced, byte for byte. The first slice of full revert: other stages are not recorded yet
- The wizard now keeps its state in `~/.ghostty-herdr-wizard/`: an append-only `journal.tsv` of what it changed, and a `backups/` store that captures each file only the first time the wizard ever touches it. Previously each run made a new timestamped backup folder, so a second run backed up the wizard's own output from the first run as if it were yours. Backups from earlier versions stay in `~/.ghostty-herdr-wizard-backups/` and are not migrated, so `--revert` only knows originals captured from now on
- A file the wizard replaces that has changed since the wizard last wrote it (for example you edited it) is also kept, under `~/.ghostty-herdr-wizard/replaced/<run time>/`, so first-ever-wins never drops your later edits. A non-LazyVim `~/.config/nvim` is moved into the backup store at its mirrored path
- Tests: `bash tests/journal_test.sh`
- New workspaces and worktrees open with a standard set of tabs (agents, code, dev server, git review). The herdr stage asks whether you want them and lets you replace the list with your own. Implemented as a herdr plugin on the `workspace.created` and `worktree.created` events
- New keybindings: prefix `Shift-O` opens an existing worktree, prefix `Shift-K` deletes a worktree checkout
- Themes are now always dark (Catppuccin Mocha) across Ghostty, herdr, bat, nvim and yazi, instead of following macOS light/dark

## 1.0.0 (2026-09-14)

First public release.

- 27-stage wizard: Ghostty and Nerd Font, CLI toolbelt, Starship prompt, shell setup, delta/difftastic/lazygit, GitHub CLI and gh-dash, LazyVim, yazi, herdr with Claude Code and Codex hooks, macOS permissions, optional Claude Code status line
- 9-stage guided tour of the daily workflow
- `--list`, `--from`, `--only`, `--skip` and `--tour` flags
- Asks for your projects folder instead of assuming one
- Diffs and backups before replacing any existing file
