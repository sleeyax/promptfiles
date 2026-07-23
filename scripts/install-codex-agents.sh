#!/usr/bin/env bash
set -euo pipefail

# Codex custom agents are TOML files, so the markdown agent files can't be symlinked like they are for Claude Code.
# This script generates ~/.codex/agents/<name>.toml from each agents/*.md instead.
# Rerun it after editing an agent file.

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="${CODEX_HOME:-$HOME/.codex}/agents"
mkdir -p "$out_dir"

for file in "$repo_root"/agents/*.md; do
  name="$(awk -F': ' '/^name:/ { print $2; exit }' "$file")"
  description="$(awk -F': ' '/^description:/ { print $2; exit }' "$file")"
  body="$(awk 'in_body { print } /^---$/ { if (++fences == 2) in_body = 1 }' "$file")"

  {
    echo "name = \"$name\""
    echo "description = \"$description\""
    echo "developer_instructions = '''"
    echo "$body"
    echo "'''"
  } >"$out_dir/$name.toml"

  echo "wrote $out_dir/$name.toml"
done
