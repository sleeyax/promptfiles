#!/usr/bin/env bash
# Post or delete GitLab MR draft notes via `glab api`.
#
# Inline note:
#   post-draft-note.sh --project ID --mr IID --body-file PATH \
#     --path NEW_PATH --old-path OLD_PATH --line NEW_LINE \
#     --base-sha SHA --start-sha SHA --head-sha SHA
#
# Plain (non-inline) note:
#   post-draft-note.sh --project ID --mr IID --body-file PATH
#
# Discard (delete listed draft IDs):
#   post-draft-note.sh --discard-mine --project ID --mr IID --ids id1,id2,...
#
# On create: prints the new draft note's numeric `id` to stdout.
# On HTTP error: forwards glab stderr, exits non-zero.

set -euo pipefail

die() { echo "post-draft-note.sh: $*" >&2; exit 1; }

mode="create"
project=""; mr=""; body_file=""
new_path=""; old_path=""; new_line=""
base_sha=""; start_sha=""; head_sha=""
ids=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --discard-mine) mode="discard"; shift ;;
    --project)   project="$2"; shift 2 ;;
    --mr)        mr="$2"; shift 2 ;;
    --body-file) body_file="$2"; shift 2 ;;
    --path)      new_path="$2"; shift 2 ;;
    --old-path)  old_path="$2"; shift 2 ;;
    --line)      new_line="$2"; shift 2 ;;
    --base-sha)  base_sha="$2"; shift 2 ;;
    --start-sha) start_sha="$2"; shift 2 ;;
    --head-sha)  head_sha="$2"; shift 2 ;;
    --ids)       ids="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

command -v glab >/dev/null 2>&1 || die "glab not found on PATH"
[[ -n "$project" ]] || die "--project required"
[[ -n "$mr" ]]      || die "--mr required"

endpoint="projects/$project/merge_requests/$mr/draft_notes"

if [[ "$mode" == "discard" ]]; then
  [[ -n "$ids" ]] || die "--ids required for --discard-mine"
  IFS=',' read -ra arr <<< "$ids"
  for id in "${arr[@]}"; do
    [[ -n "$id" ]] || continue
    glab api -X DELETE "$endpoint/$id" >/dev/null
  done
  exit 0
fi

[[ -n "$body_file" ]] || die "--body-file required"
[[ -r "$body_file" ]] || die "body file not readable: $body_file"

inline=0
if [[ -n "$new_path$old_path$new_line$base_sha$start_sha$head_sha" ]]; then
  inline=1
  for var in new_path old_path new_line base_sha start_sha head_sha; do
    [[ -n "${!var}" ]] || die "inline mode requires --${var//_/-}"
  done
fi

args=(api -X POST "$endpoint" -F "note=@$body_file")
if [[ $inline -eq 1 ]]; then
  args+=(
    -f "position[position_type]=text"
    -f "position[base_sha]=$base_sha"
    -f "position[start_sha]=$start_sha"
    -f "position[head_sha]=$head_sha"
    -f "position[new_path]=$new_path"
    -f "position[old_path]=$old_path"
    -f "position[new_line]=$new_line"
  )
fi

response=$(glab "${args[@]}")
# Extract numeric id from JSON response without jq dep.
id=$(printf '%s' "$response" | grep -oE '"id"[[:space:]]*:[[:space:]]*[0-9]+' | head -n1 | grep -oE '[0-9]+$')
[[ -n "$id" ]] || die "could not parse id from response: $response"
printf '%s\n' "$id"
