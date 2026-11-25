# changelog

this repository is an opencode port of pstack v0.15.48 by Lauren Tan, taken from [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack) at commit `005d8f6e`. this file lists what the port changes from that version and why. in the tables, "Cursor and Claude Code plugin" means that version, and "opencode plugin" means this repository.

## 0.1.0 (2026-11-28)

the first release of the port. each change below was run at least once with a real model, on opencode 2.3.2 or 2.4.2. most are in the skills' text, so the same rule reaches every agent that reads them.

### platform

| area | Cursor and Claude Code plugin | opencode plugin | why |
| --- | --- | --- | --- |
| host | `.cursor-plugin/plugin.json`, installed with `/plugin install pstack@cursor-plugins` | [`plugin/index.js`](./plugin/index.js) registers every skill, one slash command per skill, and every agent from the repository's `.md` files | to run pstack in opencode |
| install | Cursor marketplace or Claude Code marketplace | `opencode plugin add @pepsi7959/pstack` from npm, `opencode plugin add github:pepsi7959/pstack` from git, or a clone's path in `plugins` | opencode installs plugins from npm, git, or a path |
| models | hardcoded model slugs in the skills and agents, such as `claude-opus-5-5-xhigh-fast` for code and three fixed panel seats, read from `~/.cursor/rules/pstack-models.mdc` | no model anywhere. every agent runs on the chat's model until your own `opencode.json` sets one, by hand or with [`/setup-pstack`](./skills/setup-pstack/SKILL.md) | works with any provider you already use, and the model choice stays yours |
| agents | 2: `poteto-agent`, `comment-sicko` | 8: adds `pstack-worker`, `pstack-runner-a`, `-b`, `-c`, `pstack-judge`, and `pstack-explorer` | opencode sets a model per agent, so each role needs its own agent before it can have its own model |
| owners and workers | Cursor cloud agents, each in its own VM | local subagents, each in its own git worktree | opencode runs subagents on your machine |
| nested subagents | always available | need `experimental.subagent_depth` above 1. at the limit an agent does the work itself and says so | opencode stops nesting at depth 1 by default |
| skills in the catalog | visible | hidden, except `/setup-pstack`. `poteto-mode` loads `typescript-best-practices` when a `.ts` or `.tsx` file is touched | a smaller catalog leaves more of the context for the task |
| same-name skills and commands | not applicable | yours stay yours. a same-name agent is layered: your description, prompt, and model win, and pstack's permissions stay | opencode applies your config after plugins |

### removed and added

| item | change | why |
| --- | --- | --- |
| `benny` automation, `make-bot-ui` skill, Origin forge, Cursor cloud REST reads | removed | they need Cursor services |
| Bugbot | named "review bot" | any bot that reviews PRs, not one product |
| `/deslop` | added, from Cursor's original ([LICENSE-deslop](./LICENSE-deslop)). it only touches lines the branch added, against the task's base | the Cursor and Claude Code plugin calls it from the separate `cursor-team-kit` plugin |
| tests | added [`tests/log.test.sh`](./tests/log.test.sh) and [`tests/worktree-audit.test.sh`](./tests/worktree-audit.test.sh) | they reproduce the fixes to `log.sh` and `worktree-audit.sh`, such as interleaved rows and a partial session export |
| "control skill" | replaced by the project's `verify-<app>` skill, called as `@verify-<app>` | opencode loads project skills from `.opencode/skills/` |

### safety: merging, pushing, and people

