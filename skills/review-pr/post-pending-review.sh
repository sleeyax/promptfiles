#!/usr/bin/env bash
# Post a batch of GitHub PR review comments as a single pending review.
#
# Usage:
#   post-pending-review.sh --repo <owner/repo> --pr <number> --findings <path> [--host <hostname>]
#
# Reads the JSON, validates it against findings.schema.json (using
# `check-jsonschema` if present, else jq-based structural checks), refuses to
# run if the authenticated user already has a pending review on the PR, then
# posts the whole batch — the summary as the review `body` plus every inline
# comment — as ONE pending review via a single `POST .../pulls/<n>/reviews`
# call with `event` omitted. Because it is one atomic request there is no
# partial state and nothing to roll back.
#
# On success: prints `{"posted":N,"reviewId":<id>}` to stdout, exit 0.
# On failure: forwards stderr from gh/jq, exits non-zero.
#
# The review is left PENDING (unsubmitted). The user submits (Approve /
# Comment / Request changes) or discards it via the GitHub UI or `gh`.

set -euo pipefail

die() { echo "post-pending-review.sh: $*" >&2; exit 1; }

repo=""; pr=""; findings_file=""; host="github.com"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     repo="$2"; shift 2 ;;
    --pr)       pr="$2"; shift 2 ;;
    --findings) findings_file="$2"; shift 2 ;;
    --host)     host="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$repo" ]]          || die "--repo required"
[[ -n "$pr" ]]            || die "--pr required"
[[ -n "$findings_file" ]] || die "--findings required"
[[ -r "$findings_file" ]] || die "findings file not readable: $findings_file"

command -v gh >/dev/null 2>&1 || die "gh not found on PATH"
command -v jq >/dev/null 2>&1 || die "jq not found on PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema="$script_dir/findings.schema.json"
[[ -r "$schema" ]] || die "schema not found: $schema"

# gh api resolves the host from --hostname; default is github.com.
gh_api() { gh api --hostname "$host" "$@"; }

# 1. Schema validation.
if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$findings_file" >&2 \
    || die "findings.json failed schema validation"
else
  jq -e '
    (.commitId | type=="string" and length>=7) and
    (.findings | type=="array") and
    (.findings | all(
      (.severity as $s | ["blocker","concern","suggestion","nit"] | index($s) != null) and
      (.path | type=="string" and length>0) and
      (.line | type=="number" and . >= 1 and (.|floor)==.) and
      (.side as $x | ["LEFT","RIGHT"] | index($x) != null) and
      ((.startLine // null) == null or (.startLine | type=="number" and . >= 1 and (.|floor)==.)) and
      ((.startSide // null) == null or (.startSide as $x | ["LEFT","RIGHT"] | index($x) != null)) and
      (.body | type=="string" and length>0)
    )) and
    ((.summary // null) == null or (.summary.body | type=="string" and length>0))
  ' "$findings_file" >/dev/null \
    || die "findings.json failed structural checks (install check-jsonschema for detailed errors)"
fi

# 2. Bail if the user already has a pending review — GitHub allows only one per
# user per PR, and we never touch the user's in-progress draft.
me=$(gh_api user --jq '.login' 2>/dev/null) || die "could not resolve authenticated user (is gh logged in for $host?)"
existing=$(gh_api --paginate "repos/$repo/pulls/$pr/reviews" \
  --jq "[.[] | select(.state==\"PENDING\" and .user.login==\"$me\")] | length" 2>/dev/null || echo 0)
if [[ "${existing:-0}" != "0" ]]; then
  die "you already have a pending review on $repo#$pr — submit or discard it on GitHub first, then re-run."
fi

# 3. Build the create-review payload. `event` is omitted so the review stays
# PENDING. Map schema field names to the API's snake_case; include `body` only
# when a summary is present.
payload=$(jq '{
  commit_id: .commitId,
  comments: [ .findings[] | (
    { path, line, side, body }
    + (if has("startLine") then { start_line: .startLine } else {} end)
    + (if has("startSide") then { start_side: .startSide } else {} end)
  ) ]
} + (if has("summary") then { body: .summary.body } else {} end)' "$findings_file")

n_comments=$(jq '.findings | length' "$findings_file")

# 4. Post once.
if ! response=$(printf '%s' "$payload" \
  | gh_api -X POST "repos/$repo/pulls/$pr/reviews" --input - 2>&1); then
  echo "post-pending-review.sh: $response" >&2
  exit 1
fi

review_id=$(printf '%s' "$response" | jq -r '.id // empty' 2>/dev/null || true)
if [[ -z "$review_id" ]]; then
  echo "post-pending-review.sh: missing review id in response: $response" >&2
  exit 1
fi

jq -nc \
  --argjson posted "$n_comments" \
  --argjson reviewId "$review_id" \
  '{posted:$posted, reviewId:$reviewId}'
