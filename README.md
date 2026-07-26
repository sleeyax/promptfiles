# skills

My collection of skills for day-to-day agentic coding.

> [!NOTE]
> Everything in this repo is designed to fit **my** personal workflow and preferences. You're welcome to use it as-is or as inspiration for your own setup, but it evolves constantly and comes with no stable versioning guarantees. Anything in here may change or disappear without notice.

## Installation

### Skills

Skills are reusable markdown instructions that agents like Claude Code load on demand to handle a specific task or workflow.

Install via the [`skills`](https://www.npmjs.com/package/skills) CLI:

```bash
# install
npx skills add sleeyax/skills

# update
npx skills update

# uninstall
npx skills remove sleeyax/skills
```

#### Local development

Install skills from your local clone so edits to `./skills/<category>/<name>/SKILL.md` are live in your agent:

```bash
# from the root of this repo (-s '*' = all skills, -y = skip prompts)
npx skills add . -s '*'
```

Verify with `npx skills list -g`.

### Agents

Agents are custom subagents that the main agent can delegate specialized tasks to. The markdown files in `agents/` are the single source of truth, written in Claude Code's agent format.

#### Claude Code

Claude Code discovers agents in `~/.claude/agents/`:

```bash
# create the agents directory if it doesn't exist
mkdir -p ~/.claude/agents/

# symlink agent files via stow
stow -t ~/.claude/agents/ agents

# to uninstall:
# stow -D -t ~/.claude/agents/ agents
```

#### Codex

Codex expects agents as TOML files in `~/.codex/agents/`, so they can't be symlinked directly. Generate them from the markdown sources instead:

```bash
./scripts/install-codex-agents.sh
```

Rerun the script after editing an agent file.

## Harnesses

### Claude Code

#### CLAUDE.md

`harnesses/claude/CLAUDE.md` holds my global Claude Code user instructions. Symlink it so it applies across all devices:

```bash
ln -s $(pwd)/harnesses/claude/CLAUDE.md ~/.claude/CLAUDE.md

# to uninstall:
# rm ~/.claude/CLAUDE.md
```

#### settings.json

`harnesses/claude/settings.json` holds the global Claude Code settings I want on every host. Claude Code rewrites this file at runtime (e.g. when switching models), so instead of symlinking it, the script deep-merges the tracked keys into the host's existing `~/.claude/settings.json`. Tracked keys win; any other host-local settings are left untouched. Requires [`jq`](https://jqlang.github.io/jq/).

```bash
./scripts/install-claude-settings.sh
```

Rerun the script after editing the tracked settings file.

#### Extras

Recommended plugins:

```bash
claude plugins add frontend-design@claude-plugins-official
claude plugins add context7@claude-plugins-official
```
