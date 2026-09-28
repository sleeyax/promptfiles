---
name: guide-review
description: Walk me through a GitHub PR or GitLab MR as a guide — the change split into chapters in reasoning order — so I judge the approach instead of reading every line, then post my review.
disable-model-invocation: true
---

# Guide Review

PR/MR (optional): $ARGUMENTS

Turn a pull request or merge request into a **guide**: the change regrouped into chapters that follow the order the work was reasoned through — the core first, then its consequences, glue last — each explaining why it exists and what it affects. The reviewer reads the guide to judge the approach and whether it fits the problem; line-level bug-hunting is not this skill's job. After the guide, the reviewer asks questions and raises concerns, and the skill posts the concerns as one review on their say-so.

Example invocations: `/guide-review`, `/guide-review 42`, `/guide-review <pr-or-mr-url>`.

## Harness

This runs in Claude Code and in Codex; your system prompt says which. Ask with `AskUserQuestion` where it's available; otherwise ask in plain text with the same numbered options and stop until the user replies.

## Hard rules

- Every write to the PR/MR happens in step 7, behind its one confirm. Until then the skill only reads.
- The only change the skill makes to the local checkout is the fast-forward in step 3. When that can't land cleanly, the guide switches to remote links and local work stays exactly as it was.
- Read the diff in pieces: the file list and stat first, then the per-file diffs a chapter needs. Lockfiles, generated and vendored files are classified by path and never read in full.
- **Every changed file lands in exactly one chapter.** That coverage is what lets the reviewer trust the guide in place of the diff.

## Workflow

### 1. Resolve the target

Determine the provider: from the URL when `$ARGUMENTS` is one, otherwise from `git remote -v` (`github.com` → GitHub; `gitlab.com` or a self-hosted GitLab → GitLab; anything else → ask).

- URL → parse host, project path, and number.
- Bare number (strip a leading `#` or `!`) → that PR/MR in the current repo.
- Empty → the open PR/MR whose source branch is the current branch: `gh pr view` / `glab mr view`. None found, or on the default branch → stop and ask for a URL or number. Several → list them and ask.

Print number, title, URL, and state before going further.

Two conditions shape step 7, so settle them now:

- **Closed or merged** → the guide still runs, but nothing gets posted; say so up front.
- **Own PR/MR** — the author matches `gh api user --jq .login` / `glab api user` → approving and requesting changes are unavailable; comments still post.

### 2. Gather the inputs

- **GitHub**: `gh pr view <n> --json number,title,url,state,author,body,baseRefOid,headRefName,headRefOid,headRepository,headRepositoryOwner,additions,deletions,changedFiles,files,commits,closingIssuesReferences`. A single file's patch: `gh api repos/<owner>/<repo>/pulls/<n>/files --paginate --jq '.[] | select(.filename == "<path>") | .patch'`.
- **GitLab**: `glab mr view <iid> -F json` (keep `diff_refs`, `sha`, `source_branch`, `description`, `web_url`), the file list from `glab api "projects/<urlencoded-path>/merge_requests/<iid>/diffs" --paginate` filtered with `--jq` to paths and flags, a single file's diff from the same endpoint filtered to that path, and commits from `.../merge_requests/<iid>/commits`.
- **Linked issues**: GitHub `closingIssuesReferences`, GitLab `glab mr issues <iid>`, plus issue references in the description. Read each with `gh issue view` / `glab issue view`. An issue on another tracker (Linear, Jira, …) gets read through an MCP server or CLI if the session has one; otherwise the header lists its link as unread.

Existing review threads stay out of the inputs: the guide explains the change, not other reviewers' opinions of it.

### 3. Pick local or remote mode

**Local mode** holds when the current repo is the PR's repo, the current branch is the PR's source branch, and `HEAD` equals the PR's head SHA. In local mode, read files from disk, take per-file diffs with `git diff <base-sha>...HEAD -- <path>` (fetch the base if it's missing), and link as `path:line`.

On the source branch with `HEAD` behind the head SHA, bring it level first: `git fetch`, then `git merge --ff-only @{u}`, and say in one line that the branch was fast-forwarded. Recheck `HEAD` against the head SHA afterwards.

Anything else is **remote mode**: read through the API and link into the PR/MR's web diff. When the fast-forward failed or local mode almost held, state the reason in one line — e.g. "local branch has 2 commits the PR doesn't", "uncommitted changes block the fast-forward".

Remote links:

- **GitHub**: `<pr-url>/files#diff-<sha256 of the path>R<line>` — hash with `printf %s "<path>" | sha256sum`.
- **GitLab**: `<mr-url>/diffs#<sha1 of the path>` — hash with `printf %s "<path>" | sha1sum` — followed by the line number in text.

