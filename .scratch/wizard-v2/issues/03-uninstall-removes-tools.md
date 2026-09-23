# `--uninstall` removes wizard-installed tools

Status: ready-for-agent

## What to build

A second flag that goes beyond config revert and removes the software the wizard installed. `--revert` restores configs and leaves tools alone; `--uninstall` runs the full revert first, then offers to remove packages.

The ordering is not a preference, it is a safety requirement. Removing binaries while configs still reference them leaves the machine worse than either flag alone: the shell would still initialise a deleted prompt, git would still page through a deleted pager, and the terminal would still try to launch a deleted multiplexer. Every new shell would error. So `--uninstall` always implies `--revert`, and always runs it first.

Only packages the wizard actually installed may be removed. The brew helper already computes which of the requested formulae were missing before it ran, so journal that distinction: a formula the user already had is recorded as pre-existing and is never a removal candidate. Three package sources need journaling:

- Homebrew formulae and casks, marked as newly installed or pre-existing
- herdr plugins, removed by unlinking or uninstalling through herdr
- Packages from other managers the wizard invokes, such as yazi flavours and downloaded bat themes

Removal is confirmed per package, not in bulk, so a user can keep Neovim while dropping the rest.

Node is explicitly out of scope and must never be touched by this flag — see the herdr-hunk slice for why.

## Acceptance criteria

- [ ] `--uninstall` performs the complete `--revert` before removing any package
- [ ] Formulae the user already had before running the wizard are never offered for removal
- [ ] Each removal is confirmed individually, and declining one does not abort the rest
- [ ] herdr plugins installed by the wizard are unlinked or uninstalled through herdr, not by deleting directories
- [ ] Non-brew packages (yazi flavours, bat themes) are removed through their own manager
- [ ] Node is never uninstalled, downgraded, or otherwise modified
- [ ] After `--uninstall`, no shell startup file, git config, or terminal config references a removed binary
- [ ] Opening a new shell after `--uninstall` produces no errors or warnings
- [ ] `--uninstall` on a machine with nothing installed by the wizard exits cleanly

## Blocked by

- `02-revert-all-entry-types`
