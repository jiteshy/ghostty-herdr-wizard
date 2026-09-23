# Clean-home revert acceptance test

Status: ready-for-agent

## What to build

A repeatable, scripted test that proves the revert promise holds. This is the specification's real acceptance criterion: the nine changes that previously had to be undone by hand are only genuinely automated when a machine can be returned to a byte-identical state.

Shape of the test: snapshot a home directory, run the wizard non-interactively with everything selected, run `--revert`, then diff the home directory against the snapshot. The diff should contain nothing but the wizard's own state directory.

Two scenarios matter and both must be covered:

**Pristine home.** Nothing pre-exists. Every file the wizard writes is a creation, so revert must relocate all of them and leave no trace in the user's config directories.

**Populated home.** Seed the home with a plausible existing setup before running: a shell startup file with the user's own aliases, a git config, a Ghostty config with a different theme, a hand-rolled Neovim configuration, and a Claude Code settings file carrying permissions. This scenario is what catches the failure modes that matter — marked blocks stripped without disturbing surrounding lines, the Neovim directory restored rather than destroyed, and settings keys removed without touching accumulated permissions.

Run the wizard twice in one scenario before reverting, to prove the backup store still holds the user's original rather than the wizard's first-run output.

The test needs the wizard to be drivable without a human, which means it runs only the stages that do not require macOS interaction or a terminal relaunch. Those four interactive points are verified by hand in the final slice; this test covers everything else.

## Acceptance criteria

- [ ] A single command runs the whole test and reports pass or fail
- [ ] Pristine-home scenario: after revert, the home directory differs from the snapshot only by the wizard's own state directory
- [ ] Populated-home scenario: after revert, every seeded file is byte-identical to its seeded content
- [ ] The populated scenario seeds at minimum a shell startup file with user aliases, a Ghostty config, a Neovim config, and a Claude Code settings file with permissions
- [ ] A double-run-then-revert case proves the backup holds the user's original, not the wizard's first-run output
- [ ] Test failures print the offending diff, not just a pass/fail verdict
- [ ] The test does not require a clean machine, a VM, or sudo, and leaves no residue when it finishes
- [ ] Documented in the repo so it can be run before any future change to the revert path

## Blocked by

- `02-revert-all-entry-types`
