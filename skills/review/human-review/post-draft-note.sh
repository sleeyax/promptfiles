#!/usr/bin/env bash
# Post a batch of GitLab MR draft notes from a findings.json file.
#
# Usage:
#   post-draft-note.sh --project <numeric-id> --mr <iid> --findings <path>
#                      [--marker <text>] [--dry-run]
#
# Shared verbatim by the `review-mr` and `human-review` skills. A skill
# directory installs on its own, so the file is duplicated between them rather
# than referenced across them — keep the two copies identical.
#
# Reads the JSON, validates it against findings.schema.json (using
# `check-jsonschema` if present, else jq-based structural checks), then posts
# each finding as a positional draft note plus an optional non-positional
# summary draft note. Tracks created IDs internally and rolls back via DELETE
# on any HTTP failure mid-batch.
#
# --dry-run prints the exact payloads that would be POSTed and exits 0 without
# touching the API. Use it to verify anchors before committing to a batch.
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
# is missing/null — or, for a ranged note, if `position.line_range.end.new_line`
# does not match — the batch is rolled back rather than left misanchored.
#
# --marker appends the given text to every body, separated by a blank line. Pass
# an HTML comment and GitLab strips it when rendering markdown while returning it
# verbatim from the API, in drafts and — once the user publishes — in discussions
# too. `human-review` uses that to recognise its own notes on a later run;
# author identity cannot, since both skills post under the same account.
# Fingerprints for the idempotency check are taken from the unmarked body, so a
# note posted before the marker was introduced still matches.
#
# MULTI-LINE RANGES. A finding may carry an optional `lineRange` of
# `{start,end}` points, each `{newLine, oldLine}`. GitLab identifies a line by
# `line_code = sha1(<new_path>)_<old_line>_<new_line>`, using 0 for a null side.
# The point's `type` is derived: added line (oldLine null) => "new", removed
# line (newLine null) => "old", context line (both set) => null. The top-level
# `line` stays the anchor and must equal the range's end newLine.

set -euo pipefail

die() { echo "post-draft-note.sh: $*" >&2; exit 1; }

project=""; mr=""; findings_file=""; marker=""; dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  project="$2"; shift 2 ;;
    --mr)       mr="$2"; shift 2 ;;
    --findings) findings_file="$2"; shift 2 ;;
    --marker)   marker="$2"; shift 2 ;;
    --dry-run)  dry_run=1; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

# The body as posted. The reader side lives in the calling skill.
mark() { if [[ -z "$marker" ]]; then printf '%s' "$1"; else printf '%s\n\n%s' "$1" "$marker"; fi; }

[[ -n "$findings_file" ]] || die "--findings required"
[[ -r "$findings_file" ]] || die "findings file not readable: $findings_file"
if [[ $dry_run -eq 0 ]]; then
  [[ -n "$project" ]] || die "--project required"
  [[ -n "$mr" ]]      || die "--mr required"
  command -v glab >/dev/null 2>&1 || die "glab not found on PATH"
fi
command -v jq >/dev/null 2>&1 || die "jq not found on PATH"

# sha1 backend for line_code. Prefer coreutils, fall back to openssl.
if command -v sha1sum >/dev/null 2>&1; then
  sha1() { printf '%s' "$1" | sha1sum | cut -d' ' -f1; }
elif command -v openssl >/dev/null 2>&1; then
  sha1() { printf '%s' "$1" | openssl dgst -sha1 -r | cut -d' ' -f1; }
else
  die "neither sha1sum nor openssl found on PATH (needed for line_code)"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema="$script_dir/findings.schema.json"
[[ -r "$schema" ]] || die "schema not found: $schema"

# 1. Schema validation.
if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$findings_file" >&2 \
    || die "findings.json failed schema validation"
