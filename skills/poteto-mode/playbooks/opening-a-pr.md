### Opening a PR

Invoked at the end of every other playbook.

Work from a git worktree off trunk, and keep unrelated work out of it. Rebase into small, landable commits. Run `/deslop` over the diff before commit, rerun the checks that proved the change, and revert any cleanup that breaks one.

Before you commit, wait for every subagent that uses the worktree to finish. If one is stuck, ask the user to stop it. Read `git status` and the diff you are about to ship. Look for secrets in the added lines and new files. On a hit, stop and name the file and line without printing the value.

Pushing and opening a PR publish the work. Do it when the request covers it, when it is unattended, or in an autopilot run. Otherwise ask first. With no remote, or when told not to push, stop at the commit and say so.

Title: `type(scope): subject`, naming a real symbol when one carries the change. Body: a one-minute briefing under 40 lines with these `##` headings in order, dropping empty ones: `## Why`, `## What changed`, `## Scope`, `## Tradeoffs` (only rejected alternatives a reviewer would otherwise ask about), `## Blast Radius`, `## Verification`.

Stack follow-ups by base branch. Open PRs ready, through the run's PR tool with `draft: false`. Without one, use `gh pr create` without `--draft`. Opening a PR does not start a babysit.
