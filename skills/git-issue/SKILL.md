---
name: git-issue
description: Implement a specific GitHub or GitLab issue end-to-end — fetch it, set up a branch, plan, implement, and propose a commit. Use when the user references an issue number/URL and wants it implemented.
---

# Implement Issue

Issue: $ARGUMENTS

Implement a specific issue from GitHub or GitLab. Example invocations: `/git-issue #1`, `/git-issue 2`.

## Workflow

### 1. Extract the Issue Number

Parse the issue number from `$ARGUMENTS`. Strip any leading `#` and accept either form.

- `#3` → issue `3`
- `4` → issue `4`

If no issue number was provided, ask the user for one before proceeding.

### 2. Determine the Git Hosting Provider

Run `git remote -v` to inspect the remote URLs. Match against the host:

- Contains `github.com` → **GitHub**
- Contains `gitlab.com` or any GitLab instance (e.g. self-hosted) → **GitLab**
- Otherwise, ask the user which provider to use.

Also extract the `owner/repo` (GitHub) or `group/project` (GitLab) path from the remote URL — you'll need it to fetch the issue.

### 3. Fetch the Issue

Prefer the matching MCP server if one is available in the current session:

- **GitHub** → use the GitHub MCP server's issue-fetching tool
- **GitLab** → use the GitLab MCP server's issue-fetching tool

If the relevant MCP server is unavailable, fall back to the CLI:

- **GitHub**: `gh issue view <number> --json title,body,labels,state,comments`
- **GitLab**: `glab issue view <number>`

If both the MCP server and the CLI are unavailable, stop and tell the user what to install.

### 4. Set Up the Branch

1. Detect the default branch with `git symbolic-ref refs/remotes/origin/HEAD` (strip the `refs/remotes/origin/` prefix). Fall back to `main` if that fails.
2. Detect the current branch with `git rev-parse --abbrev-ref HEAD`.
3. **If already on a custom branch** (not the default), stay on it and move to step 5.
4. **If on the default branch:**
   1. Run `git fetch origin` and then `git pull --ff-only` to bring it up to date.
   2. Suggest a feature branch name derived from the issue title, following Conventional Commits style: `<type>/<kebab-case-summary>` (e.g. `feat/dark-mode-toggle`, `fix/login-redirect-loop`, `chore/bump-deps`). Pick the type from the issue's labels/content (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, etc.).
   3. Use the `AskUserQuestion` tool to ask how to proceed, with these options:
      - **Confirm** the suggested branch name
      - **Custom name** — supply their own branch name
      - **Stay on default** — continue on the default branch
   4. Unless the user chose **Stay on default**, run `git checkout -b <name>` and verify with `git rev-parse --abbrev-ref HEAD`.

### 5. Plan the Implementation

Produce a plan whose shape fits the issue — let the work drive the structure rather than a fixed template. If the issue is unclear or missing key details, ask the user before finalizing the plan.

### 6. Implement

Once the plan is approved, execute it. Follow the project's conventions (consult `CLAUDE.md` and surrounding code). Keep the change scoped to what the issue requests — do not bundle unrelated refactors.

### 7. Report

When done, summarize:

- What was changed (files and a brief description)
- Anything you intentionally did not do, and why
- Suggested next steps (tests to run, follow-up issues, etc.)

### 8. Commit

Invoke the [git-commit](../git-commit/SKILL.md) skill to suggest a commit message and commit the changes.

**Do not commit without explicit user confirmation via `AskUserQuestion`.** This step is authorization to *propose* a commit and wait for the user's explicit choice — not standing authorization to commit.

## Notes

- If the issue references other issues, PRs, or discussions, fetch them too when they're load-bearing for the implementation.
