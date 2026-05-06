---
name: review-mr
description: Review a GitLab merge request like a senior engineer and post findings as a draft review. Use when the user supplies a GitLab MR URL and asks to review it. GitHub not supported.
---

# Review a Merge Request

MR: $ARGUMENTS

Review a GitLab MR like a senior engineer on the team and post findings as **draft** notes so the user publishes/discards manually.

## Hard rules

- Never `publish` draft notes — leave them for the user.
- Never push, commit, or modify the cwd repo's working tree without explicit `AskUserQuestion` confirm.
- Every finding cites a real `+` (added) line in the actual diff. Removed-line comments are out of scope.
- Posting is gated by exactly one explicit `AskUserQuestion` confirm covering the whole batch.
- The agent writes **exactly one** `findings.json` per run (matching `findings.schema.json`) and invokes `post-draft-note.sh` **exactly once**. No per-finding shell calls. Rollback on partial failure is the helper's job.
- GitLab MCP server first if available; fall back to `glab`. If neither, stop.
- **Never dump the full diff to a file or to chat, or hand it to a subagent as one blob.** When the cwd repo matches the MR, read the diff incrementally from `git` (per-file, on demand) — not from `glab api .../diffs`. The API `diffs` endpoint is only used when there is no local checkout, and even then read it page-by-page, one file at a time, never as one bulk write. To measure size up front, use `/merge_requests/<iid>/changes` (metadata + per-file stats), not `/diffs`. This rule still holds when the user picks **Review whole diff anyway** — that answer authorizes the *scope*, not bulk-dumping.

## Workflow

### 1. Parse the URL

Require a full GitLab MR URL in `$ARGUMENTS`. Extract:
- `host` (e.g. `gitlab.com`, `gitlab.example.com`)
- `project_path` (`group/subgroup/project`)
- `mr_iid` (integer after `/merge_requests/`)

If missing or malformed, stop and ask the user for a URL.

### 2. Detect tooling

- Prefer the GitLab MCP server's tools if present in the session.
- Else require `glab` on PATH (`command -v glab`). Verify auth for the MR's host: `glab auth status --hostname <host>`.
- If neither is available, stop and tell the user to install `glab` from <https://gitlab.com/gitlab-org/cli>.

### 3. Resolve numeric project ID

Some GitLab versions reject URL-encoded paths on `/draft_notes`. Resolve once:

```
glab api "projects/<urlencoded-path>"
```

Capture `.id` and use that numeric `project_id` for every later call.

### 4. Fetch MR metadata only

Get **only** title, description, source/target branch, `state`, `diff_refs` (`base_sha`, `start_sha`, `head_sha`), and the **changed-files list with stats** (paths + per-file additions/deletions). **Do not fetch full diff text yet.**

- MCP: corresponding tools (metadata only).
- CLI:
  - `glab api "projects/<id>/merge_requests/<iid>"` — metadata + `diff_refs`
  - `glab api "projects/<id>/merge_requests/<iid>/changes" --paginate` — file list + stats. Parse paths and counts; **do not save the response to a file**.

**Bail early** with a clear message if:
- `state` is `closed` or `merged`
- `diff_refs` is missing or null

### 5. Local checkout (preferred)

If `git remote -v` in cwd matches the MR's project, check out **before** reading any diff content:

1. `git status --porcelain` clean check. If dirty, `AskUserQuestion`: **Stash** (`git stash push -u -m "review: pre-checkout"`) / **Abort**.
2. `git fetch origin`
3. `glab mr checkout <iid>` to land on the MR's source branch.

From this point, the diff source is **`git`, not the API**:
- Per-file diff: `git diff <base_sha>...<head_sha> -- <path>` on demand, one path at a time.
- File contents at HEAD: read the file directly from the working tree.

If cwd is unrelated to the project, review from the API diff alone — fetch one file at a time via `glab api "projects/<id>/merge_requests/<iid>/diffs?page=N&per_page=1"`, never bulk. Note the diff-only limitation in the summary.

