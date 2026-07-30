#!/usr/bin/env bash
# Report the state of an in-progress or finished review: what is planned, what
# has been commented on, and what was never looked at.
#
# Usage:
#   review-state.sh --plan <plan.json> [--findings <findings.json>]
#                   [--threads <existing-threads.json>]
#
# Serves resuming at startup and the coverage report before posting: a review
# that touched 6 of 74 files should say so, which the pre-submission list alone
# cannot show.
#
# Both sources are optional and their paths are unioned. `--findings` is the
# local queue, `--threads` the output of `existing-threads.sh`. A review whose
# first batch was posted has an empty queue and all of its progress on the
# server, which is the case that makes resuming across sessions work at all.
#
# Prints:
#   {
#     "groups":[{"index":1,"title":"…","files":N,"commented":N,
#                "commentedLocal":N,"commentedRemote":N,"uncommented":[…]}],
#     "totals":{"groupsTotal":N,"groupsTouched":N,"filesTotal":N,
#               "filesCommented":N,"comments":N,"remoteComments":N},
#     "resumeAt":{"index":N,"title":"…"} | null,
#     "continueAt":{"index":N,"title":"…"} | null,
#     "furthest":{"index":N,"title":"…"} | null,
#     "skippedGroups":[{"index":N,"title":"…"}],
#     "untouchedGroups":["…"]
#   }
#
# `continueAt` is the group after the furthest one with any comment against it —
# where the user actually left off, since the walk runs in plan order. It is the
# one to resume at. `resumeAt` is the first group with no comments at all, which
# is earlier whenever a group was deliberately passed over with nothing to say;
# those groups are listed in `skippedGroups` so the choice stays the user's.

set -euo pipefail

die() { echo "review-state.sh: $*" >&2; exit 1; }

plan=""; findings=""; threads=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)     plan="$2"; shift 2 ;;
    --findings) findings="$2"; shift 2 ;;
    --threads)  threads="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$plan" ]]  || die "--plan required"
[[ -r "$plan" ]]  || die "plan not readable: $plan"
command -v jq >/dev/null 2>&1 || die "jq not found on PATH"

# A missing findings file is normal — it means nothing is queued locally.
if [[ -n "$findings" && -r "$findings" ]]; then
  local_paths=$(jq -c '[.findings[].path] | unique' "$findings")
  n_comments=$(jq '.findings | length' "$findings")
else
  local_paths='[]'
  n_comments=0
fi

# So is a missing threads file — it means the MR was not consulted.
if [[ -n "$threads" && -r "$threads" ]]; then
  remote_paths=$(jq -c '.humanPaths // []' "$threads")
  n_remote=$(jq '.counts.human // 0' "$threads")
else
  remote_paths='[]'
  n_remote=0
fi

jq -n \
  --slurpfile plan "$plan" \
  --argjson localPaths "$local_paths" \
  --argjson remotePaths "$remote_paths" \
  --argjson nComments "$n_comments" \
  --argjson nRemote "$n_remote" '
  ($plan[0]) as $groups
  | (($localPaths + $remotePaths) | unique) as $commented
  # A comment can sit on a file this plan does not list — an earlier session
  # grouped things differently, or the user opened a file for context. Counting
  # those against `filesTotal` would report coverage above 100%.
  | ([ $groups[].files[] ] | unique) as $planned
  | [ $groups | to_entries[] | {
        index: (.key + 1),
        title: .value.title,
        files: (.value.files | length),
        commented:       [ .value.files[] | select(. as $f | $commented   | index($f)) ] | length,
        commentedLocal:  [ .value.files[] | select(. as $f | $localPaths  | index($f)) ] | length,
        commentedRemote: [ .value.files[] | select(. as $f | $remotePaths | index($f)) ] | length,
        uncommented: [ .value.files[] | select(. as $f | ($commented | index($f)) | not) ]
      } ] as $g
  | ([ $g[] | select(.commented > 0) ] | last) as $furthest
  | {
      groups: $g,
      totals: {
        groupsTotal:    ($g | length),
        groupsTouched:  ([ $g[] | select(.commented > 0) ] | length),
        filesTotal:     ([ $g[].files ] | add // 0),
        filesCommented: ([ $commented[] | select(. as $f | $planned | index($f)) ] | length),
        comments:       $nComments,
        remoteComments: $nRemote
      },
      resumeAt: ([ $g[] | select(.commented == 0) ] | first | if . then {index, title} else null end),
      continueAt: (
        if $furthest == null
        then ($g | first | if . then {index, title} else null end)
        else ([ $g[] | select(.index > $furthest.index) ] | first
              | if . then {index, title} else null end)
        end
      ),
      furthest: (if $furthest then {index: $furthest.index, title: $furthest.title} else null end),
      skippedGroups: [ $g[]
        | select($furthest != null and .commented == 0 and .index < $furthest.index)
        | {index, title} ],
      untouchedGroups: [ $g[] | select(.commented == 0) | .title ]
    }'
