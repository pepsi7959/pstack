---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
disable-model-invocation: true
---

# Arena

Open a todo list with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners: one per available `pstack-runner-*` agent. Keep at least two. Check each seat's model per the Subagents section of the **poteto-mode** skill and record it. When every seat runs on one model, use two seats, not three, and say so, because they share blind spots. Spawn more for multiple design directions, and reuse one seat when the work is generation-bound, not judgment-sensitive.
4. Give each candidate its own output location (a git worktree where possible, otherwise `candidate-<n>/` under one `mktemp -d`), per the **principle-separate-before-serializing-shared-state** skill.

## Phase B: Fan out

Spawn all N subagents in one message, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, spawn one `pstack-judge`. Check its model the same way. Another vendor than the chat's counts in full. The same vendor on another model runs, labelled weak evidence. The chat's own model is skipped, and you say so. While you read in Phase D, the judge scores each candidate, by path label, on each rubric criterion and recommends a base.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge when Phase C ran one. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the **principle-laziness-protocol** skill.

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the **principle-redesign-from-first-principles** skill, so the result stays coherent under one mental model. Don't paste mechanically.

If candidates from different vendors converge on one shape, that is strong agreement. Convergence on one model is not. Either way, note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the **principle-prove-it-works** skill. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Clean up

After Phase F, put each worktree this run created through the gates of the Worktree cleanup playbook. Remove what they clear. Candidates usually hold uncommitted files, so expect a hold: list those paths in the reply with what each one holds, and remove them only when the user says so.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming each seat's model, the base and why, the cross-judge's verdict or its weak or skipped status, each graft with its source candidate, what was rejected and why, any convergence or dropouts, the verification result, and the worktrees still on disk.
