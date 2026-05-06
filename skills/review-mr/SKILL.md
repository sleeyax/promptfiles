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
- On any partial failure during posting, run the helper's `--discard-mine` mode for the IDs already posted in this run, then surface the error.
- GitLab MCP server first if available; fall back to `glab`. If neither, stop.

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

### 4. Fetch MR context

Get title, description, source/target branch, `state`, `diff_refs` (`base_sha`, `start_sha`, `head_sha`), and per-file diffs.

- MCP: corresponding tools.
- CLI:
  - `glab api "projects/<id>/merge_requests/<iid>"`
  - `glab api "projects/<id>/merge_requests/<iid>/diffs"`

**Bail early** with a clear message if:
- `state` is `closed` or `merged`
- `diff_refs` is missing or null

### 5. Diff-size guardrail

If the diff exceeds **800 changed lines** *or* **30 changed files**, `AskUserQuestion`:
- **Pick files** (Recommended) — user supplies a subset of paths to review
- **Review whole diff anyway**
- **Cancel**

### 6. Local checkout (best-effort)

If `git remote -v` in cwd matches the MR's project:

1. `git status --porcelain` clean check. If dirty, `AskUserQuestion`: **Stash** (`git stash push -u -m "review: pre-checkout"`) / **Abort**.
2. `git fetch origin`
3. `glab mr checkout <iid>` to land on the MR's source branch.
4. Read files from this checkout while reviewing.

If cwd is unrelated to the project, review from the diff alone and note the limitation in the summary.

### 7. Perform the review

Senior-engineer mindset:

- Read-only inspection. No commands, no installs, no writes.
- Nits, style suggestions, naming, and small refactors are allowed; flag at the appropriate severity.
- Each finding cites a concrete `+` line — or contiguous `+` line range — in the new file.
- Multi-line ranges use the `-N+M` span on the `suggestion` block (`N` lines before anchor, `M` after; `-0+0` = anchor only).
- Severity tiers (metadata only — never mentioned in the body): `blocker`, `concern`, `suggestion`, `nit`.

### 8. Format findings

Fill `COMMENT_TEMPLATE.md` per inline finding and `SUMMARY_TEMPLATE.md` for the summary. Hold all findings in an in-memory list of objects:

```
{ id, severity, path, line, lineSpan, title, body, suggestion }
```

Summary is a separate object with no `path`/`line`.

### 9. Pre-submission review loop

1. Print numbered list to chat:
   - `[N] <severity> · <path>:<line(-range)> · <title>` + 1-line body preview
   - Summary as `[S]`
2. `AskUserQuestion`: **Post all** / **Drop some** / **Edit some** / **Cancel**.
3. **Drop some** → ask which numbers, remove them, loop back to step 1.
4. **Edit some** → ask which single number, then enter free-form chat about *that* comment. Editable: `title`, `body`, `suggestion`, `path`, `line`, `lineSpan`. After each round, `AskUserQuestion`: **Done** / **Keep editing** / **Discard this comment**. Only **Done** locks in changes; only then loop back to step 1.
5. **Post all** → step 10.
6. **Cancel** → drop everything, exit without posting.

### 10. Post (single batch)

1. **Idempotency check.** `glab api "projects/<id>/merge_requests/<iid>/draft_notes"` to list existing drafts. Skip any new finding whose `(path, line, title)` already matches an existing bot-authored draft. Tell the user how many were skipped.
2. For each remaining inline finding:
   - Write its body to `mktemp -t review-draft-XXXXXX.md`.
   - Call `./post-draft-note.sh --project <id> --mr <iid> --body-file <tmp> --path <new_path> --old-path <old_path> --line <new_line> --base-sha <base> --start-sha <start> --head-sha <head>`.
   - Track the returned ID in a session array.
   - Delete the temp file.
3. Post the summary the same way but with no `--path`/`--line`/`--*-sha` flags.
4. **On any HTTP failure mid-batch**: call `./post-draft-note.sh --discard-mine --project <id> --mr <iid> --ids <comma-separated-IDs-from-this-run>`, then surface the error and stop.

The helper script lives next to this file. Resolve its path relative to `SKILL.md`.

### 11. Report

Print:
- MR title + URL
- `<mr_url>#drafts` direct link
- Counts (posted, skipped-as-duplicate)
- Reminder: review is **unpublished**. The user publishes or discards via the GitLab UI or `glab`.

Then stop.