### 4. Build the guide

1. **Intent.** From the description, commits, and linked issues, state what the change is for.
2. **Supporting changes.** From paths and the stat, set aside lockfiles, generated and vendored files, pure renames, and formatting-only churn. They go to the final section with a one-line explanation per group.
3. **Chapters.** Read the diffs of the remaining files and group them by concern. Order the chapters the way the work was reasoned through: the core change a reader needs first, then what follows from it — callers adapting, data flowing through, surfaces exposing it, tests proving it. Chapter count follows the change: a PR that does one thing is one chapter, and the guide says so.
4. **Mismatches.** Compare the diff against the description in both directions: what the diff does that the description never mentions, and what the description claims that the diff doesn't visibly do. An empty description gets one line saying there is nothing to compare against.
5. **Risk flags.** Check the diff against the [risk categories](#risk-categories) and flag only what it actually touches.

Done when every changed file sits in exactly one chapter or the supporting section, and every mismatch and risk flag names the chapter it lives in.

### 5. Print the guide

Print it in one message, in this shape. Mismatches and risk flags come before the chapters because they change how the chapters read; drop either section when it's empty.

```markdown
# <title> (#<n>)

<author> · <files> files · +<additions> −<deletions> · <linked issues, or "no linked issue">
<one line on local/remote mode and why, when not local>

## Overview

<2–4 sentences: what the change does and why, from the issue and description>

## Mismatches

- <what differs> — ch. <n>

## Risk flags

- **<category>**: <what the diff does> — ch. <n>

## 1. <chapter title>

<why this part exists and what it affects, 2–5 sentences>

- <link> — <what changes in this file, a few words>

<excerpt of ≤15 lines, only where the code itself carries the point>

**Judge:** <1–2 questions about the approach, not the lines — e.g. "Is a per-request cache the right scope, or should this live on the client?">

## Supporting changes

- <group>: <one line> — <files>
```

### 6. Discuss

Invite the reviewer to ask about any chapter or raise concerns, then sort each reply:

- A **question** gets an answer, reading more code where it takes it. Questions don't become comments.
- A **concern** becomes a pending comment in the reviewer's words. Anchor it inline when it maps to a line inside the diff — both platforms reject inline comments on lines outside it; otherwise it goes in the review body. Echo each captured comment in one line with its anchor, so a wrong anchor is caught immediately.

Keep going until the reviewer says they're done. For a closed or merged PR/MR, stop here and report.

### 7. Finish the review

Show the batch — the review body and each inline comment with its anchor — then ask how to finish:

- **Approve**
- **Request changes**
- **Comment only** — post the comments, no verdict
- **Discard** — post nothing

On the reviewer's own PR/MR, offer only **Comment only** and **Discard**. The reviewer can edit or drop entries through a free-form answer before choosing.

Post as one review:

- **GitHub**: a single `gh api repos/<owner>/<repo>/pulls/<n>/reviews -X POST --input -` with `commit_id` set to the head SHA, `event` (`APPROVE`, `REQUEST_CHANGES`, or `COMMENT`), `body`, and `comments` as `{path, line, side, body}` — `side: "RIGHT"` for added or context lines, `"LEFT"` with the old line number for deleted ones.
- **GitLab**: each inline comment as a draft note on `projects/<id>/merge_requests/<iid>/draft_notes` with a `position` built from `diff_refs` (`position_type: "text"`, `base_sha`, `start_sha`, `head_sha`, `old_path`, `new_path`, and `new_line` or `old_line`); the review body as a draft note without a position; then `.../draft_notes/bulk_publish`. **Approve** adds `glab mr approve <iid>`. **Request changes** publishes the comments and withholds approval, since GitLab has no request-changes verdict to post — say so.

If a post fails partway, report exactly what landed and what didn't.

### 8. Report

One short summary: the PR/MR link, the verdict posted (or discarded, or read-only for closed/merged), and how many comments went inline and how many into the body.

## Risk categories

Flag a category only when the diff touches it, naming the specific change:

- **Migrations** — DB migrations or schema changes; name irreversible ones.
- **Auth** — authentication, permission, or session code.
- **Dependencies** — new or upgraded packages.
- **CI/deploy** — CI, build, or deployment configuration.
- **Secrets/config** — secrets or environment configuration.
- **Breaking API** — changes to a public API or contract others depend on.
- **Destructive data** — deletes, backfills, or other bulk data changes.
- **Concurrency** — locking, transactions, or concurrent-access behaviour.
