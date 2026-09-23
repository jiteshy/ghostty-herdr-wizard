# Wizard v2 — build spec

Outcome of the design grilling on 2026-09-22. Every decision below is settled.
Numbers in parentheses are line references into the current
`ghostty-herdr-wizard.sh` (1961 lines, 27 stages).

Headline shape: **27 stages and 27 tools become at most 13 stages and 4 mandatory
plus 8 selectable clusters**, and everything the wizard touches becomes
reversible.

---

## 1. Revert and uninstall

### 1.1 Two flags

| Flag | Does |
|---|---|
| `--revert` | Restores every config the wizard touched. Leaves tools installed. |
| `--uninstall` | Runs the full `--revert` first, then offers to remove wizard-installed formulae, one at a time. |

`--uninstall` always implies `--revert`, and in that order. The forbidden
combination is removing binaries while configs still reference them: `.zshrc`
would still `eval "$(starship init zsh)"` and the Ghostty config would still
launch herdr, so every new shell would error.

Only formulae the journal records as *newly installed by the wizard* are ever
removed. `brew_formulae()` (251) already computes the `missing[]` array, so this
distinction costs nothing.

### 1.2 The journal

State lives in `~/.ghostty-herdr-wizard/`:

```
journal.tsv          append-only, spans all runs
backups/             first-ever-wins per path
reverted/<stamp>/    where reverted content is moved to
choices.env          saved answers from the last run
```

The journal is written by the existing helpers (`install_file`, `upsert_block`,
`backup`, `git_set`), so new stages get revert support for free. Entry types:

| Type | Fields | Revert action |
|---|---|---|
| `MODIFY` | path, backup ref, sha of what we wrote | restore backup |
| `CREATE` | path, sha | relocate to `reverted/` |
| `BLOCK` | path, marker id | strip the fenced region |
| `JSONKEY` | path, key, prior value or `<absent>` | `jq del` or restore value |
| `BREW` | formula, `new` or `pre-existing` | `brew uninstall` only if `new` |
| `PLUGIN` | herdr plugin id | `herdr plugin unlink` / uninstall |
| `PKG` | manager, package (`ya pkg`, bat theme) | manager-specific removal |
| `MANUAL` | description, settings deep link | print in the closing checklist |

Stages with side effects a journal line cannot express declare an
`undo_<stage>` function. In practice that is only `herdr server reload-config`.

### 1.3 Fixing the per-run backup bug

`BACKUP_DIR` is timestamped per run (189) and `backup()` keeps only the first
copy *per run* (265). On a second run the wizard therefore backs up **its own
output from run 1** and labels it the original. Revert would then restore you to
the wizard's state, not yours.

Fix: one canonical `backups/` directory, first-ever-wins across all runs. A path
is captured the first time it is ever touched and never overwritten. `--revert`
always returns the machine to its true pre-wizard state, then archives the
journal so a later re-run starts clean.

### 1.4 Drift

Each journal entry carries the sha of exactly what the wizard wrote.

- File still matches that sha: nobody touched it, restore silently.
- File differs: the user edited it since. Show the diff and prompt, **defaulting
  to keeping their version**, and note it in the closing summary.

Managed blocks are exempt: `upsert_block` markers (306) delimit our region
precisely, so the block is always removed surgically regardless of what else in
the file changed.

### 1.5 Revert relocates, it never deletes

No `rm -rf` anywhere in the undo path. Anything the wizard created is moved to
`~/.ghostty-herdr-wizard/reverted/<timestamp>/` preserving relative paths, then
the pre-wizard original is moved back.

This matters most for `~/.config/nvim`. `stage_neovim` moves an existing nvim
config aside (957) and clones the LazyVim starter in its place. Months later that
tree holds the user's own plugin configs and `lazy-lock.json`. Revert removes it
from where Neovim looks, which is what revert means, without destroying it.

`--revert --restore` brings the last relocation back.

