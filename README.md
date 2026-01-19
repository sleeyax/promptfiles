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

# symlink all prompt files (flat structure)
ln -s $(pwd)/prompts/* $(pwd)/agents/* ~/.config/Code/User/prompts/

# symlink mcp.json
ln -s $(pwd)/mcp.json ~/.config/Code/User/mcp.json

# to uninstall (only removes symlinks pointing to this repo):
# find ~/.config/Code/User/prompts/ -type l -lname "$(pwd)/*" -delete
# rm ~/.config/Code/User/mcp.json
```

## Resources

- [Awesome copilot](https://github.com/github/awesome-copilot)
