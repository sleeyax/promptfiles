# promptfiles

My collection of skills, agents, and prompts for day-to-day agentic coding.

> [!NOTE]
> Everything in this repo is designed to fit **my** personal workflow and preferences. You're welcome to use it as-is or as inspiration for your own setup, but it evolves constantly and comes with no stable versioning guarantees. Anything in here may change or disappear without notice.

## Installation

### Skills

Skills are reusable markdown instructions that agents like Claude Code load on demand to handle a specific task or workflow.

Install via the [`skills`](https://www.npmjs.com/package/skills) CLI:

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

## Harnesses

### Claude Code

#### CLAUDE.md

`harnesses/claude/CLAUDE.md` holds my global Claude Code user instructions. Symlink it so it applies across all devices:

```bash
ln -s $(pwd)/harnesses/claude/CLAUDE.md ~/.claude/CLAUDE.md

# to uninstall:
# rm ~/.claude/CLAUDE.md
```

#### Extras

Recommended plugins:

```bash
claude plugins add frontend-design@claude-plugins-official
claude plugins add context7@claude-plugins-official
```