### 1.6 `~/.claude/settings.json` is key-level, never whole-file

Two stages mutate it: the herdr hook (1414) and the statusline (1538), both via
`jq` merge then a whole-file `install_file`. But Claude Code itself writes to this
file as the user accepts permissions. So a whole-file restore would wipe every
accumulated permission, and the drift check would fire for every user on every
run, making the warning meaningless.

Journal `JSONKEY` entries with the prior value, and revert with
`jq 'del(.statusLine)'`. A full-file backup is still taken as a safety net but is
never auto-restored.

### 1.7 What a script cannot undo

Three changes live in macOS System Settings and are applied by hand: freeing
Ctrl-Space (680), the terminal-notifier notification permission (1461), and
Ghostty's Accessibility access for the quick terminal (1493).

These are journaled as `MANUAL` and printed as a numbered checklist at the end of
revert, each offering to open the right settings pane via `open_url`. We do not
poke `com.apple.symbolichotkeys` or `tccutil`: undocumented plists in an undo path
is exactly where surprises are least acceptable.

Choosing Ctrl-B as the prefix (see 3.1) removes the first of the three entirely.

### 1.8 Correction to the manual revert notes

The wizard never sets Claude Code's effort level. It only reads and displays it
(528, 570). That change came from the tour instructing the user to run `/effort`
(1700). Fix the tour wording; there is no config mutation to revert.

---

## 2. Tool selection

### 2.1 Mandatory (3)

| Tool | Why it cannot be optional |
|---|---|
| Ghostty | the terminal the wizard configures |
| herdr | the multiplexer the whole thing exists for |
| terminal-notifier | the herdr config sets `[ui.toast] delivery = "system"` (1370), which requires it |

`jq` installs silently alongside the statusline (its only consumer, 520) and is
never a user-facing choice.

### 2.2 Selectable clusters (8)

Bundles exist **only where tools genuinely depend on each other**. Each is one
checkbox; every tool inside is listed with a plain-language line about what it
gives you. Pre-checked to the recommended set. A declined cluster skips both its
install and its config stage.

| Cluster | Tools | Why grouped |
|---|---|---|
| Nerd Font + icons | font-jetbrains-mono-nerd-font | global glyph switch, see 2.4 |
| starship prompt | starship | standalone |
| project jumper + fuzzy find | fzf, fd, eza, bat | `hproj` needs fd + fzf + eza (843-846); fzf preview needs bat (796) |
| shell typing help | zsh-autosuggestions, zsh-syntax-highlighting | a pair, useless apart |
| editor | neovim, tree-sitter-cli, ripgrep, fd + LazyVim | LazyVim requires all three |
| review the agent's diff | herdr-hunk-diff, lazygit | see 4 |
| file manager | yazi, poppler, resvg | poppler/resvg are yazi's preview backends |
| GitHub | gh, gh-dash | gh-dash requires gh |

`fd` appears in two clusters; dedupe at install time.

### 2.3 Cut (7 tools, ~9 fewer moving parts)

`git-delta`, `difftastic`, `zoxide`, `btop`, `glow`, `jless`, `tlrc`.

- **delta + difftastic** go per the "only keep herdr-hunk" instruction. This
  deletes the entire `.gitconfig` stage (pager, diff, `gds` alias), which was one
  of the nine things the manual revert had to undo. The revert surface shrinks
  with it.
- **zoxide** overlaps the `p` project jumper we already ship, and costs a shell
  init line plus a database in the revert surface.
- **btop** existed only to fill the `prefix+t` popup we invented.

`lazygit` **stays**: it does staging, committing and branch work, which herdr-hunk
does not.

Consequence: the herdr config's popup bindings (`prefix+d` lazygit, `prefix+f`
yazi, `prefix+i` gh-dash, `prefix+t` btop) must become conditional on selection,
or the user gets keys that open nothing.

### 2.4 The Nerd Font is one global glyph switch

