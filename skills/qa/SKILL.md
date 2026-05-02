---
name: qa
description: QA-test a pull request — checkout the branch, install deps, walk unresolved review comments per-comment, then hand off for manual review. Use when the user supplies a GitHub/GitLab PR/MR link or asks to QA the current branch's PR.
---

# QA a Pull Request

PR: $ARGUMENTS

QA-test a pull request. Address open review comments per-comment, then leave the session open for the human to do manual review.

## Hard rules

- Never check out, install, push, commit, or resolve threads without explicit `AskUserQuestion` confirmation for that action.
- Never operate on the default branch.
- GitHub uses `gh`, GitLab uses `glab`. Prefer the matching MCP server if available; fall back to the CLI. If neither is available for the detected provider, stop and tell the user what to install.

## Workflow

### 1. Resolve the PR

- **If `$ARGUMENTS` provided:**
  - Full URL → parse provider, `owner/repo` (or `group/project`), and PR/MR number.
  - Bare `#N` or `N` → detect provider from `git remote -v` and use the current repo.
- **If empty:**
  - Default branch: `git symbolic-ref refs/remotes/origin/HEAD` (strip `refs/remotes/origin/`), fallback `main`.
  - Current branch: `git rev-parse --abbrev-ref HEAD`.
  - If current == default → tell the user and exit.
  - Otherwise look up the open PR/MR for the current branch (MCP-first; fallback `gh pr view --json number,url,title,body,headRefName` or `glab mr view`). If none exists, tell the user and exit.

### 2. Worktree check

If `git status --porcelain` is non-empty, use `AskUserQuestion` with options:
- **Stash** — `git stash push -u -m "qa: pre-checkout"`
- **Commit first** — invoke the [git-commit](../git-commit/SKILL.md) skill
- **Abort**

### 3. Checkout & install

- If not on the PR branch: `git fetch origin`, then `gh pr checkout <n>` / `glab mr checkout <n>`.
- If already on it: `git pull --ff-only`.
- Detect package manager via lockfile/manifest (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `uv.lock`, `poetry.lock`, `Gemfile.lock`, `go.mod`, `Cargo.toml`, etc.). Run install **only** if the lockfile changed vs. the previous HEAD or `node_modules`/venv is missing. Skip silently if no recognizable manifest. Confirm via `AskUserQuestion` before running install.

### 4. Fetch open review comments

- MCP-first; CLI fallback:
  - GitHub: `gh api repos/{owner}/{repo}/pulls/{n}/comments` and `gh pr view <n> --json reviews,comments`
  - GitLab: `glab` equivalents
- "Open" = any review thread not marked resolved, plus issue-level comments posted after the latest commit by someone other than the PR author.
- If none, skip to step 6.

### 5. Address comments per-comment

For each open comment:

1. Show author, `file:line`, body. Read surrounding code.
2. Propose a concrete fix in chat.
3. `AskUserQuestion` with options: **Apply**, **Skip**, **Custom** (user steers), **Stop addressing comments**.
4. On **Apply**: make the edit. Use judgment for commit grouping — closely-related fixes in the same area can be bundled; large/independent fixes get their own commit. When ready to commit a group, invoke the [git-commit](../git-commit/SKILL.md) skill (which itself requires confirmation).

After all comments are processed, if any commits were made:

- `AskUserQuestion`: **Push to remote?** On yes, `git push` (or `git push -u origin <branch>` if no upstream).
- `AskUserQuestion`: **Resolve addressed threads?** On yes, resolve each thread the user marked **Apply** on, via MCP/CLI.

### 6. Hand off for manual QA

Print a short handoff block:

- PR title + URL
- Branch name
- Summary of what was just addressed (or "no open comments")
- **Manual-test checklist.** First look in the PR body for an existing checklist (markdown `- [ ]` under a heading like "Test plan" / "QA" / "Testing"). If found, render it verbatim. Otherwise generate a brief diff-derived checklist (3–6 items, focused on changed surfaces).
- Reminder: session is open for further manual review.

Then stop. Do not start a dev server, run tests, or take further action unless the user asks.
