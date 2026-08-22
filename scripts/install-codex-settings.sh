#!/usr/bin/env bash
set -euo pipefail

# Codex reads global instructions from ~/.codex/AGENTS.md and needs no conversion, so the shared file is symlinked in as-is rather than generated like the agent TOMLs are.
# Rerun it on a new host, or after moving this repo.

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/harnesses/AGENTS.md"
dest_dir="${CODEX_HOME:-$HOME/.codex}"
dest="$dest_dir/AGENTS.md"

mkdir -p "$dest_dir"

# Never clobber a real file: it would be host-local instructions this repo doesn't track.
if [[ -e "$dest" && ! -L "$dest" ]]; then
  echo "error: $dest already exists and is not a symlink; move it aside first" >&2
  exit 1
fi

ln -sfn "$src" "$dest"

echo "linked $dest -> $src"
