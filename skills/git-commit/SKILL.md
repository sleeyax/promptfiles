---
name: git-commit
description: Suggest a commit message that matches the repo's existing style and commit after explicit user confirmation. Use when the user asks to commit changes, wants a commit message proposal, or finishes a phase of work that needs a commit.
---

# Git Commit

Suggest a commit message for the current changes and commit it after user confirmation. The message MUST match the style already used in this repo — do NOT default to any particular format.

**Hard requirement: never commit without an explicit user choice via `AskUserQuestion`.** This applies even when this workflow is invoked as the final phase of a parent workflow (e.g. `/git-issue`) — a parent workflow that "ends with a commit phase" is authorization to *propose* a commit, not to run `git commit` on the user's behalf.

## Steps

1. Run `git log --oneline -20` to determine the repo's commit message style. Study the output carefully and identify:
   - Whether messages use a prefix/type convention or are freeform
   - Capitalization (sentence case vs lowercase)
   - Tense and mood (imperative vs past tense)
   - Use of scopes, tags, or ticket references
   - Typical length and level of detail
2. Check for a commitlint config (e.g., `commitlint.config.*`, `.commitlintrc.*`, or a `commitlint` key in `package.json`). If found, its rules take precedence.
3. Run `git diff --cached` to see staged changes. If nothing is staged, run `git diff` for unstaged changes instead.
4. Consider the full conversation context — what task was being worked on, what the user's intent was, and any relevant discussion. Use this to write a more meaningful message than the diff alone would produce.
5. Produce up to 3 commit messages, ordered from best to worst. If only one message is appropriate, suggest just one. Each message should **read like the existing commits from step 1 wrote it** — indistinguishable in style from the repo's history.
   - Keep the first line under 70 characters
   - Focus on *why*, not *what*
   - For complex changes, include a body describing the *why* and any non-obvious context. For simple changes, a subject line alone is sufficient.
   - In the body, do NOT insert hard line breaks mid-sentence. Either write the body as a single continuous paragraph (let the editor soft-wrap) or hard-wrap consistently at 72 characters. Never break lines arbitrarily.
6. Use the `AskUserQuestion` tool to confirm with the user which message (if any) they want to commit with.
7. If the user confirms, create the commit with the chosen message. If nothing is staged, stage the relevant files first. If the user declines, do not commit.
