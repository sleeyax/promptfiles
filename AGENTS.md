# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This is a curated collection of AI skills and agent definitions. There are no build steps, tests, or dependencies — the repository contains only static markdown files with YAML frontmatter and an MCP server configuration.

Agents are installed by symlinking into `~/.config/Code/User/prompts/`. Skills (used as Claude Code's replacement for slash commands in this repo) are installed via the [`skills`](https://www.npmjs.com/package/skills) npm CLI; agents and `mcp.json` are still installed by symlink.

## File Conventions

- **Agents** live in `agents/` and are named `[name].agent.md`
- **Skills** live in `skills/<name>/SKILL.md` (one subdirectory per skill, file always named `SKILL.md` — required for `npx skills` discovery). Skill frontmatter must include `name` and `description`.
  - `.claude-plugin/plugin.json` lists every skill path under a `name` field so `skills list` groups them under a "Sleeyax Skills" header. The `skills` array is maintained manually — when adding or renaming a skill directory, update `.claude-plugin/plugin.json` too, or the new skill won't be grouped.
- Agents use YAML frontmatter with fields: `name`, `description`, `model`, `tools`
- Agents use `tools` to declare capabilities (e.g., `read`, `edit`, `search`)

## MCP Configuration

`mcp.json` defines Model Context Protocol servers.

## Writing New Skills/Agents

When adding a new skill or agent, follow the patterns in existing files:
- Keep frontmatter minimal and consistent with existing files
- Use structured output formats (severity levels, tables, categorized findings) for review/analysis skills
- Include clear scope constraints so the AI stays focused
