# Changelog

## Unreleased

- `--revert` undoes every config change the wizard made, in every stage. Installed tools stay (removing them is a later `--uninstall`)
  - Replaced files come back byte for byte. Files and folders the wizard created are moved to `~/.ghostty-herdr-wizard/reverted/<time>/`, never deleted, including a LazyVim `~/.config/nvim` you have since filled with your own plugins
  - A file you changed after the wizard wrote it is shown as a diff and only reverted if you say so. By default your version is kept, and the closing summary lists it
  - The marked blocks in `~/.zshrc`, `~/.zprofile` and Neovim's `autocmds.lua` are stripped exactly, leaving every line of yours around them untouched
  - `~/.claude/settings.json` and `~/.gitconfig` are reverted key by key, so permissions Claude Code has saved since, your model choice and your own git settings stay as they are
  - What only System Settings can undo (Ctrl-Space for input sources, notification permission, Ghostty's Accessibility access) is printed as a numbered checklist that opens each settings pane. The wizard never writes those settings itself
  - A running herdr reloads the restored config straight away
- `--revert --restore` moves what the last `--revert` took away back into place
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
