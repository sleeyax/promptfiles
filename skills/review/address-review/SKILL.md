---
name: address-review
description: Fetch a GitHub PR's or GitLab MR's review comments, triage them, address the relevant ones with one local commit per comment, then, once the user signs off on the report, push, reply to and resolve every thread. Defaults to the open PR/MR for the current branch. Use when the user wants to act on reviewer feedback left on a PR/MR.
---

# Address Review Comments

PR/MR (optional): $ARGUMENTS

Pull the review feedback left on a pull request or merge request, decide what actually needs changing, land each addressed comment as its own local commit, and once the user signs off, push and close the loop on every thread: a reply, then a resolve.

`$ARGUMENTS` is **optional** — with no argument, the target is the open PR/MR for the current branch. Example invocations: `/address-review`, `/address-review 42`, `/address-review <mr-url>`.

## Hard rules

- Run **autonomously** up to one **sign-off** (step 7). Your triage is the decision: fix what you judge should be fixed and decline what you judge shouldn't, all locally and without asking. Nothing leaves the machine until the user signs off on the report.
- Ask the user only for what you genuinely can't decide — the **Needs the user** bucket and the few blocking cases named in the workflow. Batch those questions into one ask, and ask before touching code so the run is unattended up to sign-off. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with numbered options and stop until the user replies.
- **One commit per comment.** Group only when several comments demand the same edit; say so in the report when you do.
- Push with a plain `git push` only, and only after sign-off. On a rejected push, stop: report it and post nothing, since replies cite SHAs the reviewer can't fetch yet.
- Judge each comment on its merits. A reviewer can be wrong or working from stale context — decline those with a reasoned reply.
- Read the files the comments point at, not the full diff.

## Workflow

### 1. Resolve the target

Determine the provider from `git remote -v`:

- Contains `github.com` → **GitHub**
- Contains `gitlab.com` or a self-hosted GitLab host → **GitLab**
- Otherwise ask the user which provider to use.

Then resolve which PR/MR:

- **`$ARGUMENTS` is empty (the common case)** → detect the current branch with `git rev-parse --abbrev-ref HEAD` and look up the open PR/MR whose source branch is that branch:
  - **GitHub**: `gh pr view --json number,title,url,state` (resolves from the current branch), or `gh pr list --head <branch> --json number,title,url,state` if that fails.
  - **GitLab**: `glab mr view` , or `glab mr list --source-branch <branch>`.
  - No match → ask for a URL or number.
  - Several matches → ask, listing them (number + title) so the user picks.
  - On the default branch with no argument → ask; there's nothing sensible to infer.
- `$ARGUMENTS` is a URL → parse host, project path, and number from it.
- `$ARGUMENTS` is a bare number (strip a leading `#`) → that PR/MR in the current repo.

Print the resolved PR/MR (number, title, URL), then carry on.

If the PR/MR is `closed` or `merged`, ask whether to act on it anyway.

### 2. Get on the right branch

1. `git status --porcelain`. If dirty, `git stash push -u` and restore it with `git stash pop` at the end. If the pop conflicts, leave the stash in place and flag it in the report.
2. If the checkout isn't already on the PR/MR's source branch, check it out: `gh pr checkout <number>` / `glab mr checkout <iid>`.
3. `git pull --ff-only` so you're addressing feedback on the latest head.

### 3. Fetch the review comments

Prefer the provider's MCP server if one is available in the session; otherwise use the CLI:

- **GitHub**: inline review threads come from GraphQL, which carries the thread `id` and `isResolved` that replying and resolving need:

  ```bash
  gh api graphql -F owner=<owner> -F repo=<repo> -F n=<number> -f query='
    query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){
      reviewThreads(first:100){nodes{id isResolved isOutdated path line
        comments(first:50){nodes{author{login} body}}}}}}}'
  ```

  Add `gh pr view <number> --json reviews,comments` for review bodies and general discussion.
- **GitLab**: `glab api "projects/<urlencoded-path>/merge_requests/<iid>/discussions" --paginate` — each discussion has an `id` and `notes[]` with `position` (path + `new_line`), `resolved`, `system`, and `body`.

If neither MCP nor CLI is available, stop and tell the user what to install.

Normalize into one list of threads, each with: thread id, author, path + line (if inline), the comment body, any replies, and resolved state.

Filter out:
- system/activity notes (GitLab `system: true`, GitHub timeline events)
- threads already marked resolved
- threads whose last word is already your own reply

