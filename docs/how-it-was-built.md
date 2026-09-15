# How it was built

This project was built with a coding agent (Claude Code) using Matt Pocock's [wizard skill](https://www.aihero.dev/skills-wizard). This page explains what that skill is, how it shaped the script, and what the build taught us. It's written for anyone who wants to build a similar setup script for their own team or tools.

## The problem with setup guides

Setting up a development environment is a long list of small manual steps: install this, edit that file, open System Settings, click through a permissions dialog, log in to a service, check that a font renders. Written guides go stale and get skimmed. Asking an AI agent to "set up my terminal" works once, but the next person has to explain it all again, and the agent can't click macOS permission dialogs or see whether icons render on your screen.

## What the wizard skill does

The [wizard skill](https://www.aihero.dev/skills-wizard) is an agent skill from [Matt Pocock's skills collection](https://github.com/mattpocock/skills). Instead of doing a manual procedure itself, the agent writes a **wizard**: a bash script that walks a human through the procedure one stage at a time. It says exactly what to click, runs the commands it can, pauses for the steps only a person can do, and confirms before anything irreversible.

The skill comes with a template. Its top half is a small library that is identical in every wizard:

- `stage` clears the screen and shows progress (`Stage 7/27`)
- `say`, `step` and `note` for instructions
- `open_url` to open the right settings page or website
- `pause` and `confirm` gates, so the human stays in control
- a closing summary of what changed and what still needs doing by hand

The agent's job is only to write the stages below a `STAGES` marker. That split is what makes the result consistent and reviewable. The library is never hand-edited (this repo's top 185 lines match the template exactly), and all of the thinking goes into the stages.

## How the skill structured the work

The skill defines four steps, and the build followed them closely.

### 1. Scope the procedure

The agent looked at the machine before asking anything: which tools were installed, the existing shell and git config, the fonts and the macOS version. It then proposed an ordered list of stages and asked only the questions that were genuinely the user's call:

- Which editor for reading code? (Neovim with LazyVim)
- Which Nerd Font? (JetBrains Mono)
- herdr's default prefix, Ctrl-B, clashes with Claude Code's shortcut for backgrounding a command. Which should move? (herdr moves to Ctrl-Space)
- Which optional extras? (auto-start herdr, GitHub PR dashboard, quick terminal hotkey)

Everything with a sensible default was decided without asking.

### 2. Map each stage's journey

The skill insists on concrete instructions a stranger could follow, and says not to invent steps. So before writing a config key or keyboard shortcut, the agent checked it against a primary source:

- herdr's configuration reference and Rust source, for config keys, key names and how popups run commands
- Ghostty's config and keybind references, plus `ghostty +validate-config` against test files
- the lazygit docs for the installed version, where the pager setting had recently been renamed
- the Claude Code status line schema, which showed that there's no running session token total (only tokens currently in context)

### 3. Author the wizard

Each stage is one focused task, so nothing the person needs scrolls off screen. The skill's rules show up throughout the script:

- run what can be automated (`brew install`, writing config files, `git config`)
- open the exact settings page for what can't (Keyboard Shortcuts, Notifications, Accessibility)
- `confirm` before anything that touches existing files, and show a diff first
- keep a backup of anything replaced

Because every file write is idempotent, the script can be re-run safely. That later made room for the `--from`, `--only`, `--skip` and `--tour` flags.

### 4. Verify and hand off

A wizard opens browsers and waits for human input, so the agent can't run it end to end. The skill asks for static tracing instead, and the build went further with sandbox tests:

- `bash -n` under macOS's bash 3.2
- config files validated by the tools themselves (`ghostty +validate-config`, `herdr config check`, TOML and YAML parsers, `nvim` loading the Lua)
- helpers run against a throwaway `$HOME`, including the confirm prompts through a pseudo-terminal
- the status line script fed full, partial and empty JSON payloads
- a fake herdr client process, to check that the launcher could tell a client from the server

## Iterating after real use

The first version installed everything correctly. Using it every day turned up problems that no amount of reading docs would have caught. Each fix went back into the wizard, so the next person gets it for free.

| What happened | Root cause | Fix in the wizard |
|---|---|---|
| herdr didn't start when reopening Ghostty | Closing a Mac app's last window doesn't quit it, and `initial-command` only applies to the first window after launch | A launcher that attaches herdr unless it's already open in another window |
| An agent's `cat -v` failed | Claude Code copies shell aliases into its own shell, where `cat` had become `bat` | Aliases are skipped when `CLAUDECODE` is set |
| Cmd-1…9 didn't switch herdr tabs | Ghostty's built-in `cmd+digit_1` (physical key) beats a `cmd+1` binding | Bind the physical key names |
| No notifications | Ghostty drops banners while its window is focused, and herdr runs inside that window | herdr posts through terminal-notifier, and the launcher adds Homebrew to PATH so herdr can find it |
| Prompt text hard to read | The powerline preset sets backgrounds only, so text colour flipped with the theme | Fixed text colours, with backgrounds shifted to at least 5:1 contrast |

Each fix followed the same loop: reproduce the problem, find the real cause in logs or source code, change the stage, then re-run just that stage with `--only`.

A good example is the herdr issue. The client log showed herdr *had* started, in the same second Ghostty launched. So the config was fine and the problem was macOS window lifecycle, which pointed to the launcher fix rather than more config changes.

## Lessons for building your own wizard

- **Look before you ask.** Reading the machine answers most questions and makes the remaining ones sharper.
- **Verify every key and flag against the source.** Tool configs change between versions, and a plausible-looking key that doesn't exist fails silently.
- **Keep stages small and re-runnable.** It makes fixes cheap: change one stage, re-run one stage.
- **Explain the why in the output.** Comments in generated configs and notes in the wizard ("Claude Code keeps Ctrl-B for backgrounding commands") save the next person from undoing a deliberate choice.
- **Real use finds the real bugs.** Plan for a round of fixes after people actually live in the setup.

## Try the skill

- Wizard skill: <https://www.aihero.dev/skills-wizard>
- Matt Pocock's skills: <https://github.com/mattpocock/skills>

The template library at the top of `ghostty-herdr-wizard.sh` is © Matt Pocock and used under the MIT License. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
