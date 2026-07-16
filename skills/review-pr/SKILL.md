---
name: review-pr
description: Review a GitHub pull request like a senior engineer and post findings as a pending (draft) review. Use when the user supplies a GitHub PR URL and asks to review it. GitLab not supported.
---

# Review a Pull Request

PR: $ARGUMENTS

Review a GitHub PR like a senior engineer on the team and post findings as a **pending** review so the user submits/discards manually.

## Hard rules

- Never `submit` the review — leave it pending for the user.
- Never push, commit, or modify the cwd repo's working tree without explicit `AskUserQuestion` confirm.
- Every finding cites a real `+` (added) line in the actual diff. Removed-line comments are out of scope.
- Posting is gated by exactly one explicit `AskUserQuestion` confirm covering the whole batch.
- The agent writes **exactly one** `findings.json` per run (matching `findings.schema.json`) and invokes `post-pending-review.sh` **exactly once**. No per-finding shell calls.
- GitHub MCP server first if available; fall back to `gh`. If neither, stop.
- **Never dump the full diff to a file or to chat, or hand it to a subagent as one blob.** When the cwd repo matches the PR, read the diff incrementally from `git` (per-file, on demand) — not from a bulk API call. The `/pulls/<n>/files` endpoint is only used when there is no local checkout, and even then read it page-by-page, one file at a time, never as one bulk write. To measure size up front, use `/pulls/<n>/files` (metadata + per-file stats: `additions`/`deletions`/`changes`), reading only the counts, not each file's `patch`. This rule still holds when the user picks **Review whole diff anyway** — that answer authorizes the *scope*, not bulk-dumping.

## Workflow

### 1. Parse the URL

Require a full GitHub PR URL in `$ARGUMENTS`. Extract:
- `host` (e.g. `github.com`, or a GitHub Enterprise host like `github.example.com`)
- `owner` and `repo` (the `<owner>/<repo>` slug before `/pull/`)
- `pr_number` (integer after `/pull/`)

If missing or malformed, stop and ask the user for a URL.

### 2. Detect tooling

- Prefer the GitHub MCP server's tools if present in the session.
- Else require `gh` on PATH (`command -v gh`). Verify auth for the PR's host: `gh auth status --hostname <host>`.
- If neither is available, stop and tell the user to install `gh` from <https://cli.github.com>.

### 3. Fetch PR metadata only

Get **only** title, body, `state`, `merged`, base/head refs (`base.sha`, `head.sha` — `head.sha` is the `commit_id` used to anchor comments), and the **changed-files list with stats** (paths + per-file additions/deletions/changes). **Do not fetch full diff text yet.**

- MCP: corresponding tools (metadata only).
- CLI:
  - `gh api "repos/<owner>/<repo>/pulls/<pr_number>"` — metadata + `base.sha`/`head.sha`.
  - `gh api "repos/<owner>/<repo>/pulls/<pr_number>/files" --paginate` — file list + stats. Parse paths and counts; **do not save the response to a file** and **do not read each file's `patch` yet**.

**Bail early** with a clear message if:
- `state` is `closed` or `merged` is `true`
- `head.sha` is missing or null

### 4. Local checkout (preferred)

If `git remote -v` in cwd matches the PR's repo, check out **before** reading any diff content:

1. `git status --porcelain` clean check. If dirty, `AskUserQuestion`: **Stash** (`git stash push -u -m "review: pre-checkout"`) / **Abort**.
2. `git fetch origin`
3. `gh pr checkout <pr_number>` to land on the PR's head branch.

From this point, the diff source is **`git`, not the API**:
- Per-file diff: `git diff <base.sha>...<head.sha> -- <path>` on demand, one path at a time.
- File contents at HEAD: read the file directly from the working tree.

If cwd is unrelated to the repo, review from the API diff alone — fetch the per-file `patch` one file at a time (e.g. page through `gh api "repos/<owner>/<repo>/pulls/<pr_number>/files?per_page=1&page=N"`), never bulk. Note the diff-only limitation in the summary.

### 5. Diff-size guardrail

Using only the file list + stats from step 3 (no full diff text needed), if the changeset exceeds **800 changed lines** *or* **30 changed files**, `AskUserQuestion`:
- **Pick files** (Recommended) — user supplies a subset of paths to review
- **Review whole diff anyway**
- **Cancel**

