### Pause safely

**You own a clean stop. Leave a checkpoint a cold-start agent can resume from.** This is explicit only. On "keep going", "going to bed, keep going", or "don't stop", do not pause.

1. Stop at a safe boundary. Finish the current atomic step or back out of it. Start nothing new. Wait for nested subagents to finish. If one is stuck, tell the user so they can stop it.
2. Take no irreversible action to pause. No PR and no push unless you already had one out.
3. Make the work durable. Commit uncommitted edits as one clear `wip:` commit on the current branch so nothing is lost. On the default branch, make `wip/<slug>` first. Check the diff for secrets as Opening a PR says. If the tree is broken, say so in the commit body in one line.
4. Write the resume note off-context. Capture intent, what you were doing, progress and what's verified, current state, next steps, key files, and gotchas. Always write it to `$(git rev-parse --git-common-dir)/pstack/resume/<YYYYMMDD-HHMMSS>-<slug>.md`. Every worktree of the repository finds it there, and Git never commits it. Outside Git, use the work folder and say the path. Copy what the user asked to keep word for word and in order. Read the file back before you say the pause is ready. If a show-me-your-work trail exists, point at it instead of duplicating it.

**Reply:** where you are in the loop, what's on disk versus still in your head (paths, no diff dumps), the commits you made and whether the tree is clean, and the first action on resume. This is a pause, not a final report.
