#!/usr/bin/env bash
# Classify a prospective comment anchor against the diff before it is queued.
#
# Usage:
#   check-anchor.sh --base <sha> --head <sha> --path <p> --start <N> --end <M>
#
# GitLab accepts a positional note on any line of the new file, including one far
# from every hunk: the POST succeeds, the anchor verification passes, the note is
# stored correctly — and the diff view never renders it, because it only shows
# lines inside a hunk's context. Nothing downstream can detect that, so this
# check is the only place it can be caught.
#
# Prints:
#   {"verdict":"ok|context-only|outside-diff","hasAddedLines":bool,
#    "inHunk":bool,"nearestHunkLine":N,"hunkCount":N}
#
#   ok           at least one line in [start,end] was added by this MR — anchor
#                is on changed code and will render
#   context-only inside a hunk's context but no added lines — renders, but the
#                comment is about code this MR did not touch
#   outside-diff not in any hunk — WILL NOT RENDER in the MR diff view

set -euo pipefail

die() { echo "check-anchor.sh: $*" >&2; exit 1; }

base=""; head=""; path=""; start=""; end=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)  base="$2";  shift 2 ;;
    --head)  head="$2";  shift 2 ;;
    --path)  path="$2";  shift 2 ;;
    --start) start="$2"; shift 2 ;;
    --end)   end="$2";   shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$base" && -n "$head" && -n "$path" ]] || die "--base, --head, --path required"
[[ -n "$start" ]] || die "--start required"
: "${end:=$start}"
command -v jq >/dev/null 2>&1 || die "jq not found on PATH"

# Walk the diff tracking new-file line numbers. Hunk ranges come from the `@@`
# headers (default -U3, which is exactly what GitLab renders); added lines are
# the `+` lines within them.
git diff -M "$base...$head" -- "$path" | awk -v s="$start" -v e="$end" '
  /^\+\+\+ / || /^--- / { next }
  /^@@/ {
    inhunk = 1
    match($0, /\+[0-9]+(,[0-9]+)?/)
    spec = substr($0, RSTART + 1, RLENGTH - 1)
    n = split(spec, a, ",")
    c = a[1] + 0
    d = (n > 1) ? a[2] + 0 : 1
    hc++
    hstart[hc] = c
    hend[hc]   = (d > 0) ? c + d - 1 : c
    cur = c
    next
  }
  !inhunk { next }
  /^\+/ { if (cur >= s && cur <= e) added = 1; cur++; next }
  /^-/  { next }
  { cur++ }
  END {
    inh = 0; near = -1
    for (i = 1; i <= hc; i++) {
      if (s <= hend[i] && e >= hstart[i]) inh = 1
      d1 = (s > hend[i]) ? s - hend[i] : ((hstart[i] > e) ? hstart[i] - e : 0)
      if (near < 0 || d1 < near) { near = d1; nearline = hstart[i] }
    }
    verdict = added ? "ok" : (inh ? "context-only" : "outside-diff")
    printf "%s\t%d\t%d\t%d\t%d\n", verdict, added ? 1 : 0, inh, nearline + 0, hc
  }
' | {
  IFS=$'\t' read -r verdict added inhunk nearline hunks || die "could not parse diff for $path"
  jq -nc \
    --arg v "$verdict" \
    --argjson a "$([[ "$added"  == "1" ]] && echo true || echo false)" \
    --argjson i "$([[ "$inhunk" == "1" ]] && echo true || echo false)" \
    --argjson n "${nearline:-0}" --argjson h "${hunks:-0}" \
    '{verdict:$v, hasAddedLines:$a, inHunk:$i, nearestHunkLine:$n, hunkCount:$h}'
}
