# CLAUDE.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This is a curated collection of VS Code prompt files and AI agent definitions. There are no build steps, tests, or dependencies — the repository contains only static markdown files with YAML frontmatter and an MCP server configuration.

Prompts and agents are installed by symlinking into `~/.config/Code/User/prompts/`.

## File Conventions

- **Agents** live in `agents/` and are named `[name].agent.md`
- **Prompts** live in `prompts/` and are named `[action].prompt.md`
- All files use YAML frontmatter with fields: `name`, `description`, `model`, `tools` (or `agent`)
- Agents use `tools` to declare capabilities (e.g., `read`, `edit`, `search`)
- Simple prompts use `agent` instead (e.g., `agent: edit`, `agent: ask`)

## MCP Configuration

`mcp.json` defines Model Context Protocol servers.

## Writing New Prompts/Agents

When adding a new prompt or agent, follow the patterns in existing files:
- Keep frontmatter minimal and consistent with existing files
- Use structured output formats (severity levels, tables, categorized findings) for review/analysis prompts
- Include clear scope constraints so the AI stays focused
- For agents that produce reports, specify both chat output and file output strategies (see `security-audit.prompt.md` as an example)