The font is not just starship's dependency. Consumers: herdr
`status_indicators = "symbols"` (1373, herdr's own default is `dots`, which needs
no glyphs), `eza --icons` in three aliases (803-805), the hproj preview
(846), yazi and LazyVim devicons, and the statusline.

So it is one checkbox, "Nerd Font + icons", not a starship sub-dependency:

- **Ticked** — install or detect the font, glyphs everywhere. `brew_formulae`
  already no-ops when present, so an iTerm user who already has a Nerd Font just
  ticks it and gets glyphs with no install.
- **Unticked** — herdr falls back to `dots`, eza drops `--icons`, starship gets
  the plain preset, yazi and LazyVim use text markers, the statusline uses ASCII.
  No tofu anywhere.

This is the whole answer to the iTerm inclusivity problem. A script can install a
font but cannot know which font another terminal is configured to use, so this is
a choice, not a detection.

---

## 3. Prompts and flow

### 3.1 herdr prefix key is now a choice

herdr's own default is `ctrl+b`. The wizard overrides it to `ctrl+space` (1311)
because Claude Code uses Ctrl-B to background a command, and Claude Code is the
tool this setup exists to run. That override is what drags in the System Settings
detour at 680.

`prefix` is a single string (`herdr --default-config`, line 78) so both keys at
once is not possible. Present the trade-off:

```
herdr prefix key
  every herdr shortcut starts with it

  1) ctrl+space  (suggested)
     keeps ctrl+b free for Claude Code
     needs one macOS setting changed

  2) ctrl+b  (herdr's default)
     no macOS changes needed
     clashes with Claude Code's
     background-a-command shortcut

choice [1]:
```

Choosing `ctrl+b` skips the free-Ctrl-Space stage entirely and drops the manual
revert checklist from three items to two.

### 3.2 Light/dark follows macOS

Four of the nine manual revert items were forced dark. And `theme.toml` (1066)
sets `light = "catppuccin-mocha"`, so yazi currently shows a dark theme in light
mode. That is a bug, fixed either way.

Default: follow macOS. Ghostty `light:Catppuccin Latte,dark:Catppuccin Mocha`,
herdr `auto_switch = true`, yazi `dark = mocha` / `light = latte`,
catppuccin.nvim flavour auto. One prompt offers always-dark for anyone who wants
it, and a third option to leave themes alone.

Caveat to print: Ghostty, herdr and yazi switch cleanly; an already-open Neovim
may need a restart to repaint after macOS switches.

### 3.3 Prompt: two hand-written minimal configs

Upstream presets do not match the requirement. `tokyo-night` is ~130 lines with a
`[palettes]` table, powerline separators and a dozen language modules;
`pure-preset` carries username, hostname and runtime versions. Stripping them
programmatically means depending on their internals, which upstream changes.

Ship two ~20-line configs, Pure-style and Tokyo Night-style, each containing
**only `directory` and `git_branch`**. Preview both live before the choice with
`STARSHIP_CONFIG=<tmp> starship prompt`, rendered in the user's actual folder.
The existing code previews only *after* installing (731); move it before.

```
Two prompts, both showing just the folder and the git branch:

 1) pure
    ~/projects/app main
    ❯

 2) tokyo night
     ~/projects/app   main 

 1) pure          (suggested)
 2) tokyo night
 3) leave my prompt alone
```

With the glyph switch off, Tokyo Night loses its powerline separators, so offer
Pure only rather than shipping a broken powerline.

### 3.4 Destructive steps are labelled from the filesystem, at runtime

A static per-stage label lies in both directions: it cries wolf for a user with no
Ghostty config, and stays quiet for one whose nvim setup is hand-tuned.

Each stage declares its target paths. Immediately before running, check which
already exist and print the truth:

