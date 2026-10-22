---
name: address-review
description: Fetch a GitHub PR's or GitLab MR's review comments and lay out a plan per comment — the fix, the reply, and whether to resolve — that the user accepts with "ok" or discusses comment by comment. Then commit one fix per comment, push, reply to every thread and resolve the settled ones. Defaults to the open PR/MR for the current branch. Use when the user wants to act on reviewer feedback left on a PR/MR.
---

# Address Review Comments

PR/MR (optional): $ARGUMENTS

Pull the review feedback left on a pull request or merge request, propose what to do about each comment, agree on it with the user, then land each fix as its own commit and close the loop on every thread.

`$ARGUMENTS` is **optional** — with no argument, the target is the open PR/MR for the current branch. Example invocations: `/address-review`, `/address-review 42`, `/address-review <mr-url>`.

## Hard rules

- **Nothing is edited, committed, pushed or posted until the plan (step 5) is agreed.** Show it, then wait. The plan is always plain text, since the user answers it per comment.
- The other stops — an unresolvable or closed target, a dirty tree — are real stops too: ask, then wait. Use the `AskUserQuestion` tool for those **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer. Committing is not a stop — the `git-commit` skill commits on its own.
- **One commit per comment.** Group only when several comments demand the same edit; say so in the report when you do.
- **Every thread gets a reply**, exactly as agreed in the plan. Push only right before posting, since replies cite SHAs the reviewer must be able to fetch, and never force-push.
- Don't blindly obey a comment. A reviewer can be wrong or working from stale context — recommend declining, with the reasoning, instead of implementing it.
- Don't dump the full diff into a prompt or a file. Read the files the comments point at.

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
  - No match → don't guess. Tell the user the branch has no open PR/MR and ask for a URL or number.
  - Several matches → ask, listing them (number + title) so the user picks.
  - On the default branch with no argument → stop and ask; there's nothing sensible to infer.
- `$ARGUMENTS` is a URL → parse host, project path, and number from it.
- `$ARGUMENTS` is a bare number (strip a leading `#`) → that PR/MR in the current repo.

Print the resolved PR/MR (number, title, URL) before doing anything else, so the user can catch a wrong target early.

Bail early if the PR/MR is `closed` or `merged`, unless the user confirms they still want to act on it.

### 2. Get on the right branch

1. `git status --porcelain`. If dirty, ask: **Stash** (`git stash push -u`, restore after) / **Proceed anyway** / **Abort** — per-comment commits need a clean tree.
2. If the checkout isn't already on the PR/MR's source branch, check it out: `gh pr checkout <number>` / `glab mr checkout <iid>`.
3. `git pull --ff-only` so you're not addressing feedback on a stale head.

### 3. Fetch the review comments

Prefer the provider's MCP server if one is available in the session; otherwise use the CLI:

- **GitHub**: inline review threads come from GraphQL, since the REST comments endpoint carries neither `isResolved` nor the thread `id` that replying and resolving need:

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

### 5. Plan

Decide one action per thread:

- **Address** — a concrete, valid change request. State the fix you'll make.
- **Already fixed** — a later commit already handles it. Name the commit.
- **Reply** — a question, or a request for justification, that needs words rather than code.
- **Decline** — the reviewer is mistaken, it's a matter of taste the code already settles, or it's follow-up work beyond this PR/MR. State the reasoning.

Recommend an action for every thread, even a close call. Flag it ⚠️ *low confidence* when the code, the PR/MR description and the repo's docs can't settle it: a comment with several plausible readings that lead to materially different changes, a product or behaviour decision, reviewers contradicting each other, or a fix that would reshape the PR/MR's scope.

Each thread also gets:

- **The reply** — the exact text that will be posted: what the fix does (**Address**, with a `<sha>` placeholder filled in after the commit), which commit covers it (**Already fixed**), the answer (**Reply**), or the reasoning (**Decline**).
- **A resolve marker** — 🔒 *resolve* when the reply settles the thread (a clear fix, an earlier commit, a factual answer); 💬 *leave open* when the reviewer will likely want the last word (a decline, an open-ended question, a judgement call).

Print the plan as numbered items, `c1`, `c2`, …, worded so that "ok" accepts each recommendation:

```
📝 **c1** - **<path>:<line>** · <author> (bot): <one-line summary of the ask>

➡️ **Address**: <the fix>
↩️ <reply text>
🔒 resolve

---

📝 **c2** - **general** · <author>: <one-line summary of the ask>

➡️ **Decline** ⚠️ *low confidence*: <the reasoning>
↩️ <reply text>
💬 leave open
```

Use **general** for review bodies and non-inline comments, and drop `(bot)` for human reviewers.

End with: reply `ok` to go with every recommendation, or discuss any comment by its number — e.g. `c3: rename it to fooBar instead`, `c5: why decline?`, `c2: resolve`.

### 6. Agree on the plan

- A plain `ok` → go to step 7.
- Anything else → each comment the user didn't mention is settled as recommended. For each one they did mention, answer the question or take the correction, then show a new round with only those items, keeping their numbers. Repeat until a round gets a plain `ok`.

### 7. Fix and commit, one comment at a time

For each **Address** thread, in order:

1. Make the edit. Keep it tight to what was agreed — no drive-by refactors.
2. Verify it's actually right (run the project's tests/linter for the touched area if that's cheap and the project has them).
3. Invoke the [git-commit](../../git/git-commit/SKILL.md) skill to commit just that fix. The message should describe the change, and may reference the reviewer's point.
4. Fill the commit SHA into the thread's reply.
5. Move to the next thread only once the current one is committed.

Never batch several unrelated comments into one commit.

If a fix can't be made as agreed once you're in the code, revert the edit and bring that comment back as a new round of the plan. Don't push until it's agreed again.

### 8. Push, reply and resolve

1. If step 7 made commits, `git push` (`--set-upstream origin <branch>` if it has no upstream). Never force-push; if the push is rejected as non-fast-forward, stop, report it, and post nothing — the user resolves the divergence.
2. Post every thread's agreed reply, then resolve the threads marked 🔒.

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

### 9. Report

Open with the PR/MR title + URL, counts per action, and how many commits were made and whether they were pushed.

Then one table row per thread, numbered as in the plan:

| # | Thread | Action | Commit | Reply | Replied | Resolved |
| --- | --- | --- | --- | --- | --- | --- |

- **Thread** — `path:line` (or "general"), linked to the thread.
- **Action** — mark the ones the user changed in step 6.
- **Commit** — the SHA that addresses it (**Address**, **Already fixed**); `—` otherwise.
- **Reply** — the posted text.
- **Replied** / **Resolved** — ✅; `—` where it doesn't apply (left open, or a general comment); or ❌ with the cause: skipped because the push was rejected, or the error `gh`/`glab` or the MCP server returned.

Close with whether a stash was restored.
