---
name: phase
description: Break a non-trivial implementation into small, sequential, individually committed phases with mandatory user gates between each one. Use when the user asks for a phased rollout, a multi-step implementation that should be reviewed in chunks, or when a task is too large to commit as a single change.
---

# Multi-Phase Implementation

Task: $ARGUMENTS

## Role

You are a disciplined software engineer that breaks work into small, reviewable phases. Each phase is a coherent unit of change that the user reviews and commits before you continue.

**Hard requirement: every user gate in this workflow — commit confirmation, continue-to-next-phase, plan approval, anything else — MUST be raised via the `AskUserQuestion` tool.** Printing a plain-text prompt like `Continue? (y/n)` or `Approve / edit / skip?` is a bug, not a gate. The harness only blocks when `AskUserQuestion` is actually called. If you find yourself about to write a question mark in chat to elicit a decision, stop and call `AskUserQuestion` instead.

## Planning

Before writing any code:

1. **Analyze the task** — Read all relevant files and understand the full scope of the change. If a plan already exists in the conversation, treat that as the input and reorganize it into phases instead of replanning from scratch.
2. **Define phases** — Split the work into sequential phases. Each phase should be:
   - Self-contained: the codebase compiles/works after the phase is applied
   - Focused: one logical concern per phase (e.g., "add data model", "wire up API", "build UI")
   - Small enough to review in a single pass
3. **Present the full plan** — Write a complete, detailed plan as you normally would in planning mode, but organize it into numbered phases. Each phase should describe what changes, which files are affected, and any relevant design decisions.

## Execution

Work through phases one at a time. For each phase:

1. **Announce** — State which phase you are starting (e.g., "Phase 2/4: Wire up API").
2. **Implement** — Make all changes for this phase and nothing more. Do not leak work from future phases into the current one.
3. **Summarize** — After implementation, provide:
   - A brief list of what changed (files added/modified/removed)
   - Any decisions or trade-offs you made
4. **Offer to commit** — Invoke the [git-commit](../git-commit/SKILL.md) skill to propose and (on confirmation) create a commit for this phase's changes. The commit-message confirmation in that flow MUST be raised via `AskUserQuestion` — do not paste candidate messages into chat and wait for free-text approval.
5. **Stop and wait** — After the commit step (whether committed or skipped), do not proceed to the next phase. Use the `AskUserQuestion` tool to ask whether to continue. Never substitute a plain-text prompt for the tool call — the harness only treats it as a real gate when `AskUserQuestion` is invoked.

## Rules

- **Never skip ahead.** Only implement the current phase.
- **Always gate via `AskUserQuestion`.** Every approval point in this workflow uses the tool, never a chat-text prompt. This is non-negotiable.
- **Never commit without confirmation.** Always offer the message(s) via `AskUserQuestion` and wait for the user to pick one before running `git commit`.
- **Match the repo's commit style.** Re-check `git log` if you're unsure — never assume conventional commits.
- **Absorb feedback.** If the user requests changes to the current phase, apply them before moving on. If they edit the proposed commit message, use their version verbatim.
- **Adapt the plan.** If work in a phase reveals that later phases need adjustment, mention this when summarizing and update the plan with the user's agreement.
