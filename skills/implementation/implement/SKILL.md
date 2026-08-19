---
name: implement
description: Implement a specific GitHub, GitLab, or Linear issue end-to-end — fetch it, set up a branch, plan, implement, propose a commit, and review the result. Use when the user references an issue number/URL/identifier and wants it implemented.
---

# Implement Issue

Issue: $ARGUMENTS

Implement a specific issue from GitHub, GitLab, or Linear. Example invocations: `/implement #1`, `/implement 2`, `/implement ENG-42`.

## Workflow

### 1. Extract the Issue Reference

Parse the issue reference from `$ARGUMENTS`. It identifies both the issue *and* the tracker it lives in:

- `#3` → issue `3` on the repo's git host
- `4` → issue `4` on the repo's git host
- `ENG-42` (letters, dash, digits) → Linear issue `ENG-42`
- A `linear.app/…/issue/ENG-42/…` URL → Linear issue `ENG-42`
- A GitHub or GitLab issue URL → that issue, on that host

If no issue reference was provided, ask the user for one before proceeding.

### 2. Determine the Tracker

**If step 1 matched a Linear identifier or URL, the tracker is Linear** — skip the git remote check entirely. Linear is independent of where the code is hosted, so the remote says nothing about it.

Otherwise, run `git remote -v` to inspect the remote URLs and match against the host:

- Contains `github.com` → **GitHub**
- Contains `gitlab.com` or any GitLab instance (e.g. self-hosted) → **GitLab**
- Otherwise, ask the user which tracker to use.

For GitHub/GitLab, also extract the `owner/repo` (GitHub) or `group/project` (GitLab) path from the remote URL — you'll need it to fetch the issue.

### 3. Fetch the Issue

#### Linear

The Linear MCP server is the only supported way to reach Linear — there is no CLI fallback, and no other tracker is a substitute.

**If the Linear MCP tools are not in this session, stop before fetching anything** and run `claude mcp list` to find out why. A session binds its MCP tools at startup, so the two failure modes need different fixes:

**Not configured** — no Linear server in the list. Adding one now cannot surface its tools in this session; it takes a restart. Tell the user to run `claude mcp add --transport http linear https://mcp.linear.app/mcp`, restart Claude Code, then re-run this skill — and stop the workflow. Offering to retry here would only fail again.

**Configured but unusable** — the server is listed, but unauthenticated, failing its health check, or `⏸ Pending approval`. This is fixable in place, so ask how to proceed and wait for the answer:

- **Retry** — the user fixes it via `/mcp` (authenticate / reconnect) or `claude mcp login <name>`; re-check for the tools and continue once they respond
- **Abort** — stop the workflow here

Keep looping on **Retry** until the tools work or the user aborts. If a retry reveals the server was never loaded into this session at all (pending approval usually means exactly that), say so and fall back to the restart path above.

Never guess at the issue's contents, and never silently continue without it.

With the tools available, fetch the issue by its identifier and read its title, description, state, labels, and comments.

#### GitHub / GitLab

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
   2. Suggest a feature branch name:
      - **Linear**: use the branch name Linear itself suggests for the issue (the `gitBranchName` field / "copy branch name" value). It embeds the issue identifier, which is what lets Linear link the branch back to the issue.
      - **GitHub / GitLab**: derive it from the issue title, following Conventional Commits style: `<type>/<kebab-case-summary>` (e.g. `feat/dark-mode-toggle`, `fix/login-redirect-loop`, `chore/bump-deps`). Pick the type from the issue's labels/content (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, etc.).
   3. Ask how to proceed and wait for the answer, with these options:
      - **Confirm** the suggested branch name
      - **Custom name** — supply their own branch name
      - **Stay on default** — continue on the default branch
   4. Unless the user chose **Stay on default**, run `git checkout -b <name>` and verify with `git rev-parse --abbrev-ref HEAD`. Then record the base with `git config agent-branch.<name>.base <default-branch>` — see the [git-branch](../git-branch/SKILL.md) skill's base branch convention.

### 5. Plan the Implementation

If a `CONTEXT.md` or `CONTEXT-MAP.md` exists, read it before planning — it's the project's glossary, and the issue may well be written in its terms.

Produce a plan whose shape fits the issue — let the work drive the structure rather than a fixed template. If the issue is unclear or missing key details, invoke the [refine-issue](../refine-issue/SKILL.md) skill to spec it out properly before finalizing the plan.

### 6. Implement

Once the plan is approved, execute it. Follow the project's conventions (consult `CLAUDE.md` and surrounding code). Keep the change scoped to what the issue requests — do not bundle unrelated refactors.

### 7. Report

When done, summarize:

- What was changed (files and a brief description)
- Anything you intentionally did not do, and why
- Suggested next steps (tests to run, follow-up issues, etc.)

### 8. Commit

Invoke the [git-commit](../git-commit/SKILL.md) skill to suggest a commit message and commit the changes.

**Do not commit without explicit user confirmation.** This step is authorization to *propose* a commit and wait for the user's explicit choice — not standing authorization to commit.

### 9. Review

Invoke the [review-changes](../review-changes/SKILL.md) skill to review the changes just implemented and fix simple findings in their own commits before the MR/PR is opened. It prompts for a reviewer (Codex / Claude Code / Other / Skip), offering whatever the current harness can drive.

## Notes

- Every gate in this workflow — the Linear MCP retry/abort prompt, the branch choice, the commit confirmation — is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer.
- If the issue references other issues, PRs, discussions, or (on Linear) parent/sub-issues, fetch them too when they're load-bearing for the implementation.
