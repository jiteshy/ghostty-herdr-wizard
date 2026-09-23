# Journal and backup store, with `--revert` for replaced files

Status: ready-for-agent

## What to build

The spine of the whole redesign: a persistent record of what the wizard changed, and a `--revert` that reads it back. This is the tracer bullet — one config file is written, journaled, backed up, and restored end to end. Everything else in this feature writes through the machinery built here.

State lives in `~/.ghostty-herdr-wizard/`: an append-only `journal.tsv` spanning all runs, and a `backups/` directory. Only the `MODIFY` entry type is in scope (a file that already existed and was replaced); the other types come in the next slice.

Two existing behaviours must change:

**The backup store becomes first-ever-wins across all runs.** Today the backup directory is timestamped per run, and the backup helper keeps only the first copy *within* a run. On a second run the wizard therefore backs up its own output from run 1 and labels it the original, so a revert would restore the user to the wizard's state rather than their own. A path must be captured the first time it is ever touched and never overwritten afterwards.

**Journal entries are written by the existing file helpers**, not by individual stages. The helper that writes a file if it differs, and the helper that upserts a marked block, are the chokepoints — instrumenting them means every current and future stage gets revert support without knowing the journal exists.

Pick the Ghostty config stage as the one stage migrated in this slice. Leave every other stage alone.

`--revert` reads the journal in reverse and restores `MODIFY` entries from the backup store, then archives the journal so a later run starts clean.

## Acceptance criteria

- [ ] `~/.ghostty-herdr-wizard/` is created on first run with `journal.tsv` and `backups/`
- [ ] A `MODIFY` entry records the path, its backup reference, and the sha256 of exactly what the wizard wrote
- [ ] The backup of a path is captured only the first time it is ever touched, and is not overwritten on subsequent runs
- [ ] Running the wizard twice against the same pre-existing file leaves the backup holding the user's original content, not the wizard's run-1 output
- [ ] `--revert` restores every `MODIFY` entry and reports each restored path
- [ ] `--revert` archives the journal afterwards, so a subsequent run starts a fresh one
- [ ] `--revert` on a machine that has never run the wizard exits cleanly with a clear message, not an error
- [ ] The journal is append-only: no code path rewrites or truncates it
- [ ] Manual check: run the wizard against an existing Ghostty config, confirm the journal entry, run `--revert`, confirm the original config is byte-identical to before

## Blocked by

None - can start immediately
