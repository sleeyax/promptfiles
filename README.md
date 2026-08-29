# promptfiles

My collection of skills, agents, output styles, and harness config for day-to-day agentic coding.

> [!NOTE]
> Everything in this repo is designed to fit **my** personal workflow and preferences. You're welcome to use it as-is or as inspiration for your own setup, but it evolves constantly and comes with no stable versioning guarantees. Anything in here may change or disappear without notice.

## Installation

Pick one of two routes: the Claude Code plugin or the `skills` CLI (plus optional agent symlinks). 

### Claude Code plugin

This repo doubles as a Claude Code marketplace containing a single plugin, `sleeyax-skills`, that bundles every skill and both agents:

```bash
claude plugin marketplace add sleeyax/promptfiles
claude plugin install sleeyax-skills@sleeyax

# update (no version is pinned, so every new commit counts as a new version)
claude plugin marketplace update sleeyax
claude plugin update sleeyax-skills@sleeyax

# uninstall
claude plugin uninstall sleeyax-skills@sleeyax
claude plugin marketplace remove sleeyax
```

The same thing works in-session via `/plugin marketplace add sleeyax/promptfiles` and `/plugin install sleeyax-skills@sleeyax`.

To inspect what you got (component inventory and token cost): `claude plugin details sleeyax-skills`.

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

Install skills from your local clone so edits to `./skills/<category>/<name>/SKILL.md` are live in your agent:

```bash
# from the root of this repo (-s '*' = all skills, -y = skip prompts)
npx skills add . -s '*'
```

Verify with `npx skills list -g`.

### Agents

Agents are custom subagents that the main agent can delegate specialized tasks to. The markdown files in `agents/` are the single source of truth, written in Claude Code's agent format.

#### Claude Code

The plugin already ships both agents, so this step is only for a non-plugin install. Claude Code discovers agents in `~/.claude/agents/`:

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

### Output styles

Output styles are appended to Claude Code's system prompt and shape how it writes for the whole session.

- `eli5.md` — small words, short paragraphs, and at most two options when something has to be decided.
- `ste100.md` — answers in ASD-STE100 Simplified Technical English.
- `unslop.md` — cuts AI tells from any writing. Vendored from the `pstack` plugin in [cursor/plugins](https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md), where it ships as an always-on skill; only the frontmatter differs, so it can be re-synced from upstream.

The plugin ships them via the default `output-styles/` scan. For a non-plugin install, symlink into `~/.claude/output-styles/`:

```bash
mkdir -p ~/.claude/output-styles/
stow -t ~/.claude/output-styles/ output-styles

# to uninstall:
# stow -D -t ~/.claude/output-styles/ output-styles
```

Selecting one is a separate step from installing it: run `/config` and pick it under **Output style**, or set `outputStyle` in your settings. It takes effect on the next session.

## Harnesses

`harnesses/AGENTS.md` holds my global instructions, shared by every harness. Each harness picks it up its own way, so install both the shared file and the harness-specific glue below.

### Claude Code

#### CLAUDE.md

`harnesses/claude/CLAUDE.md` is a one-line `@../AGENTS.md` import, so the shared instructions come along with it. Symlink it so it applies across all devices:

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

#### statusline.sh

`harnesses/claude/statusline.sh` draws the status line: model, git branch, and context usage, the last coloured by how close it is to full. The tracked `settings.json` points `statusLine` at `~/.claude/statusline.sh`, so symlink it there before running the settings script. Requires [`jq`](https://jqlang.github.io/jq/).

```bash
ln -s $(pwd)/harnesses/claude/statusline.sh ~/.claude/statusline.sh

# to uninstall:
# rm ~/.claude/statusline.sh
```

#### Extras

Recommended plugins:

```bash
claude plugin install frontend-design@claude-plugins-official
claude plugin install context7@claude-plugins-official
```

### Codex

#### AGENTS.md

Codex reads global instructions from `~/.codex/AGENTS.md`, so the shared file needs no conversion — the script symlinks it straight in. It refuses to overwrite a real file there, and honours `CODEX_HOME`.

```bash
./scripts/install-codex-settings.sh

# to uninstall:
# rm ~/.codex/AGENTS.md
```
