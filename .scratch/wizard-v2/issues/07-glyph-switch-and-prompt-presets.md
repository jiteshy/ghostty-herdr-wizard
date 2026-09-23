# Fonts, icons and prompt: global glyph switch plus two minimal presets

Status: ready-for-agent

## What to build

Make the wizard's output render correctly in terminals other than the one it configures, and replace the single opinionated prompt with a choice of two, each trimmed to what was actually asked for.

**The font becomes a global glyph switch.** Today the Nerd Font is installed unconditionally and its glyphs are emitted everywhere, which works in the terminal the wizard configures and produces tofu boxes anywhere else, because the wizard can install a font but cannot know which font another terminal is set to use. That makes this a choice, not a detection.

It is one checkbox covering the font and the icons that need it, not a sub-dependency of the prompt. Six things consume those glyphs: the multiplexer's symbol-based agent status indicators, the listing aliases, the project jumper's preview, the file manager, the editor's file icons, and the status line. Bundling the font with the prompt alone would leave five of those rendering boxes.

- Ticked: install or detect the font, glyphs everywhere. Detection matters — a user who already has a Nerd Font in another terminal ticks the box and gets glyphs with no install at all.
- Unticked: the multiplexer falls back to its own default dot indicators, listing aliases drop their icon flags, the prompt uses its plain variant, the file manager and editor use text markers, and the status line uses ASCII. No tofu anywhere.

**Two prompt styles, hand-written.** The upstream presets do not match the requirement that the prompt show only the current directory and the git branch: one carries a palette table, powerline separators and a dozen language modules, the other carries username, hostname and runtime versions. Stripping them programmatically means depending on internals that upstream changes freely. Instead ship two small configs, one plain-text style and one powerline style, each containing only the directory and the branch.

Preview both live, rendered from the user's actual current folder, **before** the choice is made rather than after it is installed. A third option leaves the existing prompt alone. When the glyph switch is off, the powerline style has no separators to draw, so offer only the plain style rather than shipping something broken.

## Acceptance criteria

- [ ] One checkbox controls the font and every glyph the wizard emits
- [ ] An already-installed Nerd Font is detected and no install is performed
- [ ] With glyphs off, all six consumers emit their plain variants, verified individually
- [ ] With glyphs off, a full run produces no Nerd Font or private-use codepoints in any file the wizard writes
- [ ] The multiplexer's status indicator setting follows the switch rather than being hardcoded to symbols
- [ ] Two prompt configs are shipped, each showing only the current directory and the git branch
- [ ] Both are previewed live from the user's current folder before the choice, not after installation
- [ ] A third choice leaves the existing prompt untouched and writes nothing
- [ ] With glyphs off, only the plain style is offered
- [ ] Both configs are journaled and revert cleanly

## Blocked by

- `06-choices-stage-and-tool-picker`
