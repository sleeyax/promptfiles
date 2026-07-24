---
name: review-changes
description: Review the current branch's changes with a chosen reviewer (Codex CLI / Claude Code / other, whichever harness you're in), then fix simple findings in their own commits. Use when the user wants to self-review code before pushing, or asks to review a branch. For posting a GitLab MR review use review-mr instead.
---

# Review Changes

Scope: $ARGUMENTS

Review the current branch's changes with a user-chosen reviewer, then fix the **simple, unambiguous** findings in their own commits so the branch lands in a ready-to-review state before it's pushed. Anything that needs human judgement is reported, not fixed.

The skill runs in whichever harness the user invoked it from (Claude Code, Codex, …) and offers the reviewers that harness can actually drive. The chosen reviewer is read-only — either an in-process subagent or a CLI subprocess. This skill's agent is the **only editor** — it triages the findings and applies the fixes itself.

## Hard rules

- The review step is read-only. Only this skill's agent edits files, and only after the step 6 apply gate.
- Auto-fix **only** localized, unambiguous findings (see step 5). Report everything else for the human reviewer — never silently make architectural, security-sensitive, behaviour-changing, or judgement-call edits.
- Every gate — reviewer choice, apply, dirty-tree, re-review — is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer. Commits go through the `git-commit` skill's own gate.
- Never push. The user pushes manually.
- Don't dump the full diff into a prompt or hand it to the reviewer as one blob. Give the reviewer the base ref and let it run `git diff` / read files itself.
- Never spawn a reviewer that can edit: an in-process subagent gets read-only tools, and a reviewer CLI is launched with its write tools denied. A reviewer that can't be constrained is not an option — pick another one.

## Workflow

### 1. Determine scope

1. Detect the base branch: `git symbolic-ref refs/remotes/origin/HEAD` (strip the `refs/remotes/origin/` prefix); fall back to `main`.
2. Detect the current branch: `git rev-parse --abbrev-ref HEAD`.
3. Default scope is the branch's committed changes vs the base: `<base>...HEAD`.
4. `$ARGUMENTS` may override:
   - a branch name → use it as the base.
   - `uncommitted` → review staged + unstaged + untracked changes instead.
5. If there's no diff in scope, report that there's nothing to review and stop.

### 2. Identify the current harness

You already know this: your own system prompt names the harness you're running in — Claude Code ("You are Claude Code") or Codex ("You are Codex"). Use that. Don't infer it from which tools you happen to have. If you genuinely can't tell, ask the user which harness this is instead of guessing.

It decides how a reviewer is launched — in **Claude Code** the Claude reviewer is an in-process subagent; in **Codex** both reviewers run as CLI subprocesses (`codex review`, `claude -p`).

Then check which reviewer CLIs are installed — `command -v codex claude` — so step 3 only offers what can actually run.

### 3. Choose the reviewer

Ask — "Review changes?". The options depend on the harness from step 2; recommend the *other* harness, so the review is a genuine second opinion rather than the same model re-reading its own work.

In **Claude Code**:

- **Codex** (Recommended) — Codex CLI, default model.
- **Claude Code** — a read-only review subagent, default model.
- **Other** — free-form: the user names a harness + model (e.g. `claude code sonnet`, `codex gpt-5-codex`).
- **Skip** — exit cleanly without reviewing.

In **Codex**:

- **Claude Code** (Recommended) — `claude -p`, default model.
- **Codex** — a nested `codex review` subprocess, default model.
- **Other** — free-form, as above.
- **Skip** — exit cleanly without reviewing.

Drop any option whose CLI is missing, and say why it's missing. If only **Skip** remains, report that and stop.

### 4. Run the review (read-only)

Route by the choice. Give every reviewer the quality bar below, plus the base ref (`<base>...HEAD`) or the uncommitted scope — never the diff itself.

- **Codex CLI** → `codex review --base <base>` (or `codex review --uncommitted` for the uncommitted scope), plus `-m <model>` when a model was named. Capture stdout as the findings report. Same command whichever harness you're in.
- **Claude Code, in-process** (Claude Code only) → spawn a subagent (Agent tool) constrained to read-only tools (read / search / read-only git like `git diff`, `git log`, `git show`; no edit/write), with the model override if one was named. Prompt it with the base ref + the quality bar and have it return a findings report.
- **Claude Code, CLI** (from Codex or another harness) → one non-interactive run with write tools withheld:

  ```sh
  claude -p --allowed-tools "Read Grep Glob Bash(git diff:*) Bash(git log:*) Bash(git show:*)" \
    --disallowed-tools "Edit Write NotebookEdit" \
    "<review prompt: base ref + scope + quality bar + output format>"
  ```

  Add `--model <model>` when one was named. Capture stdout as the findings report.
- **Other** → parse the input: `claude` / `claude code` family → the Claude Code route for the current harness with that model; `codex` family → `codex review -m <model> --base <base>`. An unrecognized harness → ask the user for the exact non-interactive, read-only review command to run.

If the reviewer fails (non-zero exit, missing or unauthenticated CLI), surface its stderr, suggest the likely fix (e.g. `codex login`, `claude login`), and offer to pick a different reviewer. Do not silently fall back to reviewing inline.

**Quality bar:** concrete bugs, correctness issues, security problems, and maintainability risks *introduced by these changes* — cite file + line, verify against the actual files, no speculation. Nits/style are allowed but flagged low.

### 5. Triage the findings

Split every finding into one of two buckets:

- **Simple / safe (auto-fixable)** — one obvious correct fix, confined to lines/files already in the diff, with no behaviour/API/design change and no new dependency (e.g. null check, off-by-one, wrong variable, missing `await`, obvious resource leak, logic typo).
- **Complex / uncertain (leave for the reviewer)** — architectural, security-sensitive, ambiguous, behaviour-changing, or otherwise a judgement call.

Print a numbered list. For each finding show its bucket, location, and — for the simple ones — the proposed fix.

### 6. Apply the fixes

First, if the working tree is dirty, ask: **Stash** (restore after) / **Proceed anyway** / **Report only** — so per-finding fix commits stay clean.

Then ask: **Apply proposed fixes** / **Pick a subset** / **Report only (no changes)**.

On apply: edit only the chosen simple findings. Keep the change tight to each finding — no unrelated refactors — and confirm each fix is actually correct.

### 7. Commit the fixes

One commit per finding, grouped only when a few fixes clearly belong together. For each commit, invoke the [git-commit](../git-commit/SKILL.md) skill (its confirmation gate applies). These commits land **after** the existing branch commits.

### 8. Offer a re-review

Ask: **Re-review** (run another pass from step 3, to confirm the fixes are clean and catch anything new) / **Finish**.

### 9. Report

Summarize:

- Reviewer + model used, and how it ran (in-process subagent or CLI).
- Counts: findings found / fixed / left for the reviewer.
- The fix commit SHAs.
- The list of complex/uncertain findings the human reviewer should still address.
