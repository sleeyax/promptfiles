#!/usr/bin/env bash
# Post a batch of GitLab MR draft notes from a findings.json file.
#
# Usage:
#   post-draft-note.sh --project <numeric-id> --mr <iid> --findings <path>
#
# Reads the JSON, validates it against findings.schema.json (using
# `check-jsonschema` if present, else jq-based structural checks), then posts
# each finding as a positional draft note plus an optional non-positional
# summary draft note. Tracks created IDs internally and rolls back via DELETE
# on any HTTP failure mid-batch.
#
# On success: prints `{"posted":N,"skipped":M,"ids":[...]}` to stdout, exit 0.
# On failure: forwards stderr from glab/jq, attempts rollback, exits non-zero.
#
# IMPORTANT — do not switch to form fields. `glab api` does NOT flatten
# bracketed keys (`-f "position[new_line]=42"`) into nested form params; the
# GitLab draft-notes endpoint then silently stores the note as non-positional.
# Always send a JSON body via `--input -` with Content-Type: application/json
# (the header is required — omitting it returns HTTP 415).
#
# Each inline POST is verified against its own response: if `position.new_line`
# is missing/null, the batch is rolled back rather than left as unanchored
# drafts.

set -euo pipefail

die() { echo "post-draft-note.sh: $*" >&2; exit 1; }

project=""; mr=""; findings_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  project="$2"; shift 2 ;;
    --mr)       mr="$2"; shift 2 ;;
    --findings) findings_file="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$project" ]]       || die "--project required"
[[ -n "$mr" ]]            || die "--mr required"
[[ -n "$findings_file" ]] || die "--findings required"
[[ -r "$findings_file" ]] || die "findings file not readable: $findings_file"

command -v glab >/dev/null 2>&1 || die "glab not found on PATH"
command -v jq   >/dev/null 2>&1 || die "jq not found on PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema="$script_dir/findings.schema.json"
[[ -r "$schema" ]] || die "schema not found: $schema"

# 1. Schema validation.
if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$findings_file" >&2 \
    || die "findings.json failed schema validation"
