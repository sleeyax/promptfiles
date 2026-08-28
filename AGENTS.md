# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This is a curated collection of AI skills and agent definitions. There are no build steps, tests, or dependencies — the repository contains only static markdown files with YAML frontmatter.

Agents are Claude Code subagents, installed by symlinking into `~/.claude/agents/`; `scripts/install-codex-agents.sh` generates Codex TOML equivalents from the same markdown files. Skills (used as Claude Code's replacement for slash commands in this repo) are installed via the [`skills`](https://www.npmjs.com/package/skills) npm CLI.

The repo also doubles as a Claude Code marketplace hosting one plugin, `sleeyax-skills@sleeyax`, that bundles every skill, both agents, and the output styles. See [Plugin manifests](#plugin-manifests).

## Managing the local install

Prefer the `skills` CLI for anything that changes what is installed on the user's machine.
Global installs live in `~/.agents/skills/<name>/`, and each agent directory symlinks to them.

```bash
npx skills list -g                          # what is installed globally
npx skills add . -s '*'                     # install every skill from this working copy
npx skills add . -l                         # list what's installable here, without installing
npx skills update -g                        # pull the latest versions
npx skills remove --global <name>... -y     # uninstall by skill name
```

Install from `.`, not from `sleeyax/skills` — the latter pulls the published GitHub copy and silently ignores uncommitted local work.

`remove` and `add` are interactive by default, but the CLI detects it is running under an agent and falls back to a non-interactive run.
Pass `-y` anyway so the command can't block.
`-y` on `add` also skips the scope prompt and auto-detects, so pass `-g` alongside it when the target is the global install.

If the CLI can't do the job — it's unavailable, the command fails, or the install is in a state it won't reconcile — edit `~/.agents/skills/` and the symlinks under `~/.claude/skills/` directly, and say that you did.
Leave no dangling symlinks behind.

Removing a skill from this repo does not touch an existing install, so uninstall it separately.

The `skills` CLI does not handle output styles. Install those by symlinking `output-styles/` into `~/.claude/output-styles/`, or let the plugin ship them.

## File Conventions

- **Agents** live in `agents/` and are named `[name].md`, matching the kebab-case `name` frontmatter field
- **Skills** live in `skills/<category>/<name>/SKILL.md` (one subdirectory per skill, grouped under a category folder, file always named `SKILL.md` — required for `npx skills` discovery). Skill frontmatter must include `name` and `description`.
  - Categories are `delegation`, `frontend`, `git`, `implementation`, `integrations`, `planning`, `review`, `setup`, and `utils`. They organise the repo only — skill names stay flat and globally unique, since the `skills` CLI installs them by `name`, not by path.
  - A category may nest a further subdirectory when a group of skills shares a platform (`skills/integrations/openshift/query-db`). Nesting is invisible to the tooling as long as `plugin.json` lists the full path.
  - A skill directory may carry an `agents/openai.yaml` with `policy.allow_implicit_invocation: false` — the Codex equivalent of `disable-model-invocation: true` in the frontmatter. Set both or neither.
  - `.claude-plugin/plugin.json` lists every skill path, so both `skills list` and Claude Code's plugin loader pick them up. The `skills` array is maintained manually — when adding, moving, or renaming a skill directory, update it too, or the skill won't load.
- Agents use YAML frontmatter with fields: `name`, `description`, and optionally `tools` and `model`
- `tools` is a comma-separated list of Claude Code tool names (e.g., `Read, Edit`); omit it to inherit all tools
- Agent bodies must stay Codex-compatible: the Codex install script extracts frontmatter with line-based parsing, so keep `name` and `description` on single lines
- **Output styles** live in `output-styles/[name].md` and are picked up by the plugin's default `output-styles/` scan, so they are not listed in `plugin.json` — keep them flat, one level deep. Frontmatter is `name`, `description`, and `keep-coding-instructions`, which must be `true` for any style that shapes tone or format while Claude is still coding, or Claude Code drops its built-in software engineering instructions. Never set `force-for-plugin`: it would impose the style on everyone who installs the plugin.
  - `unslop.md` is vendored from [cursor/plugins](https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md). Keep its body byte-identical to upstream so it can be re-synced; frontmatter is ours.

## Plugin manifests

Two files in `.claude-plugin/` make the repo installable as a Claude Code plugin:

- `plugin.json` — the plugin manifest. Its `skills` array is the authoritative list of skill directories, because the default `skills/` scan only looks one level deep and this repo nests skills under category folders. Agents are *not* listed: the default `agents/` scan finds them, and listing individual agent files here makes Claude Code load none of them, since the marketplace entry's `source` is the repo root. Output styles are not listed either, for the same reason.
- `marketplace.json` — the marketplace catalog, with one entry pointing at `./`.

No `version` is set in either file, so Claude Code falls back to the git commit SHA and users get updates on every commit. Adding a `version` would pin the plugin until it's bumped.

Validate after changing either file, or after adding or moving a skill:

```bash
claude plugin validate .
```

Missing component paths are reported as errors. The "no version specified" warning is expected. To verify what actually loads without touching your own config, install into a throwaway config dir:

```bash
CLAUDE_CONFIG_DIR=$(mktemp -d) sh -c 'claude plugin marketplace add "$PWD" && claude plugin install sleeyax-skills@sleeyax && claude plugin details sleeyax-skills'
```

## Writing New Skills/Agents

When adding a new skill or agent, follow the patterns in existing files:
- Keep frontmatter minimal and consistent with existing files
- Use structured output formats (severity levels, tables, categorized findings) for review/analysis skills
- Include clear scope constraints so the AI stays focused
