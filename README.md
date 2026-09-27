# ghostty-herdr-wizard

**One bash script sets up a Mac terminal that runs your coding agents.**

The script installs and configures the terminal, the tools and the agent integrations. It then shows you how to use them.
test change
After it runs, you can:

- keep every repo open in the same window, and move between them with one key
- run Claude Code and Codex next to each other, and see which agent waits for you
- get a macOS notification when an agent finishes or needs an answer
- close the terminal without stopping your agents, tests or dev servers
- read code, review diffs and commit, without a browser or an editor window

[Ghostty](https://ghostty.org) is the terminal. [herdr](https://herdr.dev) keeps the sessions running in the background.

![Ghostty and herdr running Claude Code and Codex side by side across several repos](docs/images/screenshot.png)

## The screen, part by part

- **Spaces (top left).** Each repo is one workspace. Select a repo to go to it. The `spine` repo also shows a git worktree. A second agent works there on a different branch.
- **Agents (bottom left).** This list shows all agents in all repos. A mark on each row tells you if the agent works, waits for you, or is idle.
- **Tabs (top).** This repo has four tabs: `agents`, `code`, `dev server` and `git review`. Each repo keeps its own tabs.
- **Claude Code (large pane).** The two lines at the bottom show the model, the effort, the folder, the context used, the cost of the session, and your 5-hour and weekly limits.
- **Codex (top right).** A second agent works in the same repo.
- **Shell (bottom right).** The prompt shows the folder, the git branch and the time.

If you close Ghostty, the agents continue. When you open Ghostty again, your layout comes back. It also comes back after you restart the Mac.

## Install

You need a Mac and [Homebrew](https://brew.sh). Run these commands:

```bash
git clone https://github.com/jiteshy/ghostty-herdr-wizard.git
cd ghostty-herdr-wizard
bash ghostty-herdr-wizard.sh
```

The setup takes 20 to 30 minutes. Most of that time is downloads.

You can run the script again at any time. It does not repeat work that is complete.

```bash
bash ghostty-herdr-wizard.sh --list          # show all the steps
bash ghostty-herdr-wizard.sh --skip 11,13    # do not do these steps
bash ghostty-herdr-wizard.sh --from 12       # start at step 12
bash ghostty-herdr-wizard.sh --tour          # do the tour again
```

## What the script does

The script has 27 steps. Each step shows its number, tells you what it will do, and waits for you.

The script does three types of work:

1. It installs software with Homebrew.
2. It writes config files. If a file exists and is different, the script shows you the changes and asks you first. It keeps a copy of the old file in `~/.ghostty-herdr-wizard-backups/`.
3. It tells you what to do for the steps that need a person. Examples: approve a macOS permission, or sign in to GitHub.

**Steps 1 to 5: the terminal.** Install Ghostty. Choose icons (installs the JetBrains Mono Nerd Font) or plain text, which works in any font, so nothing shows as boxes in a terminal without a Nerd Font. Write the Ghostty config: the Catppuccin Mocha dark theme, and Cmd keys that control herdr. Make the Ctrl-Space key free for herdr.

**Steps 6 to 8: the shell.** Install command-line tools: `bat`, `eza`, `fd`, `ripgrep`, `fzf`, `zoxide`, `glow`, `jless`, `btop` and `tldr`. Set up the Starship prompt. Add history search, aliases, and a command that finds and opens your repos.

**Steps 9 to 13: code and git.** Install `delta` and `difftastic` for clear diffs, `lazygit` to stage and commit, the GitHub CLI with `gh-dash` for pull requests, Neovim with LazyVim, and `yazi` to browse files.

**Steps 14 to 18: the agents.** Install herdr and write its config. Connect Claude Code and Codex to herdr, so their conversations continue after a restart. Make Ghostty open herdr. Set up notifications. Add the Claude Code status line.

**Steps 19 to 27: the tour.** Nine short steps. You open repos, start agents, split panes, let Claude change a file, review the change, and close and resume everything. The tour teaches you the keys while you use them. Type `keys` later to see the full list.

## Thanks

1. Matt Pocock's [wizard skill](https://www.aihero.dev/skills-wizard) made this script. The skill makes a coding agent write a setup wizard for you. The template comes from [his skills collection](https://github.com/mattpocock/skills). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

2. [Harshal Tripathi](https://github.com/harshalstory) for the inspiration to explore ghostty & herdr.

## License

[MIT](LICENSE)
