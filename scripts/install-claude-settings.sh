#!/usr/bin/env bash
set -euo pipefail

# Claude Code mutates ~/.claude/settings.json at runtime (e.g. when you switch models), so it can't be symlinked like CLAUDE.md.
# This script deep-merges harnesses/claude/settings.json into the host file instead, keeping the repo as the source of truth for the keys it tracks while leaving any other host-local settings untouched.
# Rerun it after editing the tracked settings file.

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/harnesses/claude/settings.json"
dest_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dest="$dest_dir/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to merge settings but was not found on PATH" >&2
  exit 1
fi

mkdir -p "$dest_dir"

# Start from an empty object when the host file is missing or blank, so the first run still works.
existing='{}'
if [[ -s "$dest" ]]; then
  existing="$(cat "$dest")"
fi

# Recursive merge with tracked settings (src) taking precedence over host values, written atomically.
tmp="$(mktemp "$dest_dir/settings.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
jq -s '.[0] * .[1]' <(printf '%s' "$existing") "$src" >"$tmp"
mv "$tmp" "$dest"
trap - EXIT

echo "merged $src -> $dest"
