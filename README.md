# ghostty-herdr-wizard

**One bash script sets up a Mac terminal that runs your coding agents.**

The script installs and configures the terminal, the tools and the agent integrations. It then shows you how to use them.

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
- **Shell (bottom right).** The prompt shows the folder and the git branch.

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
bash ghostty-herdr-wizard.sh --list                # show the steps by name
bash ghostty-herdr-wizard.sh --skip yazi,github    # do not do these steps
bash ghostty-herdr-wizard.sh --from editor         # start at the editor step
bash ghostty-herdr-wizard.sh --only statusline     # do only this step
bash ghostty-herdr-wizard.sh --tour                # do the tour again
bash ghostty-herdr-wizard.sh --yes                 # re-run with last time's answers, no pauses
bash ghostty-herdr-wizard.sh --revert              # undo every config change
bash ghostty-herdr-wizard.sh --uninstall           # revert, then offer to remove each tool it installed
```

With `--yes`, the steps that only you can do still wait for you: relaunching into Ghostty, allowing notifications and accessibility, and freeing Ctrl-Space. The script also still asks before it replaces a file you have changed.

## What the script does

The script has up to 13 steps, one for each group of tools you pick. Each step has a name, tells you what it will do, and waits for you.

The script does three types of work:

1. It installs software with Homebrew.
2. It writes config files. If a file exists and is different, the script shows you the changes and asks you first. It keeps a copy of the old file in `~/.ghostty-herdr-wizard/backups/`.
3. It tells you what to do for the steps that need a person. Examples: approve a macOS permission, or sign in to GitHub.

**`choices`.** All the questions come first. First, what to install: Ghostty, herdr and terminal-notifier always, then one checkbox per group of tools that need each other (Nerd Font + icons, starship prompt, project jumper + fuzzy find, shell typing help, editor, review (lazygit and herdr-hunk), file manager, GitHub, Claude Code status line). All are ticked to start with. A group you untick is not installed and its step is skipped. Unticking icons gives plain text, which works in any font, so nothing shows as boxes in a terminal without a Nerd Font. Then herdr's prefix key (Ctrl-Space by default, Ctrl-B needs no macOS changes but clashes with Claude Code), the colour mode for Ghostty, herdr, Neovim and yazi (follow the system, always dark, or leave your themes alone), and the prompt style (plain pure or powerline Tokyo Night, both showing only folder and git branch, or leave your prompt alone). Then the folder with your repos (only with the project jumper), and the tabs that new workspaces open with. The answers are saved, and the next run offers to use them again. Then the script shows its plan: how many tools it installs, which of your files it replaces, and the points where it needs you. Nothing happens until you say yes.

Each step checks your files right before it runs. If it is about to replace a file you already have, it says so and names the file. A copy goes to `~/.ghostty-herdr-wizard/backups/`, and `--revert` puts it back. See [Undoing it](#undoing-it) for what `--revert` and `--uninstall` can and cannot undo.

**`install`.** Install everything with Homebrew in one go: Ghostty, herdr and the tools you picked. Tools of steps you skip with `--skip` are not installed.

**`ghostty`, `herdr`, `macos`: the terminal and the agents.** Write the Ghostty config: the Catppuccin theme in your colour mode, Cmd keys that control herdr, and herdr in every new window. Make the prefix key free for herdr (skipped with Ctrl-B), write its config, and connect Claude Code and Codex to it, so their conversations continue after a restart. Set up notifications and the quick terminal.

**`prompt`, `shell`: the shell.** Set up the Starship prompt in your chosen style. Add history search, aliases for `bat`, `eza`, `fzf` and the other command-line tools, and a command that finds and opens your repos.

**`editor`, `review`, `yazi`, `github`: code and git.** Neovim with LazyVim, `lazygit` to stage and commit, herdr-hunk to review the agent's diff hunk by hunk and send your comments back to it, `yazi` to browse files, and the GitHub CLI with `gh-dash` for pull requests. herdr-hunk needs Node 22.12 or newer. The wizard checks your Node but never installs or upgrades it.

**`statusline`.** Add the Claude Code status line.

**`tour`.** Short screens built from what you installed: five for a minimal setup, up to ten with every tool. You open repos, start agents, split panes and tabs, and close and resume everything. Then, for each tool you chose, one screen on it: Neovim next to your agent, reviewing Claude's change, yazi, gh-dash and the status line. The tour teaches you the keys while you use them. Press `s` at any screen to skip the rest. Type `keys` later to see the full list.

## Undoing it

`--revert` undoes the config changes the wizard recorded in `~/.ghostty-herdr-wizard/journal.tsv`. Files it replaced come back as they were. Files and folders it created are moved to `~/.ghostty-herdr-wizard/reverted/`, never deleted, and `--revert --restore` puts them back. Where it only added its own lines to a file, such as `~/.zshrc`, `~/.zprofile` or Neovim's `autocmds.lua`, those lines are removed and yours stay. In `~/.claude/settings.json` (and `~/.gitconfig`, which older versions wrote to) only the keys it set go back to what they were. If you changed a file after the wizard wrote it, `--revert` shows you the diff and keeps your version unless you say otherwise.

What `--revert` cannot undo:

- **System Settings.** The wizard never changes these itself, so it cannot change them back. At the end, `--revert` prints a checklist of the ones you changed during setup and offers to open each settings pane: turn the Ctrl-Space input source shortcuts back on, turn off notifications for terminal-notifier, and turn off Ghostty's Accessibility access. You do these by hand.
- **Installed tools.** They stay, and so do herdr plugins such as herdr-hunk. `--uninstall` runs the revert first, then asks about each tool the wizard installed, one at a time. Tools you already had are never offered, and Node is never touched.
- **What the tools save for themselves.** Your GitHub sign-in, Neovim's downloaded plugins under `~/.local/share/nvim`, and herdr's saved sessions are not wizard config, so they stay.
- **Runs from before the journal.** Backups from 1.0.0 are in `~/.ghostty-herdr-wizard-backups/`. `--revert` does not know about them.

## Tests

Unit-style checks live in `tests/`, one file per area: `journal_test.sh` (journal, backups, `--revert`), `selection_test.sh` (the choices screen), `stages_test.sh` (named stages), `plan_test.sh` (REPLACES badges and the plan), `glyphs_test.sh` (the icons switch), `tabs_test.sh` (default tabs), `review_test.sh` (herdr-hunk), `prefix_theme_test.sh` (prefix and colour), `prompt_test.sh` (prompt styles), `uninstall_test.sh` (`--uninstall`), `tour_test.sh` (the tour built from your choices), and `revert_acceptance_test.sh`. Run one with e.g. `bash tests/journal_test.sh`.

`bash tests/revert_acceptance_test.sh` is the revert acceptance test: it snapshots a throwaway home, runs the whole wizard with everything selected (only the `macos` and `tour` steps are skipped, because those need a person), runs `--revert`, and diffs the home against the snapshot, for both a pristine and a seeded home. Run it before any change to the revert path.

## Thanks

1. Matt Pocock's [wizard skill](https://www.aihero.dev/skills-wizard) made this script. The skill makes a coding agent write a setup wizard for you. The template comes from [his skills collection](https://github.com/mattpocock/skills). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

2. [Harshal Tripathi](https://github.com/harshalstory) for the inspiration to explore ghostty & herdr.

## License

[MIT](LICENSE)
