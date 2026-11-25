### Autopilot-stack

Run the Autopilot-full playbook, but never merge in this run, even when the request says to. Say so in your first message. Do not plan a merge, offer one as an option, or continue into Shipping. Landing the stack takes a new request, which runs the Shipping playbook.

1. **In place of step 5, stop at verified.** Stop when each PR is verified and green at its current head, then hand the PRs to the operator. After the handoff, nobody pushes without the operator's go. Every loop tick prompt names this file, so each tick sees the no-merge rule.
2. **Stack a PR only when it builds on another PR.** This is the one exception to step 3. Base the PR on the other PR's branch in place of trunk, per `playbooks/opening-a-pr.md`. In place of step 2's rebase onto trunk, each PR rebases onto its parent PR's branch, and the stack root rebases onto trunk. A new head on the lower PR restacks the PRs above it. Before any restack, follow "Before you rewrite a PR branch" in [Merge rules](../references/merge-rules.md). Its verdict record decides whether a restacked PR keeps its verdict.

**Reply:** list each PR with its verdict, in place of what merged, and say that this playbook does not merge.
