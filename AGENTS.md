# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This is a curated collection of AI skills and agent definitions. There are no build steps, tests, or dependencies — the repository contains only static markdown files with YAML frontmatter.

Agents are Claude Code subagents, installed by symlinking into `~/.claude/agents/`; `scripts/install-codex-agents.sh` generates Codex TOML equivalents from the same markdown files. Skills (used as Claude Code's replacement for slash commands in this repo) are installed via the [`skills`](https://www.npmjs.com/package/skills) npm CLI.

## File Conventions

- **Agents** live in `agents/` and are named `[name].md`, matching the kebab-case `name` frontmatter field
- **Skills** live in `skills/<name>/SKILL.md` (one subdirectory per skill, file always named `SKILL.md` — required for `npx skills` discovery). Skill frontmatter must include `name` and `description`.
  - `.claude-plugin/plugin.json` lists every skill path under a `name` field so `skills list` groups them under a "Sleeyax Skills" header. The `skills` array is maintained manually — when adding or renaming a skill directory, update `.claude-plugin/plugin.json` too, or the new skill won't be grouped.
- Agents use YAML frontmatter with fields: `name`, `description`, and optionally `tools` and `model`
- `tools` is a comma-separated list of Claude Code tool names (e.g., `Read, Edit`); omit it to inherit all tools
- Agent bodies must stay Codex-compatible: the Codex install script extracts frontmatter with line-based parsing, so keep `name` and `description` on single lines

## Writing New Skills/Agents

When adding a new skill or agent, follow the patterns in existing files:
- Keep frontmatter minimal and consistent with existing files
- Use structured output formats (severity levels, tables, categorized findings) for review/analysis skills
- Include clear scope constraints so the AI stays focused
