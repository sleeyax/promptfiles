---
name: refine-issue
description: Refine a GitHub or GitLab issue into an agent-ready brief — fetch it, ground it in the codebase, interview the user about the gaps, then comment on or update the issue. Use when an issue is too thin to implement.
---

# Refine Issue

Issue: $ARGUMENTS

Turn a thin issue into a spec an agent can implement from. Example invocations: `/refine-issue #12`, `/refine-issue 12`, `/refine-issue <issue-url>`.

## Hard rules

- Read-only against the code: no source edits, no commits, no test runs, no repro commands. The only writes are the comment or issue update the user picks at step 6, and — where domain modeling is set up — the glossary and ADR files described in step 3.
- Never post to, edit, or close anything on the tracker without an explicit confirm at step 6. Never close an issue at all.
- Every gate is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer.
- Don't invent requirements. Anything you can't answer from the issue, its comments, or the codebase is a question for the user, not a guess.

## Workflow

### 1. Resolve the issue

Parse `$ARGUMENTS`:

- Bare number (strip a leading `#`) → that issue in the current repo.
- Full URL → parse host, project path, and number from it.
- Empty → ask the user for an issue number or URL before proceeding.

Determine the provider from `git remote -v`:

- Contains `github.com` → **GitHub**
- Contains `gitlab.com` or a self-hosted GitLab host → **GitLab**
- Otherwise ask the user which provider to use.

Extract the `owner/repo` (GitHub) or `group/project` (GitLab) path too — you'll need it to fetch.

Print the resolved issue (number, title, URL) before doing anything else, so the user can catch a wrong target early. If the issue is closed, ask whether to continue before going further.

### 2. Fetch it

Prefer the matching MCP server if one is available in the current session; otherwise use the CLI:

- **GitHub**: `gh issue view <number> --json title,body,labels,state,comments,url`
- **GitLab**: `glab issue view <number> --comments`

If neither MCP nor CLI is available, stop and tell the user what to install.

Read the whole thread — body, comments, labels. If the issue references other issues, PRs, or MRs that are load-bearing for the work, fetch those too.

If a prior `## Agent Brief` comment exists, this is a re-run: read it and continue from there. Don't re-ask questions it already settled.

### 3. Ground it in the codebase

Explore read-only, to make the brief concrete:

- Locate the code the issue is actually about. Note the real types, function signatures, and config shapes involved — the brief names these, not file paths.
- Check whether it's **already implemented**. Search by domain concept, not just the issue's wording. If it already exists, say where and ask whether to continue.
- If `CONTEXT.md` or `CONTEXT-MAP.md` exists at the repository root, domain modeling is set up for this repo: read the glossary and use the `domain-modeling` skill from here on, if it is available, so the brief speaks the project's language. Terms sharpened while refining get written back to `CONTEXT.md` as they resolve — that's the one place this skill touches the working tree, and step 7 reports it.

### 4. Report the gaps

Before asking anything, print:

- A short grounding summary: what the issue asks for, where it lands in the code, and whether it looks already implemented.
- A numbered list of what's missing for an agent to implement it — unclear desired behavior, missing acceptance criteria, undefined edge cases, ambiguous scope, unstated non-goals.

### 5. Interview

Invoke the [refine](../refine/SKILL.md) skill to close the gaps from step 4, one question at a time. Keep the interview scoped to those gaps — this is about specifying the issue, not redesigning the project.

Where domain modeling is set up, `refine` runs `domain-modeling` for you: terms get challenged against the glossary and recorded as they resolve.

Skip this step only when step 4 found no gaps.

### 6. Write the brief

Invoke the [agent-brief](../agent-brief/SKILL.md) skill to render the brief, with the issue thread plus everything the interview settled as its source. Gaps are **blocking** here — step 5 closed them — so anything still open means the interview isn't finished. **Agent's discretion** is for detail the user deliberately chose to leave to the implementer.

Show the brief in full in chat. Then ask how to record it:

- **Comment on the issue** (Recommended) — post the brief as a new comment. The issue body is untouched.
- **Replace the body, keep the original** — the issue body becomes the brief, with the original text preserved verbatim in a collapsed block at the bottom:

  ```markdown
  <details>
  <summary>Original report</summary>

  ...original body, unchanged...

  </details>
  ```

- **Replace the body outright** — the brief fully replaces the body. This discards the reporter's original wording; say so before doing it.
- **Do nothing** — print only. Nothing touches the tracker.

Write via the MCP server if available, otherwise:

- **GitHub**: `gh issue comment <number> --body-file <file>` / `gh issue edit <number> --body-file <file>`
- **GitLab**: `glab issue note <number> --message <text>` / `glab issue update <number> --description <text>`

### 7. Report

Summarize:

- Issue title + URL.
- What was written and where (comment / body), or that nothing was posted.
- Any glossary or ADR files touched, and that they're uncommitted — this skill never commits.
- Anything left unresolved — questions the user deferred, decisions that still need a human.
- That `/implement <number>` can pick it up from here.

## The agent brief

The brief is the contract the implementing agent works from. The original body and discussion are context; the brief is what gets built. Its template and principles live in the [agent-brief](../agent-brief/SKILL.md) skill.
