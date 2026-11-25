### Bug fix

**You own this task. Plan, review, verify.** Delegate investigation and the fix to subagents, stay in the lead. Pick each subagent's agent by role, per the Subagents section.

Be scientific. Every shipped line traces to runtime evidence. Belt-and-suspenders that "might help" is a hypothesis, not a fix. It does not ship. When evidence refutes a hypothesis, revert what it motivated. The smallest change the evidence justifies ships, nothing more.

Never print a whole config, environment, or service response while you debug. Select the fields you need. Keep credentials and customer data out of every quoted line.

1. Reproduce it yourself on the matching surface via the `verify-*` skill (Non-negotiables), even when a debug or instrumentation protocol says to ask the user to reproduce. Ask the user only with a stated, specific reason the real surface cannot reach the target, and only after driving it as far as it goes. If it won't reproduce directly, synthesize the trigger, tighten conditions, or instrument until it fires.
2. Binary-search the cause. Form the candidate hypotheses, then rule them out until one survives. Seed them with a trace of the affected subsystem and the **why** skill for regression history. Each pass, take the split that cuts the most remaining problem space, get runtime evidence, eliminate. When program state is unclear, add instrumentation or logging and read it as the code runs. Don't guess. Drive a long or stubborn hunt per the Autonomous run playbook. Confirm the surviving *mechanism* with runtime evidence before step 3's `architect` or an `interrogate` fan-out.
3. Plan the fix. If it crosses a function boundary, or changes a schema, concurrency or transaction behavior, or a contract others call, `architect` first. Delegate implementation to `poteto-agent` with a specific scope.
4. Verify on the same surface. The original repro now passes. "Inconclusive" or wrong-surface is not a pass. Flag it. Unit tests show branch behavior, not bug absence.
5. Stage the commits so the failing repro lands before the fix in git history. See the **tdd** skill for the failing-test-first cadence when the bug has a cheap local test path. Skip it when the test would be expensive, integration-heavy, or unclear.
   This is the canonical **principle-sequence-verifiable-units** skill, the failing test first and the fix on top.
6. A fix to authentication, secrets, money, or data integrity needs an independent correctness review by a fresh `pstack-worker` before it is merge-ready. If none can run, the review gate stays closed. Say so when the reviewer shares the author's vendor.
7. Run **Opening a PR**. If you deploy, confirm which version the runtime serves. A successful deploy command does not show that.

**Reply:** what was broken, root cause, fix, how you verified. Quote the decisive failing and passing lines verbatim.

#### Focused-fix exception

One delegate may investigate and fix without **why** and `architect` when all three hold. Write the evidence for each in the todo list before you skip. If one is false, unknown, or later refuted, return to steps 2 and 3. Every other step stays.

- Runtime evidence puts the cause in one subsystem.
- The fix changes no interface, schema, security, concurrency, or transaction behavior.
- A cheap regression check catches the failure.