### 6. Diff-size guardrail

Using only the file list + stats from step 4 (no full diff text needed), if the changeset exceeds **800 changed lines** *or* **30 changed files**, `AskUserQuestion`:
- **Pick files** (Recommended) — user supplies a subset of paths to review
- **Review whole diff anyway**
- **Cancel**

The chosen subset is the only set of paths the agent will pull diffs for in step 7.

### 7. Perform the review

Senior-engineer mindset. Walk the file list (or the user-picked subset) **one path at a time**:

- For each path, pull its diff on demand (`git diff <base_sha>...<head_sha> -- <path>` if checked out, else one paginated API call) and read the file from the working tree to confirm context.
- Read-only inspection. No commands, no installs, no writes.
- **Never write the diff or any file's full contents to disk.** Hold what you need in working memory; move on once a file is reviewed.
- Nits, style suggestions, naming, and small refactors are allowed; flag at the appropriate severity.
- Each finding cites a concrete `+` line — or contiguous `+` line range — in the new file.
- Multi-line ranges use the `-N+M` span on the `suggestion` block (`N` lines before anchor, `M` after; `-0+0` = anchor only).
- Severity tiers (metadata only — never mentioned in the body): `blocker`, `concern`, `suggestion`, `nit`.

### 8. Build the in-memory findings list

For each finding, fill the `body` field by rendering `COMMENT_TEMPLATE.md` (inline) or `SUMMARY_TEMPLATE.md` (summary). Hold the working set as an in-memory list of objects shaped like the schema in `findings.schema.json`:

```
{ severity, path, oldPath, line, title, body }   // per inline finding
{ body }                                          // summary (optional)
```

`title` is for the pre-submission UI only — it doesn't get posted (it's already inside `body`). `severity` is metadata for sorting; not posted.

### 9. Pre-submission review loop

1. Print numbered list to chat:
   - `[N] <severity> · <path>:<line> · <title>` + 1-line body preview
   - Summary as `[S]`
2. `AskUserQuestion`: **Post all** / **Drop some** / **Edit some** / **Cancel**.
3. **Drop some** → ask which numbers, remove them, loop back to step 1.
4. **Edit some** → ask which single number, then free-form chat about *that* comment. Editable: `title`, `body`, `path`, `line`. After each round, `AskUserQuestion`: **Done** / **Keep editing** / **Discard this comment**. Only **Done** locks in changes; only then loop back to step 1.
5. **Post all** → step 10.
6. **Cancel** → drop everything, exit without posting.

### 10. Post (single batch)

1. Serialize the in-memory list to a `findings.json` file at `mktemp -t review-mr-findings-XXXXXX.json`. Top-level shape:

   ```json
   {
     "diffRefs": { "baseSha": "...", "startSha": "...", "headSha": "..." },
     "summary":  { "body": "..." },
     "findings": [ { "severity": "...", "path": "...", "oldPath": "...", "line": N, "title": "...", "body": "..." } ]
   }
   ```

   Drop the `title` from the JSON if it adds noise — it's optional. Schema lives next to this file at `findings.schema.json`; consult it for the authoritative shape.

2. Invoke the helper exactly once:

   ```
   ./post-draft-note.sh --project <id> --mr <iid> --findings <tmp.json>
   ```

   The helper script lives next to this file. It validates the JSON against `findings.schema.json`, idempotency-checks against existing drafts, posts the batch, and rolls back via `DELETE` on any HTTP failure. On success it prints one line of JSON: `{"posted":N,"skipped":M,"ids":[...]}` to stdout. On failure it forwards the error to stderr and exits non-zero.

3. **On success**, delete the findings file. **On failure**, leave it in place and tell the user the path so they can inspect or retry.

### 11. Report

Print:
- MR title + URL
- `<mr_url>#drafts` direct link
- `posted` / `skipped` counts from the helper's success JSON
- Reminder: review is **unpublished**. The user publishes or discards via the GitLab UI or `glab`.

Then stop.
