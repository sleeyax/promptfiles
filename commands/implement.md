# Implement Issue

Issue: $ARGUMENTS

Implement a specific issue from GitHub or GitLab. Example invocations: `/implement #1`, `/implement 2`.

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

Check the current branch with `git rev-parse --abbrev-ref HEAD`.

- If the current branch **is** the default branch (try `git symbolic-ref refs/remotes/origin/HEAD` to detect it; fall back to `main`):
  1. Run `git fetch origin` and then `git pull --ff-only` to bring the default branch up to date.
  2. Suggest a feature branch name derived from the issue title, following Conventional Commits style: `<type>/<kebab-case-summary>` (e.g. `feat/dark-mode-toggle`, `fix/login-redirect-loop`, `chore/bump-deps`). Pick the type from the issue's labels/content (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, etc.).
  3. Use the `AskUserQuestion` tool to ask the user how to proceed, with these options:
     - **Confirm** the suggested branch name (create and check it out)
     - **Custom name** — supply their own branch name (create and check that one out instead)
     - **Stay on default** — continue on the default branch and implement directly there
  4. Create the chosen branch with `git checkout -b <name>` unless the user opted to stay on the default branch.
- If the current branch is **already a custom branch** (not the default), stay on it and skip the branch setup.

### 5. Plan the Implementation

Once the issue is fetched, summarize:

- **Title** and **issue number**
- **Goal** — a 1-2 sentence restatement of what the issue is asking for
- **Scope** — files/areas likely affected
- **Open questions** — anything ambiguous in the issue that needs clarification

If the issue is unclear or missing key details, ask the user before writing any code.

### 6. Implement

Implement the changes. Follow the project's conventions (consult `CLAUDE.md` and surrounding code). Keep the change scoped to what the issue requests — do not bundle unrelated refactors.

### 7. Report

When done, summarize:

- What was changed (files and a brief description)
- Anything you intentionally did not do, and why
- Suggested next steps (tests to run, follow-up issues, etc.)

## Notes

- Do not create a commit, branch, or PR unless the user explicitly asks.
- If the issue references other issues, PRs, or discussions, fetch them too when they're load-bearing for the implementation.