```
Stage 9/14   Neovim + LazyVim

  ⚠ REPLACES 2 files you already have
      ~/.config/nvim/lua/config/autocmds.lua
      ~/.config/nvim/plugin/colours.lua
    a copy of each goes to ~/.ghostty-herdr-wizard/backups/
    undo any time with --revert

  ✓ adds 1 new file
```

The same data feeds the up-front plan summary. Per-file diff and confirm stay as
`install_file` already does them (288).

### 3.5 One run mode, plus `--yes`

The originally-requested "do it all autonomously" mode is dropped, because it
cannot deliver what its name promises. Four interactions are unavoidable:
relaunching into Ghostty (657), allowing notifications (1461), granting
Accessibility (1493), and freeing Ctrl-Space if that prefix is chosen. An
"unattended" run would still stop four times.

Instead, with every question front-loaded into stage 1, the two modes collapse:

1. All questions asked once, in the `choices` stage.
2. A plan summary: tools to install, files that will be replaced, the points
   where it will need the user, and the `--revert` promise.
3. One confirmation.
4. Stages run with a pause between each. `--yes` makes those pauses no-ops for a
   re-run; the four real interactions still stop.

```
   Plan
     install 9 tools
     ⚠ replaces 2 existing files
     4 points where it needs you:
       relaunch into Ghostty
       allow notifications
       allow accessibility
       free ctrl+space
     undo:  --revert
   Go? [y/N]
```

---

## 4. Git review: herdr-hunk

`herdr plugin install jhochenbaum/herdr-hunk-diff`. Requires herdr ≥ 0.8.0 (we
have 0.9.0) and **Node ≥ 22.12**.

### 4.1 Node is detected, never touched

The dev machine currently runs Node v20.19.2, below the requirement. So this is
not hypothetical.

`brew install node` is not an option. Node is usually managed outside brew by
nvm, fnm, volta or asdf; a brew Node alongside nvm creates a PATH-order mess, and
a global upgrade breaks projects pinned to v20. Neither is something `--revert`
can undo, because nvm's state is not a file we backed up.

Check the version **during selection**, not halfway through install. If too old,
grey the item out and name the manager found on the system with its exact command:

```
[ ] hunk review  needs newer Node
      review the agent's diff hunk by hunk, comment, send back.
      needs Node 22.12+, you have v20.19.2 (via nvm)
        nvm install 22 && nvm use 22
      then:  wizard --only review

  tab 4 stays a plain shell for now
```

### 4.2 Keybinding collision, and who owns `config.toml`

The plugin's `setup-keys` binds `prefix+shift+a` to "review staged changes". Our
config already uses `prefix+shift+a` for `previous_agent` (1315). And `setup-keys`
writes into `~/.config/herdr/config.toml`, which the wizard owns as a whole file,
so a second run would show a diff and offer to wipe the plugin's bindings, while
the revert drift-check would blame the user for the plugin's edit.

Resolution — let the plugin own its binding syntax, then re-absorb the file:

1. Write `config.toml` with `previous_agent = "prefix+shift+v"`, freeing
   `shift+a`.
2. `herdr plugin install jhochenbaum/herdr-hunk-diff`
3. `herdr plugin action invoke setup-keys --plugin jhochenbaum.hunkdiff`
   (adds `shift+h` review, `shift+s` send, `shift+c` latest commit,
   `shift+a` staged)
4. Re-hash `config.toml` into the journal as the wizard's new baseline.
5. `herdr server reload-config`

Re-runs then show no spurious diff, and `--revert` still restores the true
pre-wizard file.

---

## 5. Tabs

### 5.1 The layout

Four tabs, created by the `worktree-tabs` plugin on `workspace.created` and
`worktree.created`:

| # | Label | Purpose |
|---|---|---|
| 1 | agents | Claude Code / Codex |
| 2 | source code | Neovim on the files |
| 3 | local server | `npm run dev`, logs |
| 4 | git review | hunk-by-hunk review of what the agent did |

