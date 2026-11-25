import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));

function readMarkdown(path) {
  const match = readFileSync(path, "utf8").match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) throw new Error(`pstack: no frontmatter in ${path}`);
  return { meta: Bun.YAML.parse(match[1]), body: match[2] };
}

const readSkills = () =>
  readdirSync(join(root, "skills"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const path = join(root, "skills", entry.name, "SKILL.md");
      const { meta, body } = readMarkdown(path);
      return {
        id: entry.name,
        name: meta.name,
        description: meta.description,
        ...(meta["disable-model-invocation"] ? { autoinvoke: false } : {}),
        path,
        content: body,
      };
    });

const readAgents = () =>
  readdirSync(join(root, "agents"))
    .filter((file) => file.endsWith(".md"))
    .map((file) => ({ id: file.slice(0, -3), ...readMarkdown(join(root, "agents", file)) }));

const commandText = (id, request) =>
  `Load the \`${id}\` skill with the \`skill\` tool (ID \`${id}\`), then follow it. ` +
  `When it names another skill (\`/name\` or **name**), load that ID the same way. ` +
  `A playbook is a file the skill tells you to open, not a skill ID. The request:\n\n${request}`;

export default {
  id: "pstack",
  async setup(ctx) {
    const skills = readSkills();
    const agents = readAgents();

    // An ID the user already has stays theirs.
    await ctx.skill.transform((editor) => {
      for (const skill of skills) if (!editor.get(skill.id)) editor.add(skill);
    });
    await ctx.command.transform((editor) => {
      for (const { id, description } of skills) {
        if (id.startsWith("principle-")) continue;
        editor.add({
          name: id,
          description,
          execute: ({ sessionID, prompt, delivery }) =>
            ctx.session.prompt({ ...prompt, sessionID, delivery, text: commandText(id, prompt.text) }),
        });
      }
    });
    // The editor has no add. update creates an unknown agent. No agent gets a
    // model, so it runs on the chat's model until the user's config sets one.
    await ctx.agent.transform((editor) => {
      for (const { id, meta, body } of agents) {
        if (editor.get(id)) continue;
        editor.update(id, (agent) => {
          agent.mode = meta.mode;
          agent.description = meta.description;
          if (body.trim()) agent.system = body;
          agent.permissions.push(...(meta.permissions ?? []));
        });
      }
    });
  },
};
