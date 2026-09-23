# Tour assembled from selections

Status: ready-for-agent

## What to build

Collapse nine separate tour stages into one stage whose sections are chosen by what the user actually installed.

Today the tour is a third of the wizard's stages, and several of its sections teach tools that may now be unselected. Walking someone through a file manager they declined is worse than not touring at all. Meanwhile the new selection screen and the richer per-stage explanations already carry much of the teaching the tour used to do alone.

Sections that always run, because they describe the mental model rather than a tool: landing in the multiplexer and one workspace per repo, moving around, running and juggling agents, tabs inside one repo, and the closing daily-habits screen.

Sections that run only when their tool was selected: the editor, the review flow, the file manager, the status line, and the GitHub dashboard.

A minimal install should land around four screens, a full one around eight. The section counter shows position within the sections that will actually run, and skipping out of the tour is possible at any screen.

One content fix belongs here: the tour currently instructs the user to change their agent's reasoning effort level as a demonstration. That is the reason an effort-level change showed up in the original list of things needing manual reverting — the wizard never writes that setting, it only displays it. Demonstrate the status line's effort segment without telling the user to change a persistent setting.

The existing replay flag should keep working, alongside the new slug-based form.

## Acceptance criteria

- [ ] The tour is one stage in the registry, not nine
- [ ] Always-on sections run for every user regardless of selection
- [ ] Conditional sections run only when their tool was selected and installed
- [ ] A minimal install shows only the always-on sections, with no gaps or dangling references
- [ ] The section counter reflects the sections that will actually run
- [ ] The tour can be skipped from any screen, and skipping ends the stage cleanly
- [ ] Replaying works by both the existing flag and the slug-based form
- [ ] No tour screen instructs the user to change a persistent setting as a demonstration
- [ ] Key chords shown in the tour match the prefix key the user actually chose
- [ ] Glyphs in tour output follow the glyph switch

## Blocked by

- `06-choices-stage-and-tool-picker`
