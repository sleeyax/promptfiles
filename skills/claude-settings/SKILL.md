---
name: claude-settings
description: Toggle token-hungry Claude Code features (bundled skills, workflows, artifacts, hooks, auto memory, built-in tools, ...) on or off via ~/.claude/settings.json to shrink the system prompt. Only use when the user explicitly invokes /claude-settings; never trigger proactively.
---

# Claude Settings

Show which token-saving levers are currently on or off in the user-level Claude Code settings, let the user flip any of them, and apply the change safely. This is a toggle, not an install: it is safe to re-run any time to flip features back.

## Hard rules

- **Never write without an explicit user choice.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't, ask in plain text with the same numbered options and stop until the user replies. Selecting nothing means writing nothing.
- **Merge, never rewrite.** The settings file holds unrelated keys (`model`, `enabledPlugins`, `tui`, ...). Only set or delete the exact keys the user chose, via jq. Never emit a hand-built full file.
- **Leave scoped permission rules alone.** Only *bare* tool names in `permissions.deny` (e.g. `"NotebookEdit"`) remove the tool's definition from the prompt payload. Entries containing `(` — e.g. `"Bash(rm *)"` — are scoped rules: they block execution but save zero tokens. Never add, remove, or reorder them, and never offer them as toggles.
- **jq is required.** If `command -v jq` fails, stop and tell the user to install it. Never fall back to editing the JSON by hand or with sed.
- **User-level file only.** The target is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`. Do not touch project `.claude/settings.json` files even if present.
- **Walk through everything, every run.** The walkthrough has two mandatory halves: the feature flags (step 3a) and the built-in tools catalog (step 3b). Never end the asking phase after the feature flags alone — 3b runs even if the user selected nothing in 3a.

## Feature catalog

A feature is **ON** when its key is absent from the settings file or set to any value other than the "value when OFF" below. To turn a feature back ON, **delete the key** (restores the default and keeps the file minimal) rather than writing the opposite value, unless the user explicitly wants it pinned.

| Feature | Settings key | Value when OFF | Token impact | What you lose when OFF |
|---|---|---|---|---|
| Bundled skills catalog | `disableBundledSkills` | `true` | Large | Built-in skills catalogue in the system prompt |
| Workflows | `disableWorkflows` | `true` | Large | Workflow tool and workflow commands |
| Artifacts | `disableArtifact` | `true` | Medium | Artifact tool (publishing to claude.ai) |
| Background agents | `disableAgentView` | `true` | Medium | `claude agents`, `/background`, supervisor |
| claude.ai connectors | `disableClaudeAiConnectors` | `true` | Medium | Auto-fetched claude.ai MCP connectors |
| Remote control | `disableRemoteControl` | `true` | Small | Controlling the session remotely |
| Hooks + status line | `disableAllHooks` | `true` | Varies | ALL hooks and the custom status line |
| Auto memory | `autoMemoryEnabled` | `false` | Medium | Automatic memory across sessions |
| File checkpointing | `fileCheckpointingEnabled` | `false` | Small | File snapshots for `/rewind` |
| Auto-compact | `autoCompactEnabled` | `false` | Small | Automatic compaction; caution: hitting the context limit then ends the session, which may cost more than it saves |
| Away summaries | `awaySummaryEnabled` | `false` | Small | Session recap after returning from absence |

### Built-in tools (`permissions.deny`)

Adding a **bare** tool name to `permissions.deny` strips that tool's definition from the prompt payload entirely. A tool is ON when its bare name is absent from the array. Walk the user through every group below — don't cherry-pick a few candidates. Accept any other bare tool name the user asks for.

| Group | Tools | What you lose when denied |
|---|---|---|
| Plan mode | `EnterPlanMode`, `ExitPlanMode` | Plan mode entirely |
| Scheduling & remote | `CronCreate`, `CronDelete`, `CronList`, `ScheduleWakeup`, `RemoteTrigger`, `PushNotification` | Scheduled/recurring tasks, remote triggers, push notifications |
| Web | `WebFetch`, `WebSearch` | Fetching URLs and searching the web (docs lookups suffer) |
| Agent teamwork | `SendMessage`, `TaskOutput`, `TaskStop`, `Monitor` | Messaging/inspecting background agents (keep if you use subagents) |
| Editor & review extras | `NotebookEdit`, `DesignSync`, `ReportFindings`, `LSP` | Jupyter edits, design sync, structured review findings, language-server queries |
| Session niceties | `TodoWrite`, `AskUserQuestion` | Todo tracking; interactive multiple-choice questions |

Caveats to state when offering these:

- **Never offer to deny core tools** (`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Agent`, `Skill`, `ToolSearch`) — that breaks basic operation, and if the user insists, warn them first.
- **Denying `AskUserQuestion` degrades every interactive skill, including this one** (it falls back to plain-text questions). Flag this explicitly if selected.
- Tools whose feature also has a settings flag (e.g. `Artifact` / `disableArtifact`, `Workflow` / `disableWorkflows`) are better turned off via the flag — offer the flag, not the deny entry.
- This list tracks the current Claude Code tool set and may lag behind new releases; if the user names a tool not listed here, take it at face value as long as it's a bare name.

## Steps

### 1. Read current state — one call

```sh
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
command -v jq || echo "NO-JQ"
[ -f "$CFG" ] && jq . "$CFG" || echo "MISSING"
```

- `NO-JQ` → stop and tell the user to install jq.
- `MISSING` → treat the current state as `{}` (everything ON) and note the file will be created on apply.
- jq parse error → **stop**. Show jq's error and the file path and tell the user to fix or delete the file themselves. Never write over a file that doesn't parse.

### 2. Show the state table

Render two compact tables for the user:

1. **Features**: Feature | State (ON/OFF) | Token impact | What turns off — one row per catalog entry, state derived from the catalog rules.
2. **Built-in tools**: Group | Tools | State — one row per group from the tools catalog, marking each tool ON or OFF (OFF = its bare name is in `permissions.deny`).

If scoped deny rules exist, mention how many there are and that they will be preserved untouched — do not list them as toggles.

### 3a. Ask about feature flags

With `AskUserQuestion`, one call with multiSelect questions grouped as: **Big wins** (bundled skills, workflows, artifacts, background agents), **Cloud & session extras** (connectors, remote control, away summaries, auto memory), **Local machinery** (hooks, checkpointing, auto-compact). Show each item only in its meaningful direction — "Disable X" when it's ON, "Re-enable X" when it's OFF — with the token-impact hint in the label.

### 3b. Ask about built-in tools — mandatory, never skip

Always follows 3a, regardless of what was (or wasn't) selected there. With `AskUserQuestion`, use multiSelect questions, one per tools-catalog group (max 4 questions per call, 4 options per question — spread the groups over as many calls as it takes). **Every tool gets its own option.** The only exceptions are sets that are useless apart and always toggle as one: "Cron tools" (`CronCreate`/`CronDelete`/`CronList`) and "Plan mode" (`EnterPlanMode`/`ExitPlanMode`). Never merge other tools just to fit the option limit — split the group across two questions or an extra call instead. Same direction rule as 3a: "Remove X" when ON, "Restore X" when OFF.

Without `AskUserQuestion`, list all toggles from 3a and 3b as one numbered list and ask the user to reply with the numbers to flip (e.g. `1 2 8`) or `none`, then stop and wait.

After both halves: drop any selection that already matches the current state. If nothing remains (or the user selected nothing), report "no changes made" and end.

### 4. Confirm and apply

Show the exact change set as `key: old → new` (plus deny additions/removals), then confirm with `AskUserQuestion` (options: apply / cancel) — plain-text yes/no only when the tool is unavailable. On apply, run atomically in one command — compose the jq filter from these building blocks:

- Turn a feature OFF: `.disableWorkflows = true` / `.autoMemoryEnabled = false` (value from the catalog)
- Turn a feature ON: `del(.disableWorkflows)`
- Remove a tool: `.permissions.deny = (((.permissions.deny // []) + ["TodoWrite"]) | unique)`
- Restore a tool: `.permissions.deny -= ["TodoWrite"]`, then `del(.permissions.deny)` if the array is empty and `del(.permissions)` if permissions is then empty

```sh
CFG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CFG="$CFG_DIR/settings.json"
mkdir -p "$CFG_DIR"
tmp="$(mktemp "$CFG_DIR/settings.json.XXXXXX")"
jq '<FILTER>' "$CFG" >"$tmp" && jq empty "$tmp" && mv "$tmp" "$CFG" || rm -f "$tmp"
```

When the file is missing, seed it with `jq -n '<FILTER>' >"$tmp"` instead.

### 5. Report

Tell the user what changed (`key: old → new`) and remind them:

- Changes that affect the system prompt (feature flags and denied tools) take effect after a **restart or `/clear`**.
- `/context` before and after shows the actual token savings.
- Re-running `/claude-settings` flips anything back.
