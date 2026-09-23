# Four-tab layout and the rewritten tabs prompt

Status: ready-for-agent

## What to build

Fix the confusing tabs question and settle the default layout that every new workspace and worktree opens with.

**The prompt.** Today it is two chained yes/no questions: the first asks whether to open a default set of tabs, and only *after* answering does the user get shown what that set is, followed by a second yes/no asking whether to use it. The first question is unanswerable, and "no" means two different things depending on which question it lands on.

Replace with: explain, show, then one numbered choice. Two lines on what a workspace is and what tabs are inside it, then the four tabs each with a one-line purpose, then a single choice between using them, renaming them, and skipping default tabs altogether. A yes/no cannot cleanly express three outcomes.

**The layout.** Four tabs, created by the existing event-driven plugin on both workspace and worktree creation:

1. agents — where the coding agents run
2. source code — the editor on the files
3. local server — dev server and logs
4. git review — hunk-by-hunk review of what the agent changed

Tab 4 auto-launches the review. The tab-creation API has no flag for running a command, so this goes through the review plugin's own action, invoked with the placement that fills the focused pane rather than the placement that spawns a new tab — otherwise a fifth tab appears. Sequence: create the tabs, focus tab 4, invoke the review, focus tab 1.

One trade-off is accepted deliberately: a brand-new workspace or worktree has nothing to review, so the plugin opens on its working-tree fallback and needs a refresh once the agent actually edits something.

When the review tool is not selected, or is unavailable because its own prerequisites are unmet, tab 4 stays a plain shell with the same label. The layout should not change shape based on what happens to be installed.

## Acceptance criteria

- [ ] The tabs prompt explains what a workspace and a tab are before asking anything
- [ ] All four tabs are shown with a one-line purpose each, before the question
- [ ] A single numbered choice replaces the two chained yes/no questions
- [ ] Choosing custom names accepts a list and applies it; empty input falls back to the defaults with a clear message
- [ ] Choosing to skip leaves new workspaces on the multiplexer's single starting tab, and unlinks the plugin if it was previously linked
- [ ] The default layout is the four named tabs, in order, on both workspace and worktree creation
- [ ] Tab 4 auto-launches the review in its own pane, without creating a fifth tab
- [ ] After creation the focus lands on tab 1
- [ ] Without the review tool, tab 4 is a plain shell with the same label and the layout is otherwise unchanged
- [ ] The existing guard against double-application on duplicate events still holds
- [ ] The plugin and its registration are journaled and removed on revert

## Blocked by

- `06-choices-stage-and-tool-picker`
