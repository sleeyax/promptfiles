#!/usr/bin/env bash
set -uo pipefail

input=$(cat)

IFS=$'\t' read -r model dir used total pct <<<"$(
  printf '%s' "$input" | jq -r '[
    .model.display_name // "?",
    .workspace.current_dir // ".",
    .context_window.total_input_tokens // 0,
    .context_window.context_window_size // 200000,
    ((.context_window.used_percentage // 0) | floor)
  ] | @tsv'
)"

branch=$(git -C "$dir" branch --show-current 2>/dev/null)
# --show-current is empty on a detached HEAD, so fall back to the short SHA.
[ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)

human() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n / 1000000
    else if (n >= 10000) printf "%dk", n / 1000
    else if (n >= 1000) printf "%.1fk", n / 1000
    else printf "%d", n
  }'
}

if   [ "$pct" -ge 90 ]; then color=$'\033[31m'
elif [ "$pct" -ge 80 ]; then color=$'\033[38;5;208m'
elif [ "$pct" -ge 70 ]; then color=$'\033[33m'
else                        color=$'\033[32m'
fi
dim=$'\033[2m'
cyan=$'\033[36m'
reset=$'\033[0m'

git_segment=""
[ -n "$branch" ] && git_segment="${cyan}${branch}${reset} ${dim}·${reset} "

printf '%s%s%s %s·%s %s%s%s/%s tokens (%s%%)%s\n' \
  "$dim" "$model" "$reset" \
  "$dim" "$reset" \
  "$git_segment" \
  "$color" "$(human "$used")" "$(human "$total")" "$pct" "$reset"
