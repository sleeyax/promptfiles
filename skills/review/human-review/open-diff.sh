#!/usr/bin/env bash
# Open one or more files of an MR diff as native VS Code side-by-side diffs.
#
# Usage:
#   open-diff.sh --base <sha> --head <sha> --path <p> [--path <p> …] [--tmp <dir>]
#   open-diff.sh --base <sha> --head <sha> --paths-file <file> [--tmp <dir>]
#     [--open-positioning right|left|first|last] [--focus-recent true|false]
#
# Pass a whole group's files in one call, most important first.
#
# TAB ORDER AND CLOSE ORDER. The group's most important file must end up active,
# and closing it must reveal the second, then the third. Which editor VS Code
# focuses after a close is a user setting, so both cases have to hold at once:
#
#   focusRecentEditorAfterClose = true (default) — focus follows the
#     most-recently-used stack, not the tab strip. Opening 1,2,…,N and focusing 1
#     leaves an MRU of [1, N, N-1, …, 2], so closing 1 jumps to the LEAST
#     important file. Touching the tabs N…1 afterwards leaves MRU = [1, 2, …, N].
#
#   focusRecentEditorAfterClose = false — focus moves to the tab on the right, so
#     the strip itself must run most- to least-important. Under openPositioning
#     "right"/"last" (default "right") a new tab lands after the active one and
#     opening in priority order is already correct; under "left"/"first" the
#     opens have to be reversed, which fixes the MRU stack too and makes the
#     second pass unnecessary.
#
# Settings come from the workspace, machine, and user settings.json (see
# vscode_setting). When they cannot be read — a devcontainer or SSH remote keeps
# user settings on the client — the VS Code defaults are assumed, which is the
# case the reverse focus pass handles anyway.
#
# Re-opening an already-open diff focuses its tab; it neither duplicates it nor
# moves it in the strip.
#
# The RIGHT pane is deliberately the real working-tree file, not a copy: it is
# what makes the user's selection report the true repo path and `new_line`
# numbers. The file stays editable, so the skill must keep the tree clean.
#
# The LEFT pane is the file's content at <base>, extracted read-only.
#
# WINDOW TARGETING. `code` has no window selector, and VS Code only injects the
# per-window socket (VSCODE_IPC_HOOK_CLI) into integrated terminals — an agent
# shell falls back to the shared main-process socket, so with several windows
# open a request whose paths span no single workspace lands in the wrong one.
# Keeping BOTH panes inside the repo resolves it to the window owning this
# folder; hence the base pane defaults to <repo>/.git/human-review rather than
# /tmp. Inside .git it is never tracked and never dirties `git status`. --tmp
# overrides it for testing.
#
# Status handling (derived, not passed in):
#   M / R  old blob   vs working tree   (red + green)
#   A      empty left vs working tree   (all green)
#   D      old blob   vs empty right    (all red)
#
# Binary files are reported and skipped — there is nothing to anchor a comment to.
#
# Prints a JSON array, one object per requested path:
#   [{"path":"…","status":"M","left":"…","right":"…","opened":true}, …]
# Skipped binaries appear as {"…","opened":false,"reason":"binary"}.

set -euo pipefail

die() { echo "open-diff.sh: $*" >&2; exit 1; }

base=""; head=""; tmp=""; paths=(); positioning=""; focus_recent=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)             base="$2"; shift 2 ;;
    --head)             head="$2"; shift 2 ;;
    --path)             paths+=("$2"); shift 2 ;;
    --paths-file)       mapfile -t -O "${#paths[@]}" paths < "$2"; shift 2 ;;
    --tmp)              tmp="$2"; shift 2 ;;
    --open-positioning) positioning="$2"; shift 2 ;;
    --focus-recent)     focus_recent="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "$base" ]] || die "--base required"