Tab 4 **auto-launches the review**: the hook focuses tab 4, invokes the review
action with `placement = "overlay"` so it fills that tab's pane rather than
creating a fifth tab, then focuses tab 1. `herdr tab create` has no `--command`
flag, so this goes through the plugin action, not the tab API.

Known trade-off, accepted: on a brand-new workspace or worktree there is nothing
to review, so the plugin opens on its working-tree fallback and needs a refresh
once the agent edits something.

If herdr-hunk is not selected (unticked, or Node too old), tab 4 stays a plain
shell with the same label.

### 5.2 The prompt

Today this is two chained y/n questions (1074 "Open a default set of tabs?", then
1083 "Use those?"), and the first asks about something the user has not been shown
yet. Replace with: explain, show, then one numbered choice.

```
Tabs inside a workspace
  A workspace is one repo. Tabs are separate terminals in it,
  all in the same folder, all kept running.

  herdr can open the same four in every new repo and worktree:

  1 agents        Claude Code / Codex
  2 source code   Neovim on the files
  3 local server  npm run dev, logs
  4 git review    hunk-by-hunk review of what the agent did

  1) use these four        (suggested)
  2) same idea, my names
  3) no default tabs, one plain tab

  choice [1]:
```

---

## 6. Stages

### 6.1 The new list

One stage for the mandatory work, one per selected cluster. 5 fixed + up to 7
selected + tour: **minimum 6, maximum 13**, versus 27 today.

| Slug | Interactive | Notes |
|---|---|---|
| `choices` | all questions | tools, prefix, theme, prompt style, tabs, projects dir, then plan + confirm |
| `install` | no | brew the mandatory 3 plus everything selected |
| `ghostty` | **yes** | write config, relaunch into Ghostty |
| `herdr` | yes if Ctrl-Space | config, prefix key, agent integration, tab plugin, reload |
| `macos` | **yes** | notifications + quick terminal permissions |
| `prompt` | no | selected only |
| `shell` | no | selected only |
| `editor` | no | selected only |
| `review` | no | selected only |
| `yazi` | no | selected only |
| `github` | no | selected only |
| `statusline` | no | selected only |
| `tour` | yes | assembled from selections |

### 6.2 Flags take names, not numbers

Once stages are conditional on selection, numbers shift per user: one person's
stage 11 is another's stage 8, so every number in the README, in `SKIPPED`
messages and in hints (e.g. 1431) is wrong for somebody.

- `--only review`, `--skip yazi,github`, `--from editor`
- `--list` prints the slugs
- Numbers survive only in the `Stage 9/14` progress header
- Choices are saved to `choices.env`, so `--only review` needs no re-answering,
  and a plain re-run offers "use last time's answers?"

### 6.3 Tour

Nine stages (19-27) become one `tour` stage whose sections are assembled from what
was actually installed. Touring a declined tool is worse than no tour.

- Always: workspaces, navigation, agents, tabs, habits
- Conditional: Neovim, review, yazi, statusline, GitHub
- `--only tour` replays it (keep `--tour` as an alias)

A minimal install gets ~4 screens, a full one ~8.

---

## 7. Implementation order

1. Journal + backup rework (1.2, 1.3) — everything else writes through it
2. `--revert` and `--uninstall` (1.1, 1.4-1.7)
3. Stage restructure and named flags (6)
4. Selection screen and the cut list (2)
5. Glyph switch threaded through every consumer (2.4)
6. Tabs prompt and plugin changes (5)
7. herdr-hunk stage, Node gate, key collision (4)
8. Theme follows macOS (3.2), prompt presets (3.3)
9. Runtime REPLACES badges and the plan summary (3.4, 3.5)
10. Tour assembly (6.3)

Before anything else: a revert test. Snapshot a clean macOS home, run the wizard
with everything selected, run `--revert`, and diff the home directory against the
snapshot. That diff is the specification's real acceptance test, and it is the
only way to know the nine manual revert steps have genuinely been automated.
