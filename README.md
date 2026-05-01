# promptfiles

My collection of prompt files for various AI models and applications.

## Installation

### Skills

This repo's slash-command-style workflows are packaged as agent skills, installed via the [`skills`](https://www.npmjs.com/package/skills) CLI. The CLI supports Claude Code, Codex, Cursor, OpenCode, and [50+ other agents](https://github.com/vercel-labs/skills#supported-agents) — pass `-a <agent>` to target one (or omit and the CLI will prompt).

```bash
# install 
npx skills add sleeyax/promptfiles

# update
npx skills update

# uninstall
npx skills remove sleeyax/promptfiles
```

#### Local development

Install skills from your local clone so edits to `./skills/<name>/SKILL.md` are live in your agent:

```bash
# from the root of this repo (-s '*' = all skills, -y = skip prompts)
npx skills add . -s '*'
```

Verify with `npx skills list -g`.

#### Migrating from the old manual install

The old install put commands under `~/.claude/commands/` via `stow` and any skills under `~/.claude/skills/` via `ln -s`. Run from the root of your local clone to tear those down and re-install via the CLI:

```bash
# remove old command + skill symlinks pointing into this repo, prune empty dirs
find ~/.claude/commands ~/.claude/skills -type l -lname "$(pwd)/*" -delete
find ~/.claude/skills -mindepth 1 -type d -empty -delete

# re-install via the skills CLI
npx skills add sleeyax/promptfiles
```

### Claude Code extras

Recommended plugins and meta frameworks (Claude Code only):

```bash
claude plugins add rust-analyzer-lsp@claude-plugins-official
claude plugins add frontend-design@claude-plugins-official
claude plugins add context7@claude-plugins-official

npx get-shit-done-cc@latest
```

### Vscode extras

VS Code expects all prompt files in a flat structure at `~/.config/Code/User/prompts/`.

```bash
# create the prompts directory if it doesn't exist
mkdir -p ~/.config/Code/User/prompts/

# symlink prompt files via stow
stow -t ~/.config/Code/User/prompts/ prompts
stow -t ~/.config/Code/User/prompts/ agents

# symlink mcp.json
ln -s $(pwd)/mcp.json ~/.config/Code/User/mcp.json

# to uninstall:
# stow -D -t ~/.config/Code/User/prompts/ prompts agents
# rm ~/.config/Code/User/mcp.json
```

## Resources

- [Awesome copilot](https://github.com/github/awesome-copilot)
