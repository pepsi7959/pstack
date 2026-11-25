# Set up pstack

In this page you install pstack, pick which models pstack uses, and run your first task. Setup is one command.

## Install pstack

Add the clone's absolute path to `plugins` in your `opencode.json`, then run `opencode reload`:

```json
{
  "plugins": ["/absolute/path/to/pstack"]
}
```

The plugin registers the skills, slash commands, and agents. A skill or command of yours with the same name stays yours. An agent of yours with a pstack agent's name is layered on top of it: your description, prompt, and model win, and pstack's permissions stay. Give it another name to keep it wholly yours. Run `opencode reload` again after you pull or edit a skill, because opencode keeps the text it loaded.

## Pick your models

You can skip this. Every pstack role is an opencode agent without a model, so it runs on your chat's model. To give roles their own models, run:

```text
/setup-pstack
```

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) lists the models you can use, shows you each role, and asks what you want. It writes `agents.<id>.model` in your own `opencode.json` and nothing else. To restore a role, delete its `model`.

A review panel is one subagent per `pstack-runner-*` agent. It is worth more when the seats run on different vendors. `pstack-judge` counts in full on another vendor than your chat, and as weak evidence on another model of the same vendor. On the same model it is skipped, and the reply says so.

## Accept the verification offers, or don't

At the end of setup, `/setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.opencode/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

Then setup offers once to generate a formal verification skill with [`/create-formal-verification-skill`](../../skills/create-formal-verification-skill/SKILL.md), unless the project already has one. Tests check the cases someone thought to write. A formal verification skill checks one key property of your code, such as "a job never runs twice at once", in every case within a stated scope. Say yes when your code has concurrency, retries, a state machine, or a parser, where a bug is costly and tests rarely reach the case that breaks. Otherwise say no, and run it later if that changes. [Verify and ship](./06-verify-and-ship.md#prove-a-property-with-a-formal-verification-skill) covers it.

After setup, start a new chat.

## Keep the cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/setup-pstack` and pick cheaper models. A strong model in the main chat with cheaper, faster models in the code roles is a good split.
- Delete a role's `model` so it runs on the chat's own model.
- Set `"disabled": true` on a `pstack-runner-*` agent. Each seat runs one subagent.
- Save `/poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt.

From here you can type normal follow-ups. The command loads the skill once, and it fades as a long chat moves on. Start each new task with `/poteto-mode`.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
