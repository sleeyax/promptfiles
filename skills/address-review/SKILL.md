---
name: address-review
description: Fetch a GitHub PR's or GitLab MR's review comments, triage them, and address the relevant ones with one commit per comment. Defaults to the open PR/MR for the current branch. Use when the user wants to act on reviewer feedback left on a PR/MR.
---

# Address Review Comments

PR/MR (optional): $ARGUMENTS

Pull the review feedback left on a pull request or merge request, decide what actually needs changing, and land each addressed comment as its own commit.

`$ARGUMENTS` is **optional** — with no argument, the target is the open PR/MR for the current branch. Example invocations: `/address-review`, `/address-review 42`, `/address-review <mr-url>`.

## Hard rules

- Every gate — target confirmation, dirty-tree, which comments to address, thread replies — is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer. Commits go through the `git-commit` skill's own gate.
- **One commit per comment.** Group only when several comments demand the same edit; say so in the report when you do.
- Never write back to GitHub/GitLab (pushes, replies, resolves) unless the user explicitly opts in at step 8. The default is local-only: commits stay on the machine and the user pushes manually.
- Pushing is coupled to replying. Push **only** as part of a step 8 reply option, and only before posting — never as a standalone step, and never force-push.
- Don't blindly obey a comment. A reviewer can be wrong or working from stale context — flag disagreements instead of implementing them.
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

- **GitHub**: `gh pr view <number> --json title,url,reviews,comments` for review bodies and general discussion, plus `gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate` for inline review comments (each carries `path`, `line`, `diff_hunk`, `in_reply_to_id`, `body`, `user.login`).
- **GitLab**: `glab api "projects/<urlencoded-path>/merge_requests/<iid>/discussions" --paginate` — each discussion has `notes[]` with `position` (path + `new_line`), `resolved`, `system`, and `body`.

If neither MCP nor CLI is available, stop and tell the user what to install.

Normalize into one list of threads, each with: author, path + line (if inline), the comment body, any replies, and resolved state.

Filter out:
- system/activity notes (GitLab `system: true`, GitHub timeline events)
- threads already marked resolved
- your own prior replies

Keep bot comments (linters, CI, review bots) but mark them as such — they're often the easy wins.

If nothing is left after filtering, say so and stop.

### 4. Read the code behind each comment

For each thread, open the file at the cited line **in the current working tree** — not the diff hunk from the API. The comment may already be addressed by a later commit; the hunk won't tell you that.

### 5. Triage

Sort every thread into one bucket:

- **Address** — a concrete, valid change request.
- **Already fixed** — a later commit already handles it; nothing to do but reply.
- **Reply only** — a question, or a request for justification, that needs words rather than code.
- **Disagree / out of scope** — the reviewer is mistaken, or it's a follow-up ticket rather than this PR/MR. Give a one-line reason.
- **Needs the user** — ambiguous or a judgement call you shouldn't make alone.

Print a numbered list: `[N] <bucket> · <author> · <path>:<line>` + a one-line summary of the ask, and — for **Address** — the fix you intend to make.

### 6. Confirm the scope

Ask: **Address all** / **Pick a subset** / **Cancel**.

Resolve every **Needs the user** thread here too, before touching code.

### 7. Fix and commit, one comment at a time

For each chosen thread, in order:

1. Make the edit. Keep it tight to what the comment asks — no drive-by refactors.
2. Verify it's actually right (run the project's tests/linter for the touched area if that's cheap and the project has them).
3. Invoke the [git-commit](../git-commit/SKILL.md) skill to commit just that fix. Its confirmation gate applies. The message should describe the change, and may reference the reviewer's point.
4. Move to the next thread only once the current one is committed.

Never batch several unrelated comments into one commit.

### 8. Offer to reply on the PR/MR

Default is local-only: the user replies and resolves manually.

Ask — "Post replies to the review threads?":

- **No, local only** (Recommended) — do nothing further on the platform, and don't push. The user pushes when ready.
- **Push and reply, leave threads open** — push the commits, then post one reply per handled thread noting what changed and the commit SHA.
- **Push, reply and resolve** — same, then resolve the threads that were addressed or were already fixed.

Either posting option implies pushing — a reply that cites a SHA the reviewer can't fetch is worse than no reply. So, in this order:

1. Push the branch: `git push` (`--set-upstream origin <branch>` if it has no upstream). Never force-push; if the push is rejected as non-fast-forward, stop, report it, and leave the replies unposted — the user resolves the divergence.
2. Show the exact reply text for each thread and confirm the batch.
3. Post, then resolve if that option was chosen. Only threads in the **Address** / **Already fixed** buckets get a reply — never auto-reply to a disagreement on the user's behalf. Post via the MCP server or `gh api ... /comments/<id>/replies` / `glab api ... /discussions/<id>/notes`.

### 9. Report

Summarize:

- PR/MR title + URL.
- Counts per bucket, and how many commits were made.
- Commit SHA per addressed comment.
- Threads left for the user: disagreements (with reasons), reply-only questions, anything skipped.
- Whether the branch was pushed and which threads got replies/resolves — or, for the local-only path, an explicit reminder that nothing was pushed or posted.
