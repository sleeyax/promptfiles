---
name: git-commit
description: Write a commit message that matches the repo's existing style and create the commit. Use when the user asks to commit changes, wants a commit message proposal, or finishes a phase of work that needs a commit.
---

# Git Commit

Write a commit message for the current changes and commit it. The message MUST match the style already used in this repo — do NOT default to any particular format.

## Hard rules

- **Commit without asking.** Pick the single best message and create the commit — no options, no confirmation gate. The user amends or resets afterwards if the message is wrong, which is cheaper than a round trip on every commit.
- **Only commit what the change is about.** Never `git add -A` blindly. Stage the files that belong to the change, and leave anything unrelated, generated, or secret-looking alone — say what you skipped.
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

### 3. Write the message

Combine the diff with the conversation context — what task was being worked on, what the user's intent was, any relevant discussion. That context is what makes the message better than the diff alone would produce.

Write one message. It should **read like the existing commits from step 1 wrote it** — indistinguishable in style from the repo's history.

- Keep the first line under 70 characters
- Focus on *why*, not *what*
- For complex changes, include a body describing the *why* and any non-obvious context. For simple changes, a subject line alone is sufficient.
- In the body, do NOT insert hard line breaks mid-sentence. Either write the body as a single continuous paragraph (let the editor soft-wrap) or hard-wrap consistently at 72 characters. Never break lines arbitrarily.

### 4. Commit

Stage the relevant files if nothing is staged, then create the commit.

Report the subject line and anything you deliberately left unstaged. Two lines, not a summary of the change — the user just watched you make it.

## Stop instead of committing

Commit unless one of these is true, in which case report the situation and let the user decide:

- The working tree is mid-merge, mid-rebase, or otherwise in a conflicted state
- There is nothing to commit
- The changes are clearly two or more unrelated pieces of work, and staging one of them requires guessing which the user meant

## Delegating steps 1–3

If the harness provides a subagent tool (e.g. Claude Code's `Agent`), prefer running steps 1–3 in a subagent: it reads the log and the diff in its own context and returns only the message, so the diff never lands in the conversation.

The subagent has no conversation history, so hand it a 2–3 sentence summary of what was actually done and why — otherwise it regresses to describing the diff. Ask it to return the message and nothing else. A subagent never commits; step 4 stays with you.