The chosen subset is the only set of paths the agent will pull diffs for in step 6.

### 6. Perform the review

Senior-engineer mindset. Walk the file list (or the user-picked subset) **one path at a time**:

- For each path, pull its diff on demand (`git diff <base.sha>...<head.sha> -- <path>` if checked out, else one paginated API call) and read the file from the working tree to confirm context.
- Read-only inspection. No commands, no installs, no writes.
- **Never write the diff or any file's full contents to disk.** Hold what you need in working memory; move on once a file is reviewed.
- Nits, style suggestions, naming, and small refactors are allowed; flag at the appropriate severity.
- Each finding cites a concrete `+` line — or contiguous `+` line range — on the new side of the diff (`side: RIGHT`).
- GitHub suggestion fence is a plain ` ```suggestion ` block; the replaced span comes from the comment's own anchor: a single-line comment (`line` only) replaces that one line, and a multi-line comment (`startLine`..`line`, both `side: RIGHT`) replaces that whole range. This is the concrete fence the shared `COMMENT_TEMPLATE.md` defers to.
- Severity tiers (metadata only — never mentioned in the body): `blocker`, `concern`, `suggestion`, `nit`.

### 7. Build the in-memory findings list

For each finding, fill the `body` field by rendering `COMMENT_TEMPLATE.md` (inline) or `SUMMARY_TEMPLATE.md` (summary) — both symlinked in from `../_internal/`. Substitute the templates' `<skill-url>` footer placeholder with `https://github.com/sleeyax/promptfiles/blob/main/skills/review-pr/SKILL.md`. Hold the working set as an in-memory list of objects shaped like the schema in `findings.schema.json`:

```
{ severity, path, line, side, startLine?, startSide?, title, body }   // per inline finding
{ body }                                                              // summary (optional)
```

`title` is for the pre-submission UI only — it doesn't get posted (it's already inside `body`). `severity` is metadata for sorting; not posted. `side`/`startSide` default to `RIGHT`; set `startLine`/`startSide` only for a multi-line comment.

### 8. Pre-submission review loop

1. Print numbered list to chat:
   - `[N] <severity> · <path>:<line> · <title>` + 1-line body preview
   - Summary as `[S]`
2. `AskUserQuestion`: **Post all** / **Drop some** / **Edit some** / **Cancel**.
3. **Drop some** → ask which numbers, remove them, loop back to step 1.
4. **Edit some** → ask which single number, then free-form chat about *that* comment. Editable: `title`, `body`, `path`, `line`. After each round, `AskUserQuestion`: **Done** / **Keep editing** / **Discard this comment**. Only **Done** locks in changes; only then loop back to step 1.
5. **Post all** → step 9.
6. **Cancel** → drop everything, exit without posting.

### 9. Post (single atomic call)

1. Serialize the in-memory list to a `findings.json` file at `mktemp -t review-pr-findings-XXXXXX.json`. Top-level shape:

   ```json
   {
     "commitId": "<head.sha>",
     "summary":  { "body": "..." },
     "findings": [ { "severity": "...", "path": "...", "line": N, "side": "RIGHT", "startLine": M, "startSide": "RIGHT", "title": "...", "body": "..." } ]
   }
   ```

   Drop the `title` from the JSON if it adds noise — it's optional, as are `startLine`/`startSide` (single-line comments omit them). Schema lives next to this file at `findings.schema.json`; consult it for the authoritative shape.

2. Invoke the helper exactly once:

   ```
   ./post-pending-review.sh --repo <owner>/<repo> --pr <pr_number> --findings <tmp.json>
   ```

   The helper script lives next to this file. It validates the JSON against `findings.schema.json`, bails if the user already has a pending review on the PR, then posts the whole batch (summary as the review `body` + every inline comment) as **one** pending review via a single API call — so there is no partial state to roll back. On success it prints one line of JSON: `{"posted":N,"reviewId":<id>}` to stdout. On failure it forwards the error to stderr and exits non-zero.

3. **On success**, delete the findings file. **On failure**, leave it in place and tell the user the path so they can inspect or retry.

### 10. Report

Print:
- PR title + URL
- `<pr_url>/files` direct link (where the pending review's comments show)
- `posted` count from the helper's success JSON
- Reminder: the review is a **pending, unsubmitted** review. The user submits (Approve / Comment / Request changes) or discards it via the GitHub UI or `gh`.

Then stop.
