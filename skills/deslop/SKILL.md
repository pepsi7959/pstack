---
name: deslop
description: Remove AI-generated code slop and clean up code style
disable-model-invocation: true
---

# Remove AI code slop

Check the diff against the base of this work and remove AI-generated slop introduced in the branch. The base is the PR's base branch, else the branch this one was cut from, else the default branch. Touch only lines the branch added or changed.

## Focus Areas

- Extra comments that are unnecessary or inconsistent with local style
- Defensive checks or try/catch blocks that are abnormal for trusted code paths
- Casts to `any` used only to bypass type issues
- Deeply nested code that should be simplified with early returns
- Other patterns inconsistent with the file and surrounding codebase

## Guardrails

- Keep behavior unchanged unless fixing a clear bug.
- Prefer minimal, focused edits over broad rewrites.
- Rerun the checks that proved the change, and revert any edit that breaks one.
- Keep the final summary concise (1-3 sentences).
