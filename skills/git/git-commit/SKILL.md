---
name: git-commit
description: Suggest a commit message that matches the repo's existing style and commit after explicit user confirmation. Use when the user asks to commit changes, wants a commit message proposal, or finishes a phase of work that needs a commit.
---

# Git Commit

Suggest a commit message for the current changes and commit it after user confirmation. The message MUST match the style already used in this repo — do NOT default to any particular format.

## Hard rules

- **Never commit without an explicit user choice.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. This applies even when this workflow is invoked as the final phase of a parent workflow (e.g. `/implement`) — a parent workflow that "ends with a commit phase" is authorization to *propose* a commit, not to run `git commit` on the user's behalf.
- **Keep the context small.** This skill almost always runs at the end of a long session, where every extra round trip and every line of diff is re-sent along with the whole conversation. Gather in one call, bound the diff, and never re-run a command whose output you already have.

## Steps

### 1. Gather the evidence — one call

Run all of it as a single command, not one tool call per fact:

```sh
git log --oneline -20
git status --short
git diff --cached --stat
ls -d commitlint.config.* .commitlintrc* 2>/dev/null
grep -l '"commitlint"' package.json 2>/dev/null
```

If the staged stat is empty, nothing is staged — the scope is the unstaged changes instead (`git diff --stat`), and every later `--cached` command below drops the flag to match.

From the log output, identify the repo's style:

- Whether messages use a prefix/type convention or are freeform
- Capitalization (sentence case vs lowercase)
- Tense and mood (imperative vs past tense)
- Use of scopes, tags, or ticket references
- Typical length and level of detail

If a commitlint config turned up, read it — its rules take precedence over what the log suggests.

### 2. Read the diff, bounded

The diff is the single largest thing this skill puts in context, and it stays there for every later call. Never pull in more of it than the message needs.

```sh
git diff --cached -- . ':(exclude)*.lock' ':(exclude)*-lock.json' ':(exclude)*.sum'
```

If the stat from step 1 shows a large change (roughly >500 changed lines or >20 files), skip the full diff entirely: work from the stat plus targeted `git diff --cached -- <path>` calls on the few files that actually carry the intent. Generated, vendored, and lockfile changes need a mention in the message at most — never a read.

### 3. Write the candidates

Combine the diff with the conversation context — what task was being worked on, what the user's intent was, any relevant discussion. That context is what makes the message better than the diff alone would produce.

Produce up to 3 commit messages, ordered from best to worst. If only one message is appropriate, suggest just one. Each message should **read like the existing commits from step 1 wrote it** — indistinguishable in style from the repo's history.

- Keep the first line under 70 characters
- Focus on *why*, not *what*
- For complex changes, include a body describing the *why* and any non-obvious context. For simple changes, a subject line alone is sufficient.
- In the body, do NOT insert hard line breaks mid-sentence. Either write the body as a single continuous paragraph (let the editor soft-wrap) or hard-wrap consistently at 72 characters. Never break lines arbitrarily.

### 4. Ask, then commit

Ask the user which message (if any) they want to commit with, and wait for the answer.

If the user confirms, create the commit with the chosen message. If nothing is staged, stage the relevant files first. If the user declines, do not commit.

## Delegating steps 1–3

If the harness provides a subagent tool (e.g. Claude Code's `Agent`), prefer running steps 1–3 in a subagent: it reads the log and the diff in its own context and returns only the candidate messages, so the diff never lands in the conversation that then has to survive the confirmation gate.

The subagent has no conversation history, so hand it a 2–3 sentence summary of what was actually done and why — otherwise it regresses to describing the diff. Ask it to return the candidates plus the style rules it inferred, and nothing else. The gate in step 4 stays with you: a subagent never commits.
