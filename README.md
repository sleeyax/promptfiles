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

## Resources

- [Awesome copilot](https://github.com/github/awesome-copilot)
