# Changelog

## Unreleased

- Each stage checks the filesystem right before it runs and says what it will do to your files: `⚠ REPLACES 2 files you already have` with each path, where the copy goes and that `--revert` undoes it, then the files it only adds its own lines to (`~/.zshrc`, `~/.zprofile`, Neovim's `autocmds.lua`, `~/.claude/settings.json`), and how many files are new. A file the wizard wrote on an earlier run and you have not touched since is not called yours. A non-LazyVim `~/.config/nvim` is named as a folder replaced whole
- After the `choices` stage, one plan for the whole run: how many tools it installs, which of your files it replaces, the points where it needs you (the Xcode tools dialog, relaunch into Ghostty, free Ctrl-Space, allow notifications, allow accessibility, the first Neovim launch, the GitHub login, each only when it applies to this run) and the `--revert` promise. Then one `Go? [y/N]`. No writes no files (your answers are still saved). A run without the `choices` stage, such as `--only editor`, shows the per-stage badges but no plan
- New `--yes` flag for re-runs, alone or with `--from`, `--only` or `--skip`: it reuses the saved answers, shows the plan without asking for Go, installs the herdr hooks for Claude Code and Codex without asking, makes the pauses between stages no-ops and skips the tour (unless `--only tour`). What only you can do still waits: the Xcode tools dialog, relaunching into Ghostty, Ctrl-Space, notifications, accessibility, the GitHub login, the first Neovim launch and the Nerd Font check. Replacing a file that differs (or a non-LazyVim `~/.config/nvim`) still shows what it is and asks
- Tests: `bash tests/plan_test.sh`

- The `choices` stage now starts with what to install. Ghostty, herdr and terminal-notifier are always installed. Everything else is one checkbox per group of tools that need each other, each tool listed with what it gives you: Nerd Font + icons (the icons switch), starship prompt, project jumper + fuzzy find (fzf, fd, eza, bat), shell typing help (zsh-autosuggestions, zsh-syntax-highlighting), editor (Neovim, LazyVim, tree-sitter-cli, ripgrep, fd), review (lazygit), file manager (yazi, poppler, resvg), GitHub (gh, gh-dash) and the Claude Code status line (jq comes with it). All are ticked to start with; type numbers to untick. The answer is saved as `TOOLS` in `choices.env`
  - An unticked group is not installed and its stage does not run. `Stage 3/9` counts only the stages you picked, and `--only` or `--from` on one you declined says so instead of running it
  - The `shell` stage always runs, since its blocks also carry Ghostty's shell integration, history, `keys` and the other groups' lines, but `~/.zshrc` and `~/.zprofile` only get lines for what you picked. herdr only gets popup keys for installed tools (prefix m projects, d lazygit, f yazi, i gh-dash), and so do Ghostty's matching Cmd-O, Cmd-E and Cmd-Shift-G. The `keys` cheat sheet lists only what you picked. The projects folder is only asked with the project jumper. The status line stage no longer asks a second time
- Cut: git-delta, difftastic, zoxide, btop, glow, jless and tlrc. The wizard no longer writes any `~/.gitconfig` settings (pager, diff tools, `gds`, `git dft`/`dlog`/`dshow`), lazygit uses its built-in diff view, herdr's `prefix t` btop popup is gone, and `keys` shows the cheat sheet with bat (or less without it). `--revert` still undoes git settings written by earlier versions
- Tests: `bash tests/selection_test.sh`
- 27 stages become 13, each with a name: `choices`, `install`, `ghostty`, `herdr`, `macos`, `prompt`, `shell`, `editor`, `review`, `yazi`, `github`, `statusline`, `tour`
  - `choices` asks every question first (icons, projects folder, default tabs) and saves the answers in `~/.ghostty-herdr-wizard/choices.env`. A re-run shows last time's answers and offers to use them
  - `install` brews everything in one go, leaving out the tools of stages you `--skip`. A stage run on its own with `--only` still brews the formulae it needs (casks such as Ghostty and the Nerd Font come only from `install`)
  - Ghostty's install, config, relaunch and herdr auto-start are one `ghostty` stage. Freeing Ctrl-Space, the herdr config and the Claude Code and Codex hooks are one `herdr` stage. delta, difftastic and lazygit are one `review` stage. The nine tour steps are one `tour` stage
- `--from`, `--only` and `--skip` take stage names instead of numbers, e.g. `--only herdr,macos` or `--skip yazi,github`. An unknown name (or an old number) is rejected with the list of names. `--list` prints the names. `--tour` is `--only tour`
- Tests: `bash tests/stages_test.sh`
- New "Nerd Font + icons" choice in the `choices` stage, saved in `~/.ghostty-herdr-wizard/choices.env` so later runs and `--only` reuse it. Icons (the default) keeps today's setup. Plain text skips the Nerd Font and makes every consumer glyph-free: herdr's sidebar uses `dots`, eza drops `--icons` (aliases and the `p` / prefix m preview), starship uses its `plain-text-symbols` preset, yazi replaces every glyph in its default theme (icons, separators, notification and completion icons), Neovim uses ASCII file icons, letters for LazyVim's diagnostics and git signs, no completion-kind icons and plain lualine separators, lazygit turns off Nerd Font icons, the Claude Code status line drops its icons, and Ghostty keeps its built-in font. Re-run the wizard after changing it to rewrite those configs
- Tests: `bash tests/glyphs_test.sh`
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
- New workspaces and worktrees open with a standard set of tabs: `agents`, `source code`, `local server` and `git review`. Implemented as a herdr plugin on the `workspace.created` and `worktree.created` events. The `choices` stage asks about them once: it explains tabs, shows the four with what each is for, then offers 1) use these four, 2) same idea, my names (rename each, Enter keeps it), 3) no default tabs. The answer is saved in `choices.env`, so a re-run offers it as the default
- When herdr-hunk is installed, tab 4 opens straight into its review (`herdr plugin action invoke review`), then focus returns to tab 1. Without it, tab 4 is a plain shell with the same label. The review tab is set by `review_tab=4` in `apply-tab-layout.sh`. The review fills tab 4 only when hunk's `review.placement` is `overlay`; the wizard sets that once it installs herdr-hunk itself
- Tests: `bash tests/tabs_test.sh`
- New keybindings: prefix `Shift-O` opens an existing worktree, prefix `Shift-K` deletes a worktree checkout
- Themes are now always dark (Catppuccin Mocha) across Ghostty, herdr, bat, nvim and yazi, instead of following macOS light/dark

## 1.0.0 (2026-09-14)

First public release.

- 27-stage wizard: Ghostty and Nerd Font, CLI toolbelt, Starship prompt, shell setup, delta/difftastic/lazygit, GitHub CLI and gh-dash, LazyVim, yazi, herdr with Claude Code and Codex hooks, macOS permissions, optional Claude Code status line
- 9-stage guided tour of the daily workflow
- `--list`, `--from`, `--only`, `--skip` and `--tour` flags
- Asks for your projects folder instead of assuming one
- Diffs and backups before replacing any existing file
