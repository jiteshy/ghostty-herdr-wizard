# Changelog

## Unreleased

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
