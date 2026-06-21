---
name: review-changes
description: Review the current branch's changes with a chosen harness (Codex CLI / Claude Code / other), then fix simple findings in their own commits. Use when the user wants to self-review code before pushing, or asks to review a branch. For posting a GitLab MR review use review-mr instead.
---

# Review Changes

Scope: $ARGUMENTS

Review the current branch's changes with a user-chosen harness, then fix the **simple, unambiguous** findings in their own commits so the branch lands in a ready-to-review state before it's pushed. Anything that needs human judgement is reported, not fixed.

The chosen harness is the **reviewer** (read-only). This skill's agent is the **only editor** — it triages the findings and applies the fixes itself.

## Hard rules

- The review step is read-only. Only this skill's agent edits files, and only after the step 5 apply gate.
- Auto-fix **only** localized, unambiguous findings (see step 4). Report everything else for the human reviewer — never silently make architectural, security-sensitive, behaviour-changing, or judgement-call edits.
- Every gate — harness choice, apply, dirty-tree, re-review — uses `AskUserQuestion`, never a plain-text prompt. Commits go through the `git-commit` skill's own gate.
- Never push. The user pushes manually.
- Don't dump the full diff into a prompt or hand it to the review subagent as one blob. Give the subagent the base ref and let it run `git diff` / read files itself.

## Workflow

### 1. Determine scope

1. Detect the base branch: `git symbolic-ref refs/remotes/origin/HEAD` (strip the `refs/remotes/origin/` prefix); fall back to `main`.
2. Detect the current branch: `git rev-parse --abbrev-ref HEAD`.
3. Default scope is the branch's committed changes vs the base: `<base>...HEAD`.
4. `$ARGUMENTS` may override:
   - a branch name → use it as the base.
   - `uncommitted` → review staged + unstaged + untracked changes instead.
5. If there's no diff in scope, report that there's nothing to review and stop.

### 2. Choose the review harness

`AskUserQuestion` — "Review changes?":

- **Codex** (Recommended) — Codex CLI, default model.
- **Claude Code** — a read-only review subagent, default model.
- **Other** — free-form: the user names a harness + model (e.g. `claude code sonnet`, `codex gpt-5-codex`).
- **Skip** — exit cleanly without reviewing.

### 3. Run the review (read-only)

Route by the choice. Give every reviewer the quality bar below.

- **Codex** → `codex review --base <base>` (or `codex review --uncommitted` for the uncommitted scope). Capture stdout as the findings report.
- **Claude Code** → spawn a subagent (Agent tool) constrained to read-only tools (read / search / read-only git like `git diff`, `git log`, `git show`; no edit/write). Prompt it with the base ref + the quality bar, and have it return a findings report. It must not edit anything.
- **Other** → parse the input:
  - `claude` / `claude code` family → the read-only review subagent, with that model as the override.
  - `codex` family → `codex review -m <model> --base <base>`.
  - An unrecognized harness → ask the user for the exact non-interactive review command to run.

If the harness fails (non-zero exit, missing/unauthenticated CLI), surface its stderr, suggest the likely fix (e.g. "run `codex login`"), and offer to pick a different harness. Do not silently fall back to reviewing inline.

**Quality bar:** concrete bugs, correctness issues, security problems, and maintainability risks *introduced by these changes* — cite file + line, verify against the actual files, no speculation. Nits/style are allowed but flagged low.

### 4. Triage the findings

Split every finding into one of two buckets:

- **Simple / safe (auto-fixable)** — one obvious correct fix, confined to lines/files already in the diff, with no behaviour/API/design change and no new dependency (e.g. null check, off-by-one, wrong variable, missing `await`, obvious resource leak, logic typo).
- **Complex / uncertain (leave for the reviewer)** — architectural, security-sensitive, ambiguous, behaviour-changing, or otherwise a judgement call.

Print a numbered list. For each finding show its bucket, location, and — for the simple ones — the proposed fix.

### 5. Apply the fixes

First, if the working tree is dirty, `AskUserQuestion`: **Stash** (restore after) / **Proceed anyway** / **Report only** — so per-finding fix commits stay clean.

Then `AskUserQuestion`: **Apply proposed fixes** / **Pick a subset** / **Report only (no changes)**.

On apply: edit only the chosen simple findings. Keep the change tight to each finding — no unrelated refactors — and confirm each fix is actually correct.

### 6. Commit the fixes

One commit per finding, grouped only when a few fixes clearly belong together. For each commit, invoke the [git-commit](../git-commit/SKILL.md) skill (its confirmation gate applies). These commits land **after** the existing branch commits.

### 7. Offer a re-review

`AskUserQuestion`: **Re-review** (run another pass from step 2, to confirm the fixes are clean and catch anything new) / **Finish**.

### 8. Report

Summarize:

- Harness + model used.
- Counts: findings found / fixed / left for the reviewer.
- The fix commit SHAs.
- The list of complex/uncertain findings the human reviewer should still address.
