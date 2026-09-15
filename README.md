# ghostty-herdr-wizard

**Run all your coding agents, across all your repos, from one terminal window. Set up with a single bash script.**

Claude Code in one pane, Codex in another, a dev server in the next tab, and every repo you work on one keystroke away. You never leave the terminal, and nothing stops when you close the window.

This repo turns a Mac into that setup, using [Ghostty](https://ghostty.org) and [herdr](https://herdr.dev).

![Ghostty and herdr running Claude Code and Codex side by side across several repos](docs/images/screenshot.png)

## What you're looking at

- **Spaces (top left):** each repo is its own workspace. Jump between them instantly. `spine` also has a git worktree under it, so a second agent can work on a separate branch without clashing.
- **Agents (bottom left):** every agent running in any repo, in one list. You can see at a glance which are busy and which are waiting for you, and you get a notification when one needs you.
- **Tabs (top):** `agents`, `code`, `dev server` and `git review`. Each repo keeps its own tabs, so every view stays exactly where you left it.
- **Claude Code (left pane):** with a status line showing the model, effort, folder, context used, session cost and your 5-hour and weekly limits.
- **Codex (top right):** a second agent working on the same repo.
- **Shell (bottom right):** a clean, colourful prompt with your folder, git branch and the time.

Close Ghostty and everything keeps running. Open it again and you're right back where you left off, even after a reboot.

## Set it up

You need a Mac and [Homebrew](https://brew.sh). Then run:

```bash
git clone https://github.com/jiteshy/ghostty-herdr-wizard.git
cd ghostty-herdr-wizard
bash ghostty-herdr-wizard.sh
```

That's it. The script walks you through everything, one step at a time:

- It installs and configures the tools for you.
- It tells you exactly what to click for the few things only you can do, like macOS permissions.
- It shows you a diff and makes a backup before changing any file you already have.
- It finishes with a short hands-on tour, so you learn the keys by using them.

It takes about 20 to 30 minutes, mostly downloads. Safe to run again at any time.

Handy options:

```bash
bash ghostty-herdr-wizard.sh --list          # see every step
bash ghostty-herdr-wizard.sh --skip 11,13    # leave out steps you don't want
bash ghostty-herdr-wizard.sh --tour          # replay the tour
```

## What you get

**A terminal built for agents**
- Ghostty with a Nerd Font and a theme that follows macOS light and dark mode
- herdr: one workspace per repo, tabs, split panes, and an agent list across everything
- Sessions that survive closing the window and come back after a reboot
- macOS notifications when an agent finishes or needs your answer
- Claude Code and Codex connected to herdr, so conversations resume where they left off
- Git worktrees in one keystroke, so agents can work in parallel on the same repo
- A Claude Code status line with context, cost and usage limits
- A drop-down terminal from any app (Ctrl-\`)

**See and review every change**
- Clear, colour-highlighted git diffs, side by side when you want
- lazygit to stage, commit and undo changes in a popup
- Neovim (LazyVim) that reloads files as agents edit them, with a full review view for all changes
- Your GitHub pull requests and issues in the terminal

**A nicer shell**
- A pastel powerline prompt that's easy to read in light and dark mode
- Fuzzy search for history, files and projects
- A file browser with previews, plus friendlier `ls` and `cat`
- A cheat sheet one command away: `keys`

## Built with Matt Pocock's wizard skill

This script was created with Matt Pocock's [wizard skill](https://www.aihero.dev/skills-wizard), which has a coding agent write a step-by-step setup wizard for you instead of a setup guide. The wizard's template comes from [his skills collection](https://github.com/mattpocock/skills). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

[MIT](LICENSE)