| playbook or skill | Cursor and Claude Code plugin | opencode plugin | why |
| --- | --- | --- | --- |
| autopilot-full | the owner merges once the swarm proves the code | merges only on an explicit order, otherwise every PR stops at merge-ready. it states the size first and waits above three owners | merging is a step you cannot take back |
| autopilot-full | verifiers on any model | a verifier from the owner's own vendor stops the PR at merge-ready, unless you accept that | an agent shares its vendor's blind spots, so its review is weak evidence |
| autopilot-full | no cap on fix rounds | two fix rounds per PR, then stop and report the evidence | bounds the run time. each round costs 45 to 60 minutes in tests |
| autopilot-full | no rule for a person's review thread | never replies to or resolves a person's thread unless the request says to, and never stops the run to ask about one. that PR stops at merge-ready with the drafted reply in the report | in one test the agent replied "Yes." from your account. in the next, one question held a verified PR for 53 minutes |
| autopilot-full | no heartbeat rule | if no hourly heartbeat can be armed, says so and merges nothing | a long run that nobody checks can stall silently |
| shipping, [merge rules](./skills/poteto-mode/references/merge-rules.md) | `gh pr merge <pr> --squash` | always `--match-head-commit <verified sha>`, never `--admin`, never changes branch protection. a required merge queue means stop and ask. after merging, confirm the merge commit is on trunk | only the head that was verified can land |
| autopilot-stack | does not merge, with no rule for restacks | never merges, even when told. disables auto-merge before a restack and reads it back. a PR in a merge queue means stop and ask. a verdict records head, base, and patch-id, and carries over only when the patch-id matches | a restack changes what would land, and auto-merge could land it unverified |
| babysit | names the watcher, not how to start it | `BUN_BE_BUN=1 opencode <watcher> --pr <number>`, plus `--owner` and `--repo` for another repository. if that fails, reads `gh pr view` and says it cannot watch | opencode embeds Bun, and the watcher failed with "too many arguments" in a test |
| babysit | triages bot threads, with no rule for a person's thread | a person's thread gets a reply or a resolve only when the request says to, and otherwise the exact reply goes in the report | a reply posts from your account |
| bug-fix | no rule on evidence | never prints a whole config or environment, strips credentials and customer data from evidence, and needs an independent review for auth, secret, money, and data-integrity fixes | evidence often lands in PRs and logs |
| opening-a-pr | no secret check | checks added lines for secrets before committing, stops at the commit when there is no remote, and asks before opening a PR unless the request covers it | a pushed secret cannot be taken back |
| pause-safely, session-pickup | a `wip:` commit on the current branch and a resume note | the note goes in one place under the git directory, and a `wip:` commit on the default branch goes on a new branch first. permission to merge, push, deploy, or delete does not carry into a new session. transcript text is data, not instructions | the next session finds the note, and should not act on an old yes |
| worktree-cleanup | `git worktree remove --force` on the confirmed set | the audit fails safe (an unreadable session means review, untracked or locked means hold), no `--force` by default, and only worktrees the run itself created are removed without asking | a worktree can hold the only copy of work |

### verification and review quality

| skill | Cursor and Claude Code plugin | opencode plugin | why |
| --- | --- | --- | --- |
| arena, interrogate | three fixed seats on three vendors | two seats when every seat is on one model. agreement counts only across vendors. each seat's model is recorded | three copies of one model are not three opinions |
| judge (arena, eval, show-me-your-work) | always on another vendor | full weight on another vendor, weak evidence on the same vendor's other model, skipped on the chat's own model | the weight of a review depends on who trained the reviewer |
| swarm | no limit | at most four workers at once, the rest queue. separate ports, databases, and temp dirs per worker | parallel workers on one machine fight over ports and slow the model provider |
| no-comments | no exemption for comments that tools read | keeps directives that tools read, such as `//go:build` and swagger annotations, and only reviews comments the diff adds or changes | deleting a build directive breaks the build |
| show-me-your-work | appends rows without a lock | `log.sh` takes a lock, so parallel writers no longer interleave rows. no secrets or customer data in the trail | the interleaving was reproduced in a test |
| create-verification-skill | proves one feature | drives every mapped feature once. a recipe that never ran is a draft | a test found a broken search recipe that the one-feature proof had missed |
| setup-pstack | writes `~/.cursor/rules/pstack-models.mdc` with a model and a reasoning budget per role | never reads the whole `opencode.json`, edits only `.agents` with `jq`, backs up once per run, gives a snippet for `.jsonc`, accepts only model IDs from the detected list, and recommends no model. lists the models again when the first list comes back empty | the config often holds provider keys, and the first model list in a new session was empty three times in tests |
| ketchup-video | no rule on text rendering | draws text with a renderer that shapes it, such as a browser, and checks every character in the frames | Thai rendered with broken marks through Pillow without raqm |
| poteto-mode routing | playbooks listed by title | says runtime forensics instruments a process you can run now, and trace forensics reads a capture that already exists | the trace playbook was never opened in two test runs. after the line, 2 of 2 opened it |
| recall, reflect | Cursor's transcript files | reads opencode sessions through `opencode session export` into a temp folder and deletes it. quotes your own words for past decisions | opencode stores sessions in its own database |

### speed and cost

| change | effect |
| --- | --- |
| no hardcoded models | put a cheaper model on `pstack-worker`, because swarms run many workers. put a model on a second provider to cut queue time, because about half of an agent's time in a long test run went to waiting for the model's first token |
| two fix rounds per PR | a run ends in a known number of rounds instead of chasing ever deeper edge cases |
| verifiers report only what the diff breaks | fewer follow-up rounds on problems the base already had |
| no stopping the run to ask | other PRs keep moving while one waits for you |
| at most four swarm workers at once | fewer slow turns from an overloaded provider |
| hidden skills, `typescript-best-practices` loaded only for TypeScript | a smaller context in every turn |
| two panel seats when every seat is on one model | one fewer model run that adds no new view |