else
  # The jq fallback must also enforce the schema's `additionalProperties:false`.
  # Without it a misspelled key (`linerange`) is silently ignored and the note
  # posts unranged — the exact failure this validation exists to catch.
  jq -e '
    def only(allowed): (keys_unsorted - allowed) | length == 0;
    def point_ok: type=="object"
      and only(["newLine","oldLine"])
      and ((.newLine // null) != null or (.oldLine // null) != null)
      and ((.newLine // null) == null or (.newLine | type=="number" and . >= 1 and (.|floor)==.))
      and ((.oldLine // null) == null or (.oldLine | type=="number" and . >= 1 and (.|floor)==.));
    only(["diffRefs","summary","findings"]) and
    (.diffRefs | only(["baseSha","startSha","headSha"])) and
    ((.summary // null) == null or (.summary | only(["body"]))) and
    (.diffRefs.baseSha  | type=="string" and length>=7) and
    (.diffRefs.startSha | type=="string" and length>=7) and
    (.diffRefs.headSha  | type=="string" and length>=7) and
    (.findings | type=="array") and
    (.findings | all(
      only(["severity","path","oldPath","line","title","body","lineRange"]) and
      (.severity as $s | ["blocker","concern","suggestion","nit"] | index($s) != null) and
      (.path    | type=="string" and length>0) and
      (.oldPath | type=="string" and length>0) and
      (.line    | type=="number" and . >= 1 and (.|floor)==.) and
      (.body    | type=="string" and length>0) and
      ((.lineRange // null) == null or (
        (.lineRange | only(["start","end"])) and
        (.lineRange.start | point_ok) and
        (.lineRange.end   | point_ok) and
        ((.lineRange.end.newLine // null) == null or .lineRange.end.newLine == .line) and
        ((.lineRange.start.newLine // null) == null or (.lineRange.end.newLine // null) == null
          or .lineRange.start.newLine <= .lineRange.end.newLine)
      ))
    )) and
    ((.summary // null) == null or (.summary.body | type=="string" and length>0))
  ' "$findings_file" >/dev/null \
    || die "findings.json failed structural checks (install check-jsonschema for detailed errors)"
fi

# 1b. Pre-flight: validate GitLab suggestion fences against their anchor spans.
#
# A ```suggestion:-N+M fence tells GitLab to replace lines [anchor-N, anchor+M]
# when the author clicks Apply. GitLab does not check that span against anything
# — a fence that disagrees with the range the comment was written against
# silently rewrites the wrong lines, and the mistake only surfaces in the
# author's branch. The anchor is the LAST line of a captured range, so the only
# correct span for one is -(end-start)+0.
#
# Only findings that carry a `lineRange` are checked: without one there is no
# recorded span to contradict, and a caller that writes the fence by hand is
# free to reach above and below the anchor.
#
# This runs before the first POST: a span error must abort the batch, not leave
# half of it posted and rolled back.
n_pre=$(jq '.findings | length' "$findings_file")
for ((i=0; i<n_pre; i++)); do
  range_pre=$(jq -c ".findings[$i].lineRange // null" "$findings_file")
  [[ "$range_pre" == "null" ]] && continue
  body_pre=$(jq -r ".findings[$i].body" "$findings_file")
  line_pre=$(jq -r ".findings[$i].line" "$findings_file")
  path_pre=$(jq -r ".findings[$i].path" "$findings_file")

  fences=$(grep -oE '```suggestion:-[0-9]+\+[0-9]+' <<<"$body_pre" || true)
  [[ -z "$fences" ]] && continue

  expected_n=0
  s_new_pre=$(jq -r '.start.newLine // empty' <<<"$range_pre")
  [[ -n "$s_new_pre" ]] && expected_n=$(( line_pre - s_new_pre ))

  while read -r fence; do
    [[ -z "$fence" ]] && continue
    fn=$(sed -E 's/.*:-([0-9]+)\+([0-9]+)$/\1/' <<<"$fence")
    fm=$(sed -E 's/.*:-([0-9]+)\+([0-9]+)$/\2/' <<<"$fence")
    [[ "$fn" == "$expected_n" ]] \
      || die "$path_pre:$line_pre — suggestion span -$fn does not match the comment's range (expected -$expected_n)"
    [[ "$fm" == "0" ]] \
      || die "$path_pre:$line_pre — suggestion span +$fm must be +0; the anchor is the last line of the selection"
    (( line_pre - fn >= 1 )) \
      || die "$path_pre:$line_pre — suggestion span reaches above line 1"
  done <<<"$fences"
done

endpoint="projects/$project/merge_requests/$mr/draft_notes"

# 2. Idempotency — list existing drafts and build fingerprints.
declare -A existing_fps
if [[ $dry_run -eq 0 ]]; then
  existing_raw=$(glab api --paginate "$endpoint" 2>/dev/null || echo '[]')
  existing_json=$(jq 'if type=="array" then . else [] end' <<<"$existing_raw" 2>/dev/null || echo '[]')
  # The body side of the fingerprint is JSON-encoded on both sides. Raw bodies
  # would not compare: a remote one arrives with its newlines escaped by jq's
  # output encoding while the local one keeps them literal, so no multi-line
  # comment could ever match itself. Encoding also keeps each key on one line,
  # which @tsv would not — it re-escapes the backslashes jq just wrote.
  while IFS= read -r fp; do
    [[ -z "$fp" ]] && continue
    existing_fps["$fp"]=1
  done < <(jq -r --arg marker "$marker" '.[]
    | select(.position.new_path != null)
    | (.note // "") as $n
    | (if $marker == "" then $n else ($n | sub("\n\n" + $marker + "$"; "")) end | tojson) as $b
    | "\(.position.new_path)|\(.position.new_line // 0)|\($b[0:80])"' \
    <<<"$existing_json")
fi

# 3. Post each finding, tracking IDs for rollback.
posted_ids=()
posted=0
skipped=0
fail_msg=""

# Build one line_range endpoint object. $1 path, $2 oldLine (may be empty),
# $3 newLine (may be empty). Empty means "this side does not exist".
mk_point() {
  local path="$1" old="$2" new="$3" type
  if   [[ -z "$old" && -n "$new" ]]; then type="new"
  elif [[ -n "$old" && -z "$new" ]]; then type="old"
  else type=""; fi
  jq -nc \
    --arg lc "$(sha1 "$path")_${old:-0}_${new:-0}" \
    --arg type "$type" \
    --argjson old "${old:-null}" \
    --argjson new "${new:-null}" \
    '{line_code:$lc, type:(if $type=="" then null else $type end), old_line:$old, new_line:$new}'
}

post_one() {
  # $1 = payload JSON, $2 = expected new_line ("" for non-positional),
  # $3 = expected line_range end new_line ("" when unranged)
  local payload="$1" expected_line="${2:-}" expected_end="${3:-}" response id
  if [[ $dry_run -eq 1 ]]; then
    jq . <<<"$payload"
    posted=$((posted+1))
    return 0
  fi
  if ! response=$(printf '%s' "$payload" \
    | glab api -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        --input - 2>&1); then
    fail_msg="$response"
    return 1
  fi
  id=$(printf '%s' "$response" | jq -r '.id // empty' 2>/dev/null || true)
  if [[ -z "$id" ]]; then
    fail_msg="missing id in response: $response"
    return 1
  fi
  posted_ids+=("$id")
  posted=$((posted+1))

  # Anchor verification — guards against silent regressions where the API
  # accepts the request but stores the note as non-positional or unranged.
  if [[ -n "$expected_line" ]]; then
    local got_line
    got_line=$(printf '%s' "$response" | jq -r '.position.new_line // empty' 2>/dev/null || true)
    if [[ -z "$got_line" || "$got_line" != "$expected_line" ]]; then
      fail_msg="draft $id posted but anchor missing/wrong (expected new_line=$expected_line, got '${got_line:-null}'). Aborting batch."
      return 1
    fi
  fi
  if [[ -n "$expected_end" ]]; then
    local got_end
    got_end=$(printf '%s' "$response" | jq -r '.position.line_range.end.new_line // empty' 2>/dev/null || true)
    if [[ -z "$got_end" || "$got_end" != "$expected_end" ]]; then
      fail_msg="draft $id posted but line_range missing/wrong (expected end new_line=$expected_end, got '${got_end:-null}'). Aborting batch."
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
  range=$(jq -c   ".findings[$i].lineRange // null" "$findings_file")

  body_fp=$(printf '%s' "$body" | jq -Rs .)
  if [[ -n "${existing_fps["$path|$line|${body_fp:0:80}"]:-}" ]]; then
    skipped=$((skipped+1))
    continue
  fi

  payload=$(jq -nc \
    --arg note "$(mark "$body")" \
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

  expected_end=""
  if [[ "$range" != "null" ]]; then
    s_old=$(jq -r '.start.oldLine // empty' <<<"$range")
    s_new=$(jq -r '.start.newLine // empty' <<<"$range")
    e_old=$(jq -r '.end.oldLine   // empty' <<<"$range")
    e_new=$(jq -r '.end.newLine   // empty' <<<"$range")
    lr=$(jq -nc \
      --argjson s "$(mk_point "$path" "$s_old" "$s_new")" \
      --argjson e "$(mk_point "$path" "$e_old" "$e_new")" \
      '{start:$s, end:$e}')
    payload=$(jq -c --argjson lr "$lr" '.position.line_range = $lr' <<<"$payload")
    expected_end="$e_new"
  fi

  if ! post_one "$payload" "$line" "$expected_end"; then
    rollback
    echo "post-draft-note.sh: $fail_msg" >&2
    exit 1
  fi
done

# 4. Summary (optional, non-positional).
has_summary=$(jq 'has("summary")' "$findings_file")
if [[ "$has_summary" == "true" ]]; then
  summary_body=$(jq -r '.summary.body' "$findings_file")
  payload=$(jq -nc --arg note "$(mark "$summary_body")" '{note: $note}')
  if ! post_one "$payload" "" ""; then
    rollback
    echo "post-draft-note.sh: $fail_msg" >&2
    exit 1
  fi
fi

# 5. Success output.
if [[ $dry_run -eq 1 ]]; then
  jq -nc --argjson posted "$posted" '{dryRun:true, wouldPost:$posted}'
  exit 0
fi
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
