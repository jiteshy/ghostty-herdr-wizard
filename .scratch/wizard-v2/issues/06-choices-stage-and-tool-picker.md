# `choices` stage: tool picker, cut list, plan summary, one confirm

Status: ready-for-agent

## What to build

Front-load every question into a single opening stage, cut the tool list roughly in half, and replace the old run-and-hope flow with a plan the user approves once.

**The picker.** Three tools are mandatory and shown as a statement of fact, not a prompt: the terminal, the multiplexer, and the notifier that the multiplexer's toast configuration depends on. One more installs silently as an implementation detail of the status line and is never offered as a choice.

Everything else is a checkbox. Clusters exist **only where tools genuinely depend on one another** — the project jumper needs its finder, fuzzy matcher and lister; the editor needs its parser and search tools; the file manager needs its preview backends; the GitHub dashboard needs the GitHub CLI. Where a tool stands alone, it is its own checkbox. Each cluster lists every tool inside it with a plain-language line about what that tool gives you, because the audience has not used most of these and cannot judge a cluster by its name alone. Pre-check the recommended set.

A declined cluster skips both its install and its config stage. That is what honouring the selection has to mean.

**The cut.** Remove seven tools entirely: the git pager and structural differ, the directory jumper, the process monitor, the markdown viewer, the JSON viewer, and the tldr client. Removing the two git tools deletes the git config stage outright — pager, diff settings and the diff alias all go, which also removes one of the nine things the old manual revert had to undo. The git UI tool stays, because staging, committing and branching are not what the hunk reviewer does.

Consequence to handle: several popup keybindings in the multiplexer config point at tools that may now be absent or cut. Those bindings must be emitted conditionally, or the user gets keys that open nothing.

**The plan.** After the questions, print what will happen: how many tools will be installed, which existing files will be replaced (from the target declarations built in the previous slice), the points where the run will need the user, and the command that undoes it all. Take one confirmation. Then run.

**One run mode.** The originally-requested autonomous mode is dropped, because it cannot deliver what its name promises: four interactions are unavoidable regardless — relaunching into the terminal, allowing notifications, granting accessibility, and freeing the prefix key if that option is chosen. With every question front-loaded, the difference between the two modes collapses to whether the wizard pauses between stages, so that becomes a flag rather than a mode. The flag makes inter-stage pauses no-ops for a re-run; the four real interactions still stop.

## Acceptance criteria

- [ ] Mandatory tools are shown as a short factual list with no prompt attached
- [ ] Optional tools are presented as toggles, grouped only where a genuine dependency exists, each tool described in plain language
- [ ] The recommended set is pre-checked and a single keystroke accepts it
- [ ] Declining a cluster skips its install and its config stage, verified for each cluster
- [ ] The seven cut tools are gone from the script entirely, including their installs, aliases, config, and documentation
- [ ] The git config stage no longer exists
- [ ] Popup keybindings are emitted only for tools that were actually selected and installed
- [ ] All questions are asked in this stage; no later stage prompts for a preference
- [ ] The plan summary lists tools to install, files that will be replaced, the interactive points, and the revert command
- [ ] Exactly one confirmation gates the entire run, and declining it exits without touching anything
- [ ] The pause-skipping flag suppresses inter-stage pauses but not the four genuinely interactive moments
- [ ] Answers are written to the choices file and reused on a later run

## Blocked by

- `05-named-stage-registry`
