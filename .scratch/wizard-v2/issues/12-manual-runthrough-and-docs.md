# Full manual run-through, revert, and documentation

Status: ready-for-human

## What to build

The end-to-end verification that only a human on a real Mac can perform, followed by documentation describing what was actually verified rather than what was planned.

The automated acceptance test covers everything that can run unattended. Four things it cannot cover, because each requires a person at the machine:

1. Relaunching into the configured terminal mid-run, and confirming the wizard picks up correctly on the other side
2. Granting the notification permission, and confirming a banner actually appears
3. Granting accessibility access, and confirming the drop-down terminal responds from another app
4. Freeing the prefix key in keyboard settings, when that prefix was chosen

Run the wizard twice for real: once accepting the recommended selection, once with the minimum selection and the alternative answer to every question, so both sides of each branch are exercised. Then run the config revert, work through the manual checklist it prints, and confirm those macOS settings genuinely return to their prior state — the checklist is the wizard's only claim about them, and nobody has verified that claim until someone follows it.

Then run the uninstall on a third pass and confirm the machine is left with no dangling references: shells open without errors, no config points at a removed binary.

Documentation updates follow from what the run-through establishes:

- The README's description of the flow, the stage count, and the tool list
- The changelog, including the reversal of the always-dark entry from the unreleased section, since themes now follow the system again
- Any flag or command shown in a hint, which must match the slug-based forms
- The revert and uninstall promises, stated with the manual-checklist caveat rather than as an unqualified claim

## Acceptance criteria

- [ ] A full run completes on a real Mac with the recommended selection
- [ ] A second full run completes with the minimum selection and the opposite answer to each question
- [ ] The terminal relaunch hands off correctly and the wizard resumes at the right stage
- [ ] The notification banner appears, and clicking it focuses the terminal
- [ ] The drop-down terminal responds from another application after accessibility is granted
- [ ] The prefix key works in the multiplexer after being freed, when that option was chosen
- [ ] Config revert runs clean, and every item on the printed manual checklist genuinely restores the setting it names
- [ ] Uninstall leaves no config referencing a removed binary, and a fresh shell opens with no errors
- [ ] Any defect found is filed as its own issue rather than fixed silently in this one
- [ ] README, changelog, and all in-script hints match the shipped behaviour
- [ ] The always-dark changelog entry is reversed to reflect following the system
- [ ] The revert promise is documented together with what it cannot undo

## Blocked by

- All other issues in this feature
