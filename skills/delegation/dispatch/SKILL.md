---
name: dispatch
description: Turn the current session into an agent-ready brief, push it as a GitHub or GitLab issue, then apply your private follow-up instructions. Use when handing work off to a cloud agent.
---

# Dispatch

Scope (optional): $ARGUMENTS

Hand the current session off to a cloud agent. Everything worked out in this conversation — the goal, the decisions and their reasons, the plan, whatever is already on the branch — becomes an issue that an agent elsewhere can pick up and finish. Example invocations: `/dispatch`, `/dispatch just the caching part`.

Missing detail is expected. This skill does not interview the user to close it — it names what's open, delegates it to the implementing agent, and ships.

## Before you start

This skill writes — it creates an issue, and may commit and push — so it needs edits enabled. In Claude Code that means leaving plan mode first (accept-edits or auto mode).

If it's invoked from a planning mode, stop immediately and say so. Don't do the read-only half and leave the issue uncreated: the user approves the plan, enables edits, and invokes again.

## Hard rules

- Read-only against the code. The only writes are the issue at step 5, whatever the follow-up instructions do to that issue at step 6, and — if the user opts in at step 3 — commits via `git-commit` plus a push.
- Every gate is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer.
- **Don't interview.** Unlike [refine-issue](../refine-issue/SKILL.md), an unresolved detail is not a blocker — it goes under **Agent's discretion**. Only stop for something that would make the brief actively wrong.
- Don't contradict the session. A decision the user already made is recorded as a decision, not reopened as a question.
- Never create, label, or assign anything on the tracker without the step 5 confirm. Never force-push.

## Workflow

### 1. Distill the session

**If the session produced an approved plan, that plan *is* the deliverable — dispatch it as-is.** It's the text the user read and approved, so it ships verbatim: no re-summarizing, no restructuring, no improving it in passing. Skip step 4 entirely.

Otherwise, work from the conversation itself: the goal, the decisions made *and why*, constraints, alternatives that were rejected, the interfaces and types already explored, and anything already implemented.

`$ARGUMENTS` may narrow the scope to one part of the session. Empty means the whole thing.

If `CONTEXT.md` or `CONTEXT-MAP.md` exists at the repository root, read it so the brief speaks the project's language.

### 2. Determine the provider

Run `git remote -v` to inspect the remote URLs. Match against the host:

- Contains `github.com` → **GitHub**
- Contains `gitlab.com` or a self-hosted GitLab host → **GitLab**
- Otherwise ask the user which provider to use.

Extract the `owner/repo` (GitHub) or `group/project` (GitLab) path too.

### 3. Take stock of local state

Gather it in one call, not one per fact:

```sh
git rev-parse --abbrev-ref HEAD
git symbolic-ref refs/remotes/origin/HEAD
git status --porcelain
git log @{u}..HEAD --oneline
```

Fall back to `main` if the default branch can't be resolved, and treat a failing `@{u}..HEAD` as "no upstream — nothing is pushed".

**On a custom branch**, the brief must tell the agent to *continue from it*, not start over: the branch name, what's already committed there (`git log <base>..HEAD --oneline`), and what remains. Name the branch — no compare or commit URLs, which rot as the branch moves.

**With uncommitted or unpushed work**, say plainly that the cloud agent only sees what's on the remote, then ask:

- **Commit and push** (Recommended) — invoke the [git-commit](../git-commit/SKILL.md) skill (its confirmation gate applies), then `git push`, adding `--set-upstream origin <branch>` when the branch has no upstream. If the push is rejected as non-fast-forward, stop and report it — the user resolves the divergence.
- **Push existing commits only** — the working tree is left alone.
- **Continue anyway** — the brief states explicitly that local work exists which the agent won't see.

**On the default branch with a clean tree**, there's nothing to warn about — the agent starts fresh.

### 4. Write the brief

Skip this step when step 1 found an approved plan — that text ships as it is.

Otherwise, invoke the [agent-brief](../agent-brief/SKILL.md) skill with the distillation from step 1 and the branch state from step 3 as its source. Unresolved detail is **delegated**, not blocking.

Sections that typically apply here: Summary, Context, Starting point, Desired behavior, Key interfaces, Decisions already made, Agent's discretion, Acceptance criteria, Out of scope.

If that skill isn't installed, render those sections under an `## Agent Brief` heading directly.

### 5. Confirm and create

The issue body is the brief from step 4, or the approved plan verbatim when step 1 found one. Either way, when step 3 found a branch to continue from, add a short **Starting point** section naming it and what's already committed there — the plan was written before the branch existed and can't know it. That addendum is the only thing appended to an approved plan.

Show the body in full in chat, along with a proposed issue title. Titles are a plain sentence describing the work — no conventional-commit prefix, that convention stays on branches and commits.

Then ask:

- **Create the issue** — push it to the tracker.
- **Revise first** — apply the user's changes and show it again.
- **Print only** — nothing touches the tracker; skip step 6.

Write via the matching MCP server if one is available in the session, otherwise the CLI:

- **GitHub**: `gh issue create --title <title> --body-file <file>`
- **GitLab**: `glab issue create --title <title> --description <text>`

Print the resulting URL. If neither MCP nor CLI is available, stop and tell the user what to install.

### 6. Apply the private follow-up instructions

What happens to a dispatched issue is the user's call, written in a private instructions file. Look for it in this order, first match wins:

1. `./.agents/dispatch.local.md` — this repo's override
2. `~/.agents/dispatch.local.md` — the global default

**If found**, read it and resolve each instruction into a concrete action on the issue that was just created — a label, an assignee, a milestone, a comment mentioning an agent. Print the resolved actions, confirm once, then execute and report each result. An instruction that can't be carried out (a label that doesn't exist, an assignee the API rejects) is reported as failed, never silently substituted with something close.

The file authorizes tracker actions on the issue just created, and nothing else. It is not a channel for editing the codebase.

**If missing**, there's nothing to apply — and nothing to print yet. Step 7 is the only place this gets reported; don't emit it here and again in the summary. The block it uses:

````markdown
No follow-up instructions found, so the issue was left as-is. Create `~/.agents/dispatch.local.md` to say what should happen to an issue after it's dispatched:

```sh
mkdir -p ~/.agents && $EDITOR ~/.agents/dispatch.local.md
```

Plain English, one instruction per line:

```markdown
Assign the `ready-for-agent` label.
Assign GitHub Copilot to the issue.
```

For repo-specific behavior, put the same file at `./.agents/dispatch.local.md` — it takes precedence. Gitignore it with `.agents/*.local.md`, which hides the file while keeping a project-scoped `.agents/skills/` tracked; don't ignore `.agents/` wholesale.
````

Once that report is out, offer to write the file from instructions the user dictates.

### 7. Report

Summarize:

- Issue title + URL, or that nothing was created.
- The branch the agent continues from, and whether anything was committed or pushed — plus any local work left behind that the agent won't see.
- Which follow-up instructions ran and what each did — or, when there were none, the setup block from step 6, emitted here and only here.
- What was left under **Agent's discretion**, so the user knows which calls the agent will make on its own.

## Notes

- [refine](../refine/SKILL.md) is how the user settles open questions themselves instead of delegating them. Running it before dispatching is a perfectly good workflow — but it's their call, made beforehand, never this skill's to initiate or propose.
- The issue this produces is directly consumable by [implement](../implement/SKILL.md) if the work comes back in-house.
