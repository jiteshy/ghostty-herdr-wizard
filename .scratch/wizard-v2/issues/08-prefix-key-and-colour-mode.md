# Prefix key and colour mode become choices

Status: ready-for-agent

## What to build

Two settings the wizard currently forces become questions, and one of them removes a mandatory macOS detour for anyone who answers the second way.

**The multiplexer prefix key.** Its own default is Ctrl-B. The wizard overrides that to Ctrl-Space because Claude Code uses Ctrl-B to background a command, and Claude Code is the tool this whole setup exists to run. The override is well-motivated, but it is the sole reason for the most confusing step in the wizard: sending the user into macOS keyboard settings to untick two input-source shortcuts. It is also the one change a revert cannot undo automatically.

The config field takes a single key, so supporting both at once is not possible. Present the trade-off plainly: Ctrl-Space keeps Ctrl-B free for the agent but needs one macOS setting changed; Ctrl-B needs no macOS changes but clashes with the agent's backgrounding shortcut. Default to Ctrl-Space.

Choosing Ctrl-B must skip the free-the-prefix stage entirely — not run it and report success, but never run it — which also drops the manual revert checklist from three items to two.

**Colour mode follows macOS by default.** Four surfaces are currently pinned to one dark palette: the terminal, the multiplexer, the editor, and the file manager. Four of the nine changes in the original manual revert were undoing exactly that. Default to following the system appearance across all four, with a second option for a fixed dark palette and a third that leaves themes alone entirely.

There is a genuine bug to fix here regardless of which option is chosen: the file manager's theme config sets its *light* flavour to the dark one, so it shows a dark theme in light mode.

The original rationale for pinning — panes sitting side by side should never clash — is real, so print the one honest caveat: the terminal, multiplexer and file manager all switch cleanly, but an already-open editor session may need a restart to repaint after the system switches.

## Acceptance criteria

- [ ] The prefix key is a question with both options and their trade-offs stated, defaulting to Ctrl-Space
- [ ] Choosing the multiplexer's own default skips the free-the-prefix stage entirely
- [ ] With that choice, the manual revert checklist contains two items rather than three
- [ ] The chosen prefix is reflected everywhere keys are documented: the config, the cheat sheet, and the tour
- [ ] Colour mode is a three-way question defaulting to following the system
- [ ] Following the system is applied consistently to all four surfaces, each using its own mechanism
- [ ] The file manager's light flavour is a light theme, in every colour mode
- [ ] The leave-my-themes-alone option writes no theme setting to any of the four
- [ ] The editor-repaint caveat is printed when the system-following option is chosen
- [ ] Both choices are recorded in the choices file and survive a re-run

## Blocked by

- `06-choices-stage-and-tool-picker`