Keep bot comments (linters, CI, review bots) but mark them as such — they're often the easy wins.

If nothing is left after filtering, say so and stop.

### 4. Read the code behind each comment

For each thread, open the file at the cited line **in the current working tree** — not the diff hunk from the API. The comment may already be addressed by a later commit; the hunk won't tell you that.

### 5. Triage

Sort every thread into one bucket:

- **Address** — a concrete, valid change request.
- **Already fixed** — a later commit already handles it.
- **Reply only** — a question, or a request for justification, that needs words rather than code.
- **Decline** — the reviewer is mistaken, it's a matter of taste the code already settles, or it's follow-up work beyond this PR/MR. Write down the reasoning; it becomes the reply.
- **Needs the user** — reserved for what the code, the PR/MR description, and the repo's docs can't settle: a comment with several plausible readings that lead to materially different changes, a product or behaviour decision, reviewers contradicting each other, or a fix that would reshape the PR/MR's scope.

Print a numbered list: `[N] <bucket> · <author> · <path>:<line>` + a one-line summary of the ask, and the fix (**Address**) or reasoning (**Decline**) you'll go with.

If any thread is **Needs the user**, ask about all of them in one batch now, then re-bucket each by the answer. Otherwise go straight on.

### 6. Fix and commit, one comment at a time

Record `git rev-parse HEAD` as the **base**: everything after it is this run's local history, free to rewrite until step 8 pushes it.

For each **Address** thread, in order:

1. Make the edit, scoped to what the comment asks.
2. Verify it's actually right (run the project's tests/linter for the touched area if that's cheap and the project has them).
3. Invoke the [git-commit](../git-commit/SKILL.md) skill to commit just that fix. The message should describe the change, and may reference the reviewer's point.
4. Move to the next thread only once the current one is committed.

If a fix turns out wrong or infeasible once you're in the code, revert it and move the thread to **Decline** with the reason you found.

### 7. Sign-off

Show the [report](#report) without the **Replied** / **Resolved** columns, then ask: **Continue** (push, reply and resolve) / **Request changes**.

On **Request changes**, apply what the user asks and keep the history at one clean commit per comment:

- Rework a fix: commit with `git commit --fixup=<sha>`, then `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.
- Drop a fix (e.g. the thread moves to **Decline**): `git rebase --onto <sha>^ <sha>`.
- Change a bucket or an explanation: update the report.

Then show the report again and ask again, until the user picks **Continue**.

### 8. Push, reply and resolve

1. If step 6 made commits, `git push` (`--set-upstream origin <branch>` if it has no upstream).
2. Reply to every thread with its **Explanation** from the signed-off report, citing the commit SHA where there is one, then resolve it.

Post and resolve via the MCP server, or:

- **GitHub** review threads:

  ```bash
  gh api graphql -F id=<thread-id> -F body=<reply> -f query='
    mutation($id:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}){comment{url}}}'
  gh api graphql -F id=<thread-id> -f query='
    mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'
  ```

  Review bodies and general PR comments aren't threads: answer them in one `gh pr comment <number>` that quotes each point it responds to. There's nothing to resolve.
- **GitLab**: `glab api -X POST "projects/<path>/merge_requests/<iid>/discussions/<id>/notes" -f body=<reply>`, then `glab api -X PUT "projects/<path>/merge_requests/<iid>/discussions/<id>" -f resolved=true`.

Finish by showing the full report.

## Report

The report is the user's audit trail of every decision made on their behalf, so it covers every triaged thread, whatever its outcome.

Open with the PR/MR title + URL, counts per bucket, and how many commits were made and whether they were pushed.

Then one table row per thread, numbered as in triage:

| # | Thread | Bucket | Ask | Commit | Explanation | Replied | Resolved |
| --- | --- | --- | --- | --- | --- | --- | --- |

- **Thread** — `path:line` (or "general" for a non-inline comment), linked to the thread.
- **Bucket** — mark threads the user settled in step 5.
- **Commit** — the SHA that addresses it (**Address**, **Already fixed**); `—` otherwise.
- **Explanation** — the reply text: what changed and why (**Address**), how the earlier commit covers it (**Already fixed**), the answer (**Reply only**), or the reasoning (**Decline**).
- **Replied** / **Resolved** — ✅; `—` where it doesn't apply (general comments can't be resolved); or ❌ with the cause: skipped because the push was rejected, or the error message `gh`/`glab` or the MCP server returned.

Close with whether a stash was restored, or left in place after a conflicting pop.
