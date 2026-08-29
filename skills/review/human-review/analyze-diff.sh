#!/usr/bin/env bash
# Emit compact per-file signals for an MR diff, for the agent to group and order.
#
# Usage:
#   analyze-diff.sh --base <sha> --head <sha> [--max-contexts N]
#
# Prints a JSON array, one object per changed file:
#   {
#     "path": "…", "oldPath": "…", "status": "M",
#     "added": 42, "deleted": 7, "binary": false,
#     "commits": ["feat(remi): …", …],   // subjects of commits touching this file
#     "contexts": ["class FooService", "async save(", …]  // hunk header context
#   }
#
# Grouping 70+ files needs more than paths, but reading every diff would blow
# the context budget and break the skill's "never dump the diff" rule. Hunk-header
# context lines plus the commit subjects that touched each file give most of the
# signal at a fraction of the size.
#
# Contexts are capped per file (default 6) and de-duplicated; a file with 40
# hunks contributes at most 6 short strings.

set -euo pipefail

die() { echo "analyze-diff.sh: $*" >&2; exit 1; }

base=""; head=""; max_contexts=6
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)          base="$2"; shift 2 ;;
    --head)          head="$2"; shift 2 ;;
    --max-contexts)  max_contexts="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$base" ]] || die "--base required"
[[ -n "$head" ]] || die "--head required"
command -v jq >/dev/null 2>&1 || die "jq not found on PATH"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"

# numstat gives added/deleted (and "-" for binary); name-status gives A/M/D/R.
# Build both into lookup tables keyed by path, then join.
stat_tmp=$(mktemp); name_tmp=$(mktemp)
trap 'rm -f "$stat_tmp" "$name_tmp"' EXIT

# Relaxed rename/copy detection for name-status only. git's default -M misses
# a file that was moved AND substantially edited in the same MR, which then
# reads as an unrelated delete plus an unrelated add — a wall of red and a wall
# of green the reviewer has to mentally pair up. `numstat` deliberately stays on
# plain -M: its output keys the added/deleted lookup below, and -C changes the
# path column format.
git diff --numstat -M "$base...$head" > "$stat_tmp"
git diff --name-status -M30% -C30% --find-copies-harder "$base...$head" > "$name_tmp"

emit_file() {
  local path="$1" old_path="$2" status="$3" added="$4" deleted="$5"
  local binary=false
  [[ "$added" == "-" ]] && { binary=true; added=0; deleted=0; }

  local commits contexts
  commits=$(git log --format=%s "$base..$head" -- "$path" 2>/dev/null \
    | awk '!seen[$0]++' | head -5 | jq -Rn '[inputs]')

  # Hunk header context: the text trailing the second `@@`. Empty for files
  # whose hunks sit at top level (git finds no enclosing declaration).
  #
  # Filter blanks with awk, not `grep -v '^$'` — grep exits 1 on no match, and
  # under `set -e` + `pipefail` a context-less file (package.json, JSON fixtures)
  # would abort the whole run.
  contexts=$(git diff --unified=0 -M "$base...$head" -- "$path" 2>/dev/null \
    | sed -n 's/^@@[^@]*@@[[:space:]]*\(.*\)$/\1/p' \
    | sed 's/[[:space:]]*$//' \
    | awk 'NF && !seen[$0]++' \
    | head -"$max_contexts" \
    | cut -c1-80 \
    | jq -Rn '[inputs]') || contexts='[]'
  [[ -n "$contexts" ]] || contexts='[]'

  jq -nc \
    --arg path "$path" --arg old_path "$old_path" --arg status "$status" \
    --argjson added "${added:-0}" --argjson deleted "${deleted:-0}" \
    --argjson binary "$binary" \
    --argjson commits "$commits" --argjson contexts "$contexts" \
    '{path:$path, oldPath:$old_path, status:$status,
      added:$added, deleted:$deleted, binary:$binary,
      commits:$commits, contexts:$contexts}'
}

{
  while IFS=$'\t' read -r status f1 f2; do
    [[ -z "$status" ]] && continue
    local_status="${status:0:1}"
    if [[ "$local_status" == "R" || "$local_status" == "C" ]]; then
      old_path="$f1"; path="$f2"
    else
      old_path="$f1"; path="$f1"
    fi
    # Look up counts for this path from numstat.
    counts=$(awk -F'\t' -v p="$path" -v q="$old_path" \
      '($3==p)||($3==q)||($NF==p){print $1"\t"$2; exit}' "$stat_tmp")
    added=$(cut -f1 <<<"$counts"); deleted=$(cut -f2 <<<"$counts")
    emit_file "$path" "$old_path" "$local_status" "${added:-0}" "${deleted:-0}"
  done < "$name_tmp"
} | jq -s 'sort_by(-(.added + .deleted))'
