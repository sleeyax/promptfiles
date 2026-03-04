# promptfiles

My collection of prompt files for various AI models and applications.

## Installation

### Vscode

VS Code expects all prompt files in a flat structure at `~/.config/Code/User/prompts/`.

```bash
# get your copy of the prompt files
git clone https://github.com/sleeyax/promptfiles.git
cd promptfiles

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

### Claude Code

```bash
# install custom skills from this repo
mkdir -p ~/.claude/skills/phase
ln -s $(pwd)/skills/phase.md ~/.claude/skills/phase/SKILL.md
# to uninstall skills:
# rm -r ~/.claude/skills/phase

# install plugins
claude plugins add rust-analyzer-lsp@claude-plugins-official
claude plugins add frontend-design@claude-plugins-official
claude plugins add context7@claude-plugins-official

# install GSD (meta framework)
npx get-shit-done-cc@latest
```

### Migrating from manual symlinks

If you previously installed with `ln -s`, remove the old symlinks first and then use stow to manage them:

```bash
find ~/.config/Code/User/prompts/ -type l -lname "$(pwd)/*" -delete
stow -t ~/.config/Code/User/prompts/ prompts agents
```

## Resources

- [Awesome copilot](https://github.com/github/awesome-copilot)