else
  jq -e '
    (.diffRefs.baseSha  | type=="string" and length>=7) and
    (.diffRefs.startSha | type=="string" and length>=7) and
    (.diffRefs.headSha  | type=="string" and length>=7) and
    (.findings | type=="array") and
    (.findings | all(
      (.severity as $s | ["blocker","concern","suggestion","nit"] | index($s) != null) and
      (.path    | type=="string" and length>0) and
      (.oldPath | type=="string" and length>0) and
      (.line    | type=="number" and . >= 1 and (.|floor)==.) and
      (.body    | type=="string" and length>0)
    )) and
    ((.summary // null) == null or (.summary.body | type=="string" and length>0))
  ' "$findings_file" >/dev/null \
    || die "findings.json failed structural checks (install check-jsonschema for detailed errors)"
fi

endpoint="projects/$project/merge_requests/$mr/draft_notes"

# 2. Idempotency — list existing drafts and build fingerprints.
existing_raw=$(glab api --paginate "$endpoint" 2>/dev/null || echo '[]')
existing_json=$(jq 'if type=="array" then . else [] end' <<<"$existing_raw" 2>/dev/null || echo '[]')
mk_fingerprint() {
  local path="$1" line="$2" body="$3"
  printf '%s|%s|%s' "$path" "$line" "${body:0:80}"
}
declare -A existing_fps
while IFS=$'\t' read -r ex_path ex_line ex_body; do
  [[ -z "$ex_path" ]] && continue
  fp=$(mk_fingerprint "$ex_path" "$ex_line" "$ex_body")
  existing_fps["$fp"]=1
done < <(jq -r '.[] | select(.position.new_path != null) |
  [.position.new_path, (.position.new_line // 0), (.note // "")] | @tsv' \
  <<<"$existing_json")

# 3. Post each finding, tracking IDs for rollback.
posted_ids=()
posted=0
skipped=0
fail_msg=""

post_one() {
  # Build a JSON payload and POST it via stdin. Form-field syntax with
  # nested `position[...]` keys is not reliably parsed by the GitLab draft-notes
  # endpoint, so we send `application/json` instead.
  # $1 = payload JSON (string)
  # $2 = expected new_line (integer) for anchor verification, or "" for non-positional
  local payload="$1"
  local expected_line="${2:-}"
  local response
  if ! response=$(printf '%s' "$payload" \
    | glab api -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        --input - 2>&1); then
    fail_msg="$response"
    return 1
  fi
  local id
  id=$(printf '%s' "$response" | jq -r '.id // empty' 2>/dev/null || true)
  if [[ -z "$id" ]]; then
    fail_msg="missing id in response: $response"
    return 1
  fi
  posted_ids+=("$id")
  posted=$((posted+1))

  # Anchor verification — guards against silent regressions where the API
  # accepts the request but stores the note as non-positional.
  if [[ -n "$expected_line" ]]; then
    local got_line
    got_line=$(printf '%s' "$response" | jq -r '.position.new_line // empty' 2>/dev/null || true)
    if [[ -z "$got_line" || "$got_line" != "$expected_line" ]]; then
      fail_msg="draft $id posted but anchor missing/wrong (expected new_line=$expected_line, got '${got_line:-null}'). Aborting batch."
      return 1
    fi
  fi
}

rollback() {
  if [[ ${#posted_ids[@]} -gt 0 ]]; then
    echo "post-draft-note.sh: rolling back ${#posted_ids[@]} draft(s)…" >&2
    for id in "${posted_ids[@]}"; do
      glab api -X DELETE "$endpoint/$id" >/dev/null 2>&1 \
        || echo "post-draft-note.sh: failed to delete draft $id" >&2
    done
  fi
}

n_findings=$(jq '.findings | length' "$findings_file")
base_sha=$(jq -r  '.diffRefs.baseSha'  "$findings_file")
start_sha=$(jq -r '.diffRefs.startSha' "$findings_file")
head_sha=$(jq -r  '.diffRefs.headSha'  "$findings_file")

for ((i=0; i<n_findings; i++)); do
  path=$(jq -r    ".findings[$i].path"    "$findings_file")
  oldpath=$(jq -r ".findings[$i].oldPath" "$findings_file")
  line=$(jq -r    ".findings[$i].line"    "$findings_file")
  body=$(jq -r    ".findings[$i].body"    "$findings_file")

  fp=$(mk_fingerprint "$path" "$line" "$body")
  if [[ -n "${existing_fps[$fp]:-}" ]]; then
    skipped=$((skipped+1))
    continue
  fi

  payload=$(jq -nc \
    --arg note "$body" \
    --arg base "$base_sha" --arg start "$start_sha" --arg head "$head_sha" \
    --arg new_path "$path" --arg old_path "$oldpath" \
    --argjson new_line "$line" \
    '{
      note: $note,
      position: {
        position_type: "text",
        base_sha: $base,
        start_sha: $start,
        head_sha: $head,
        new_path: $new_path,
        old_path: $old_path,
        new_line: $new_line
      }
    }')

  if ! post_one "$payload" "$line"; then
    rollback
    echo "post-draft-note.sh: $fail_msg" >&2
    exit 1
  fi
done

# 4. Summary (optional, non-positional).
has_summary=$(jq 'has("summary")' "$findings_file")
if [[ "$has_summary" == "true" ]]; then
  summary_body=$(jq -r '.summary.body' "$findings_file")
  payload=$(jq -nc --arg note "$summary_body" '{note: $note}')
  if ! post_one "$payload" ""; then
    rollback
    echo "post-draft-note.sh: $fail_msg" >&2
    exit 1
  fi
fi

# 5. Success output.
if [[ ${#posted_ids[@]} -eq 0 ]]; then
  ids_json='[]'
else
  ids_json=$(printf '%s\n' "${posted_ids[@]}" | jq -R 'tonumber' | jq -s .)
fi
jq -nc \
  --argjson posted "$posted" \
  --argjson skipped "$skipped" \
  --argjson ids "$ids_json" \
  '{posted:$posted, skipped:$skipped, ids:$ids}'
