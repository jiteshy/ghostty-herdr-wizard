# Named stage registry with declared targets and REPLACES badges

Status: ready-for-agent

## What to build

Restructure the wizard from 27 numbered stages into a registry of named stages, each declaring what it will touch, and use those declarations to warn honestly before anything is overwritten.

**Names replace numbers on the command line.** Stages become conditional on tool selection in the next slice, which means numbers shift from user to user: one person's stage 11 is another's stage 8, so every number printed in a hint, written in the README, or suggested in a skipped-item message is wrong for somebody. Flags take slugs instead (`--only review`, `--skip yazi,github`, `--from editor`), and the listing flag prints them. Numbers survive only in the progress header, where they are just progress.

The new stage set, collapsing the old 27 to a fixed core plus one stage per selected cluster:

| Slug | Interactive | Covers |
|---|---|---|
| `choices` | all questions | every prompt, plus the plan and confirmation |
| `install` | no | the mandatory tools plus everything selected |
| `ghostty` | yes | write config, relaunch into Ghostty |
| `herdr` | sometimes | config, prefix key, agent integration, tab plugin, reload |
| `macos` | yes | notification and quick-terminal permissions |
| `prompt` `shell` `editor` `review` `yazi` `github` `statusline` | no | one each, selected only |
| `tour` | yes | assembled from selections |

Minimum run is 6 stages, maximum 13.

**Each stage declares its target paths**, and immediately before running, the wizard checks which of them already exist and prints the truth: either "adds new files only", or a REPLACES warning naming the specific files at stake, where their backups go, and how to undo. A static hand-written label would lie in both directions — crying wolf for a user with no existing config, staying quiet for one whose setup is hand-tuned. Computing it from the filesystem is truthful for free, and the same declarations feed the plan summary in the next slice.

The per-file diff and confirmation that already happen at write time stay exactly as they are.

Stage selection also needs to survive between runs, so record the user's answers in a choices file under the wizard's state directory. A targeted re-run then needs no re-answering, and a plain re-run can offer to reuse the previous answers. Populating that file is this slice's job only insofar as the registry reads it; the questions themselves arrive next.

## Acceptance criteria

- [ ] Every stage has a stable slug, and the listing flag prints slug plus description
- [ ] `--only`, `--skip` and `--from` accept slugs; passing a number or an unknown slug prints the valid list and exits non-zero
- [ ] The old numeric forms no longer appear in any hint, message, or doc string
- [ ] The progress header shows position out of the number of stages that will actually run for this user
- [ ] Each stage declares its target paths in one place, adjacent to the stage itself
- [ ] Before a stage runs, existing targets are listed under a REPLACES warning naming each file, its backup location, and the revert command
- [ ] A stage whose targets are all absent prints the additive message instead, with no warning
- [ ] The badge reflects the actual filesystem at the moment the stage runs, not a hardcoded label
- [ ] Choices persist to the wizard's state directory and are read back on a later run
- [ ] A targeted re-run such as `--only review` uses saved answers and asks nothing
- [ ] All existing stage behaviour is preserved; this slice restructures and reports, it does not change what gets written

## Blocked by

- `01-journal-and-backup-store`
