# Revert coverage for every entry type

Status: ready-for-agent

## What to build

Extend the journal and `--revert` from one entry type to all of them, and migrate every remaining stage to write through the instrumented helpers. After this slice, `--revert` returns a fully-configured machine to its pre-wizard state.

Entry types to add:

| Type | Records | Revert action |
|---|---|---|
| `CREATE` | path, sha | relocate (see below) |
| `BLOCK` | path, marker id | strip the fenced region only |
| `JSONKEY` | path, key, prior value or `<absent>` | delete the key, or restore its prior value |
| `MANUAL` | description, settings deep link | print in the closing checklist |

Three rules govern how revert behaves:

**Drift.** Each entry carries the sha of what the wizard wrote. If the file still matches, nobody touched it, so restore silently. If it differs, the user edited it since: show the diff and prompt, **defaulting to keeping their version**, and report it in the closing summary. Marked blocks are exempt from the drift check entirely, since their markers delimit our region precisely and can always be stripped surgically.

**Revert relocates, it never deletes.** No `rm -rf` anywhere in the undo path. Anything the wizard created is moved to `~/.ghostty-herdr-wizard/reverted/<timestamp>/` preserving relative paths, then the pre-wizard original is moved back. This matters most for the Neovim config directory: the editor stage moves an existing one aside and clones the LazyVim starter in its place, and months later that tree holds the user's own plugin configs and lockfile. Revert removes it from where Neovim looks without destroying it. A `--revert --restore` flag brings the last relocation back.

**Claude Code settings are key-level, never whole-file.** Two stages mutate `~/.claude/settings.json`, and Claude Code itself writes to that file as the user accepts permissions. A whole-file restore would wipe every accumulated permission, and the drift check would fire for every user on every run, making the warning meaningless. Journal the exact keys touched with their prior values and undo them individually. A full-file backup is still taken as a safety net but is never auto-restored.

Changes that only macOS System Settings can undo are journaled as `MANUAL` when the user confirms them: freeing Ctrl-Space, the notification permission, and Ghostty's Accessibility access. Revert prints them as a numbered checklist, each offering to open the right settings pane. Do not write to `com.apple.symbolichotkeys` or reset TCC — undocumented plists in an undo path is where surprises are least acceptable.

The herdr stage additionally needs a non-file undo hook, to reload the running server's config so a revert takes effect live rather than after a restart.

## Acceptance criteria

- [ ] All four new entry types are written by the appropriate helpers and understood by `--revert`
- [ ] A file whose sha still matches the journal is restored with no prompt
- [ ] A file that has drifted shows a diff and prompts, defaulting to keeping the user's version
- [ ] Kept-because-drifted files are listed in the closing summary
- [ ] Marked blocks are stripped surgically, leaving all content outside the markers untouched, regardless of drift
- [ ] Nothing in the revert path calls `rm`, `rm -rf`, or equivalent; created paths are moved into `reverted/<timestamp>/`
- [ ] Reverting a wizard-created Neovim config preserves files the user added, under `reverted/`
- [ ] `--revert --restore` brings the most recent relocation back into place
- [ ] Claude Code settings are reverted key by key; unrelated keys such as permissions and model are provably untouched
- [ ] `MANUAL` entries print as a numbered closing checklist with working settings deep links
- [ ] The revert path never writes to `com.apple.symbolichotkeys` and never invokes `tccutil`
- [ ] A running herdr server picks up the reverted config without needing a restart
- [ ] Every stage that mutates the filesystem now routes through an instrumented helper

## Blocked by

- `01-journal-and-backup-store`