[[ -n "$head" ]] || die "--head required"
[[ ${#paths[@]} -gt 0 ]] || die "at least one --path (or --paths-file) required"

command -v code >/dev/null 2>&1 || die "'code' CLI not on PATH — cannot open the editor"
command -v jq   >/dev/null 2>&1 || die "jq not found on PATH"

repo="$(git rev-parse --show-toplevel)" || die "not inside a git repository"

# Default the scratch panes into the repo — see WINDOW TARGETING above.
: "${tmp:=$repo/.git/human-review}"

# Read one VS Code setting from the settings.json files that can define it, in
# increasing order of precedence. Prints the bare value ("right", "false", …),
# or nothing when no file sets it.
#
# These files are JSONC — comments and trailing commas — so they are matched by
# key rather than parsed. A key/value pair sits on its own line in practice, so
# dropping line comments first is enough to ignore a commented-out setting.
vscode_setting() {
  local key="$1" f line val out=""
  local files=(
    "${VSCODE_PORTABLE:-/nonexistent}/user-data/User/settings.json"
    "$HOME/.config/Code/User/settings.json"
    "$HOME/.config/Code - Insiders/User/settings.json"
    "$HOME/.config/Code - OSS/User/settings.json"
    "$HOME/.config/VSCodium/User/settings.json"
    "$HOME/Library/Application Support/Code/User/settings.json"
    "${APPDATA:-/nonexistent}/Code/User/settings.json"
    "$HOME/.vscode-server/data/Machine/settings.json"
    "$HOME/.vscode-remote/data/Machine/settings.json"
    "$repo/.vscode/settings.json"
  )
  for f in "${files[@]}"; do
    [[ -r "$f" ]] || continue
    line=$(sed 's://.*$::' "$f" \
      | grep -oE "\"$key\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|true|false|[0-9]+)" \
      | tail -1) || true
    [[ -n "$line" ]] || continue
    val=$(sed -E 's/^.*:[[:space:]]*//; s/"//g' <<<"$line")
    [[ -n "$val" ]] && out="$val"
  done
  printf '%s' "$out"
}

[[ -n "$positioning"  ]] || positioning=$(vscode_setting "workbench.editor.openPositioning")
[[ -n "$focus_recent" ]] || focus_recent=$(vscode_setting "workbench.editor.focusRecentEditorAfterClose")
: "${positioning:=right}"    # VS Code defaults
: "${focus_recent:=true}"

# Tabs land after the active one under "right"/"last", so opening in priority
# order already yields a priority-ordered strip; under "left"/"first" they land
# before it and the opens have to be reversed to get the same strip.
open_reversed=0
case "$positioning" in
  left|first) open_reversed=1 ;;
esac

# An editor limit smaller than the group evicts the group's own tabs as they
# open — the user would silently get the tail of the group only.
limit_enabled=$(vscode_setting "workbench.editor.limit.enabled")
if [[ "$limit_enabled" == "true" ]]; then
  limit_value=$(vscode_setting "workbench.editor.limit.value")
  : "${limit_value:=10}"
  if [[ "$limit_value" =~ ^[0-9]+$ && ${#paths[@]} -gt limit_value ]]; then
    echo "open-diff.sh: workbench.editor.limit.value=$limit_value < ${#paths[@]} files — VS Code will close earlier tabs in this group" >&2
  fi
fi

# Resolve panes for one path and open it. Echoes one JSON object.
open_one() {
  local entry="$1"
  local path old_override="" raw status old_path left right

  # An entry may be "path" or "path<TAB>oldPath". The override comes from
  # analyze-diff.sh, which runs relaxed rename/copy detection; without it this
  # script's own plain -M would call a moved-and-edited file a fresh add and
  # show it as all green instead of diffing it against its source.
  path="${entry%%$'\t'*}"
  [[ "$entry" == *$'\t'* ]] && old_override="${entry#*$'\t'}"

  raw=$(git diff --name-status -M "$base...$head" -- "$path" | head -1)
  if [[ -z "$raw" ]]; then
    jq -nc --arg p "$path" '{path:$p, opened:false, reason:"no diff entry"}'
    return 0
  fi
  status=$(cut -f1 <<<"$raw" | cut -c1)
  old_path="$path"
  if [[ "$status" == "R" || "$status" == "C" ]]; then
    old_path=$(cut -f2 <<<"$raw")
    path=$(cut -f3 <<<"$raw")
  fi
  if [[ -n "$old_override" && "$old_override" != "$path" ]]; then
    old_path="$old_override"
    # Base content comes from the source path, so this is a rename either way.
    [[ "$status" == "A" ]] && status="R"
  fi

  # Binary check — numstat reports "-" for both counts.
  if git diff --numstat "$base...$head" -- "$path" | awk '$1=="-" && $2=="-"{exit 0} {exit 1}'; then
    jq -nc --arg p "$path" --arg s "$status" \
      '{path:$p, status:$s, opened:false, reason:"binary"}'
    return 0
  fi

  left="$tmp/base/$old_path"
  right="$repo/$path"
  mkdir -p "$(dirname "$left")"

  # Panes are chmod'd read-only after writing, so a re-open (revisiting a group,
  # or the focus pass below) must clear the previous one or the redirect fails.
  rm -f "$left"

  case "$status" in
    A) : > "$left" ;;
    M|R|C|D)
      git show "$base:$old_path" > "$left" 2>/dev/null \
        || die "could not extract $old_path at $base (git show failed)" ;;
    *) die "unhandled status '$status' for $path" ;;
  esac
  chmod a-w "$left"

  # A deleted file has no working-tree side; diff against an empty right pane.
  if [[ "$status" == "D" ]]; then
    right="$tmp/deleted/$path"
    mkdir -p "$(dirname "$right")"
    rm -f "$right"
    : > "$right"
    chmod a-w "$right"
  fi

  code --diff "$left" "$right" --reuse-window

  jq -nc \
    --arg p "$path" --arg s "$status" --arg l "$left" --arg r "$right" \
    '{path:$p, status:$s, left:$l, right:$r, opened:true}'
}

# Open in the order that leaves the tab strip running most- to least-important
# from left to right, then report in priority order regardless.
order=()
for ((i=0; i<${#paths[@]}; i++)); do order+=("$i"); done
if [[ $open_reversed -eq 1 ]]; then
  rev=(); for ((i=${#order[@]}-1; i>=0; i--)); do rev+=("${order[i]}"); done
  order=("${rev[@]}")
fi

declare -A by_index
for i in "${order[@]}"; do by_index["$i"]=$(open_one "${paths[i]}"); done
results=$(for ((i=0; i<${#paths[@]}; i++)); do printf '%s\n' "${by_index[$i]}"; done | jq -s .)

# Focus pass. Touching the opened tabs from least to most important leaves the
# most important one active AND leaves the MRU stack in priority order, so
# closing the active tab reveals the next file down whichever order VS Code
# follows. Two cases need no pass at all:
#   - the opens already ran least-important first, which is the same sequence
#   - focus follows the tab strip, which the open order has already ordered, so
#     only the first file has to be brought to the front
mapfile -t focus_seq < <(jq -r 'map(select(.opened)) | .[] | "\(.left)\t\(.right)"' <<<"$results")
if [[ ${#focus_seq[@]} -gt 1 && $open_reversed -eq 0 ]]; then
  if [[ "$focus_recent" == "false" ]]; then
    focus_seq=("${focus_seq[0]}")
  else
    rev=(); for ((i=${#focus_seq[@]}-1; i>=0; i--)); do rev+=("${focus_seq[i]}"); done
    focus_seq=("${rev[@]}")
  fi
  for entry in "${focus_seq[@]}"; do
    code --diff "${entry%%$'\t'*}" "${entry#*$'\t'}" --reuse-window
  done
fi

echo "open-diff.sh: openPositioning=$positioning focusRecentEditorAfterClose=$focus_recent" >&2

jq -c . <<<"$results"
