---
name: setup-pstack
description: Choose which opencode model each pstack role runs on. Lists the models you can use and writes your choices to opencode.json. Use for /setup-pstack, "configure pstack models", or changing pstack's model choices.
---

# Setup pstack

pstack ships no model choice. Each role is an opencode agent without a `model`, so it runs on the chat's model. This skill writes the user's choices to `agents.<id>.model` in their own `opencode.json`. A user who skips it has a working setup.

## Roles

| Agent | Runs |
| --- | --- |
| `poteto-agent` | Code, prose, and judgment |
| `pstack-worker` | Swarm slices, verification, mechanical edits, dispatching |
| `pstack-runner-a`, `-b`, `-c` | One panel seat each for `arena` and `interrogate` |
| `pstack-judge` | Cross-judge and trail review, on another vendor than the chat |
| `pstack-explorer` | Read-only exploration for `how` |
| `comment-sicko` | `no-comments` |

## Steps

### 1. Detect available models

List the models and their variants (reasoning levels). Keep the filter, because the unfiltered output can hold provider credentials:

```bash
opencode api GET /api/model | jq -r '.data[] | select(.enabled) | "\(.providerID)/\(.id)\t\([.variants[]?.id] | join(","))"'
```

Each line is a `provider/model` ID, then its variants. Never write a model or variant that is not in that output. The first call in a new session can return nothing, so if the output is empty, run it once more. If it fails or is still empty, ask the user to paste the IDs they can use.

### 2. Load current state

Run the role listing from the Subagents section of the **poteto-mode** skill. `inherit` means the role runs on the chat's model. Treat every other value as the user's choice, and keep it unless they change it.

### 3. Ask and confirm

Show every role with its current model. Use the `question` tool when the session has it. Offer `inherit` and the detected models for each role, with a variant when the model has any. When the list is too long to offer as options, take a typed ID instead, and accept it only if it appears in the step 1 output. Otherwise ask again. Do not recommend a model by name, do not give example model IDs, and mark no option as recommended. These rules are what matter:

- `inherit` for everything is valid and is the default.
- A panel is worth more when its seats run on different vendors.
- `pstack-judge` counts in full on another vendor than the chat's model. On the same vendor's other model it counts as weak evidence. On the chat's own model it is skipped. A vendor is whoever trained the model, not the provider that serves it.
- A cheaper model on `pstack-worker` saves the most, because swarms run many workers.
- Two panel seats are the minimum.

### 4. Write the config

Never read `opencode.json` as a whole, because it often holds provider keys. `opencode debug paths` prints the global config directory. Work on its `opencode.json`, or on the project's own `opencode.json` when the choice is for one project.

1. Show the user the exact `agents` change, with placeholders filled in, and wait for a yes.
2. If the file is `opencode.jsonc`, or `jq empty <file>` fails because it has comments, do not edit it. Give the user the snippet to paste.
3. Otherwise back it up, and change only `.agents` with `jq`. This keeps the file's mode and prints nothing but the pstack agents:

```bash
f="<config>/opencode.json"; [ -e "$f" ] || (umask 077; echo '{}' > "$f")
cp -p "$f" "$f.pstack-bak" && (umask 077; jq '.agents["<id>"].model = "<provider>/<model>#<variant>"' "$f.pstack-bak" > "$f.pstack-new") && cat "$f.pstack-new" > "$f" && rm "$f.pstack-new"
jq '.agents | with_entries(select(.key | test("^(poteto-agent|comment-sicko|pstack-)")) | .value |= {model, disabled})' "$f"
```

Back up once per run, before the first write. A later write in the same run, such as step 5, skips the `cp -p` and runs `jq` on `"$f"` instead of `"$f.pstack-bak"`, so the backup keeps the file as it was before the run.

`#<variant>` is optional. To set a role to `inherit`, use `del(.agents["<id>"].model)`. To remove a seat, use `.agents["pstack-runner-<x>"].disabled = true`. Keep at least two seats. Tell the user where the backup is, and that it holds the same secrets as the file.

Never write a model into the pstack checkout.

### 5. Offer the experimental settings (optional)

Offer each once as a plain yes or no with neither marked as recommended, and write only what the user accepts, with the same recipe on `.experimental`:

- `experimental.subagent_depth: 2` lets a delegate spawn its own subagents. Without it, a delegate does that work itself.
- `experimental.todo: true` gives agents `todowrite`. Without it, they keep the list in the reply.
- `experimental.automations: true` allows a timed heartbeat on long runs.

### 6. Confirm

Run `opencode reload`, then run the role listing again and show the result. Every role must match the choice. Tell the user that a rerun updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /create-verification-skill." On yes, invoke `/create-verification-skill` (resolves wherever pstack is installed: workspace, user, or plugin). On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with /create-formal-verification-skill." On yes, invoke `/create-formal-verification-skill` (resolves wherever pstack is installed: workspace, user, or plugin). On no, move on without pushing.
