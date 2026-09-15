# ghostty-herdr-wizard

An interactive setup wizard that turns a Mac into a terminal-first workspace for software development with coding agents. You get [Ghostty](https://ghostty.org) with a Nerd Font, [herdr](https://herdr.dev) managing one workspace per repo with Claude Code and Codex sessions side by side, readable git diffs, LazyVim for reading and reviewing code, and a guided tour that teaches the whole thing hands-on.

![Pastel powerline prompt: Apple logo, folder, git branch, Node version, time](docs/images/prompt.png)

It's a single bash script. It installs with Homebrew, writes config files, walks you through the few steps only a human can do (macOS permissions, GitHub login), and shows a diff and keeps a backup before it touches anything you already have.

## What you get

**Terminal**
- Ghostty with JetBrains Mono Nerd Font and Catppuccin colours that follow macOS light/dark mode
- A drop-down quick terminal on Ctrl-\` from any app
- Cmd shortcuts that drive herdr (Cmd-D split, Cmd-T tab, Cmd-1…9 switch tab, Cmd-P go to anything)

**Agents across repos**
- herdr runs every terminal in a background server: close Ghostty and your agents, dev servers and tests keep running
- One workspace per repo, opened with a fuzzy project picker (prefix `m`)
- A sidebar showing which agent is working, idle or waiting for you, plus macOS notifications when one needs you
- herdr hooks for Claude Code and Codex, so conversations resume after a reboot
- The herdr skill for Claude Code, so Claude can start a dev server in a side pane or wait for tests itself
- Git worktrees from herdr, so two agents can work on the same repo without clashing

**Git and code review**
- delta for syntax-highlighted diffs, difftastic for structural diffs (`git dft`)
- lazygit in a popup, with delta and difftastic as switchable renderers
- LazyVim with TypeScript, Tailwind, ESLint, Prettier, JSON and Markdown support out of the box; add Python, Go, Rust and other languages with `:LazyExtras`
- Neovim tuned for working next to agents: files an agent edits reload by themselves, and Diffview reviews all changes (`Space g v`)
- gh-dash for pull requests and issues in the terminal

**Shell and prompt**
- Starship pastel powerline prompt (Apple logo, folder, git branch, runtime version, time), recoloured so text is readable in both light and dark mode
- fzf history and file search, zoxide, eza, bat, yazi, jless, btop, tldr
- An optional two-line Claude Code status line: model, effort, directory, worktree, context used, session cost, and 5-hour and weekly rate limits

## Requirements

- macOS (tested on macOS 15)
- [Homebrew](https://brew.sh)
- About 20 to 30 minutes, most of it downloads
- Optional: [Claude Code](https://code.claude.com), [Codex CLI](https://github.com/openai/codex), a GitHub account

## Quick start

```bash
git clone https://github.com/jiteshy/ghostty-herdr-wizard.git
cd ghostty-herdr-wizard
bash ghostty-herdr-wizard.sh
```

Run it from any terminal. After installing Ghostty it asks you to continue inside Ghostty (the command is copied to your clipboard), because later stages need you to look at fonts, colours and shortcuts.

Don't pipe it into `bash` from `curl`: the wizard reads your answers from the keyboard.

## How the wizard works

The script moves through 27 stages. Each one clears the screen, says what it's about to do, and shows progress (`Stage 7/27`).

| # | Stage | # | Stage |
|---|---|---|---|
| 1 | Preflight | 15 | Connect herdr to Claude Code and Codex |
| 2 | Install Ghostty and JetBrains Mono Nerd Font | 16 | Ghostty: open herdr automatically |
| 3 | Ghostty config | 17 | macOS permissions: notifications and quick terminal |
| 4 | Move into Ghostty | 18 | Claude Code status line (optional) |
| 5 | Free up Ctrl-Space for herdr | 19 | Tour 1/9: land in herdr, one workspace per repo |
| 6 | CLI toolbelt | 20 | Tour 2/9: moving around |
| 7 | Starship prompt (pastel powerline) | 21 | Tour 3/9: run and juggle agents |
| 8 | Shell: history search, aliases, project jumper | 22 | Tour 4/9: tabs inside one repo |
| 9 | Git diffs: delta and difftastic | 23 | Tour 5/9: Neovim next to your agent |
| 10 | lazygit | 24 | Tour 6/9: Claude edits, you review |
| 11 | GitHub CLI and gh-dash | 25 | Tour 7/9: reading the status line |
| 12 | Neovim + LazyVim | 26 | Tour 8/9: close anything, pick up later |
| 13 | yazi file manager | 27 | Tour 9/9: daily habits |
| 14 | herdr | | |

### Safe to run, safe to re-run

- **Diff before overwrite.** If a config file already exists and differs, you see the diff and choose whether to replace it.
- **Backups.** Anything replaced is copied to `~/.ghostty-herdr-wizard-backups/<timestamp>/` first.
- **Marked blocks.** `~/.zshrc`, `~/.zprofile` and Neovim's `autocmds.lua` get a block between `>>> ghostty-herdr-wizard >>>` markers. Everything outside the markers is left alone, and re-runs replace only the block.
- **Idempotent.** Installed tools are skipped and identical files report `unchanged`, so re-running is quick.

### Flags

```bash
bash ghostty-herdr-wizard.sh --list            # print the stages
bash ghostty-herdr-wizard.sh --from 12         # start at stage 12
bash ghostty-herdr-wizard.sh --only 14,16,17   # run just these stages
bash ghostty-herdr-wizard.sh --skip 11,13      # everything except GitHub and yazi
bash ghostty-herdr-wizard.sh --tour            # replay the guided tour
```

## Design decisions

These came out of real use, and each one fixes a problem that isn't obvious up front.

**herdr's prefix is Ctrl-Space, not Ctrl-B.** Claude Code uses Ctrl-B to send a running command to the background. Stage 5 turns off the macOS shortcut that claims Ctrl-Space for switching input sources.

**Every Ghostty window goes through a small launcher.** `~/.local/bin/ghostty-launch` attaches herdr if no herdr window is open anywhere, and opens a plain shell otherwise. Opening Ghostty always lands you in herdr, and Cmd-N while herdr is open is your "without herdr" shortcut. Ghostty's `initial-command` isn't enough on its own: closing a Mac app's last window doesn't quit the app, so windows reopened from the Dock would skip herdr.

**Cmd-1…9 use physical key names.** Ghostty 1.3 ships `cmd+digit_1=goto_tab:1`, which wins over a `cmd+1` binding. The wizard binds `cmd+digit_N` so the keys reach herdr.

**Notifications go through terminal-notifier.** Ghostty drops notification banners while its own window is focused, and herdr lives in that window. herdr's `system` delivery posts through `terminal-notifier` instead, so banners always appear, and clicking one brings Ghostty forward. herdr doesn't notify you about the tab you're already looking at.

**Shell aliases skip agent shells.** `ls`→eza and `cat`→bat are nice for humans, but Claude Code copies your aliases into its own shell, where `cat -v` or `ls -lt` would break. The aliases are skipped when `CLAUDECODE` is set.

**The prompt uses fixed text colours.** The pastel powerline preset only sets backgrounds, so text takes the terminal's default colour and is hard to read in both modes. Each segment gets white or near-black text, and its background is shifted to reach at least 5:1 contrast.

## Everyday keys

**prefix** is Ctrl-Space: press it, release, then press the key. Run `keys` in any shell for the full cheat sheet.

| Keys | Action |
|---|---|
| prefix `m` · Cmd-O | open a repo as a workspace |
| prefix `,` / `.` · Cmd-Shift-[ / ] | previous / next workspace |
| prefix `g` · Cmd-P | go to any workspace, tab or agent |
| prefix `a` / `A` | next / previous agent |
| Cmd-T · Cmd-1…9 | new tab · switch tab |
| Cmd-D · Cmd-Shift-D | split right · split down |
| prefix `h j k l` · prefix `Space` | move between panes · back to last pane |
| prefix `z` · prefix `x` | zoom pane · close pane |
| prefix `d` · `f` · `i` · `t` | lazygit · yazi · GitHub PRs · btop |
| prefix `Shift-G` | new git worktree for a parallel agent |
| prefix `q` | detach (everything keeps running); `herdr` reattaches |

## Where things live

| File | Written by stage |
|---|---|
| `~/.config/ghostty/config` | 3, 16 |
| `~/.local/bin/ghostty-launch` | 16 |
| `~/.config/starship.toml` | 7 |
| `~/.zprofile`, `~/.zshrc` (marked blocks), `~/.local/bin/hproj` | 8 |
| global git config | 9 |
| lazygit `config.yml` | 10 |
| `~/.config/nvim` (LazyVim starter plus extras, Diffview, auto-reload) | 12 |
| `~/.config/yazi/theme.toml` | 13 |
| `~/.config/herdr/config.toml` | 14 |
| `~/.claude/settings.json` hooks, `~/.claude/skills/herdr/SKILL.md` | 15 |
| `~/.claude/statusline.sh`, `statusLine` in `~/.claude/settings.json` | 18 |
| `~/.config/ghostty-herdr-cheatsheet.md` (opened by `keys`) | 8 |

To customise, edit these files directly. A later re-run shows your edits as a diff and asks before replacing them. To make a change permanent for re-runs, edit the matching stage in the script.

## Undoing it

- **Restore a file:** copy it back from `~/.ghostty-herdr-wizard-backups/<timestamp>/`. Files are named after their path, e.g. `.config_ghostty_config`.
- **Stop Ghostty auto-starting herdr:** delete the `command = ...ghostty-launch` line from `~/.config/ghostty/config`.
- **Remove the shell setup:** delete the marked blocks from `~/.zshrc` and `~/.zprofile`.
- **Remove the status line:** delete the `statusLine` key from `~/.claude/settings.json`.
- **Remove herdr's agent hooks:** `herdr integration uninstall claude` (and `codex`).
- **Uninstall tools:** `brew uninstall` or `brew uninstall --cask` the ones you don't want.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Icons show as boxes | Quit Ghostty fully (Cmd-Q) and reopen it. Fonts load at app start. |
| Ctrl-Space does nothing in herdr | System Settings → Keyboard → Keyboard Shortcuts → Input Sources: untick both shortcuts. |
| Ghostty opens a plain shell | herdr is probably open in another window. Otherwise check `~/.config/ghostty/config` has the `command = ...ghostty-launch` line and reload with Cmd-Shift-,. |
| No notifications | Run stage 17 (`--only 17`). Allow terminal-notifier in System Settings → Notifications. Check Focus mode is off. After first setup, detach with prefix `q` and run `herdr` once so the client picks up Homebrew's PATH. |
| Cmd-1…9 or Cmd-D do nothing | Reload Ghostty (Cmd-Shift-,). Run `ghostty +list-keybinds` and look for a built-in binding on the same physical key. |
| herdr config errors | `herdr config check` |

## Tested with

macOS 15.7, Ghostty 1.3.1, herdr 0.9.0, Neovim 0.12.5, lazygit 0.65, Starship 1.26, Claude Code 2.1, Codex CLI 0.154. Newer versions will mostly work. When a tool renames a config key, the validation step in that stage (`ghostty +validate-config`, `herdr config check`) tells you.

## How it was built

The script was generated and refined with Matt Pocock's [wizard skill](https://www.aihero.dev/skills-wizard) for coding agents, then hardened through real use. [docs/how-it-was-built.md](docs/how-it-was-built.md) covers the process and what it taught us.

## Contributing

Issues and pull requests are welcome. Please keep the wizard library at the top of the script (everything above the `STAGES` marker) unchanged, since it comes from the wizard skill's template. Before opening a PR, run:

```bash
bash -n ghostty-herdr-wizard.sh
shellcheck -S error ghostty-herdr-wizard.sh
bash ghostty-herdr-wizard.sh --list
```

## Credits

- [herdr](https://herdr.dev) and [Ghostty](https://ghostty.org), which do the heavy lifting
- [Matt Pocock's skills](https://github.com/mattpocock/skills), the wizard skill and its template library (MIT, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md))
- [Catppuccin](https://catppuccin.com), [Starship](https://starship.rs), [LazyVim](https://www.lazyvim.org), [delta](https://github.com/dandavison/delta), [difftastic](https://difftastic.wilfred.me.uk), [lazygit](https://github.com/jesseduffield/lazygit), [yazi](https://yazi-rs.github.io), [gh-dash](https://github.com/dlvhdr/gh-dash), [Diffview.nvim](https://github.com/sindrets/diffview.nvim), [terminal-notifier](https://github.com/julienXX/terminal-notifier)

## License

[MIT](LICENSE)
