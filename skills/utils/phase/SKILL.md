---
name: phase
description: Break a non-trivial implementation into small, sequential, individually committed phases with mandatory user gates between each one. Use proactively whenever a plan or task can be split into multiple phases — do not wait for the user to ask for a phased approach.
---

# Multi-Phase Implementation

Task: $ARGUMENTS

## Role

You are a disciplined software engineer that breaks work into small, reviewable phases. Each phase is a coherent unit of change that the user reviews and commits before you continue.

**Hard requirement: every user gate in this workflow — commit confirmation, continue-to-next-phase, plan approval, anything else — is a real stop: ask, then wait for the answer.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer, and never ask a question and then keep working in the same turn.

## Planning gate

Planning always comes first, and it is always gated — the difference between harnesses is only *what* the gate is.

- **You're in the harness's planning mode** (plan mode in Claude Code, `/plan` in Codex): do **Planning only**. That mode is the gate — the user leaves it to approve, and only that grants permission to implement. Invoking this skill **never** grants permission to start writing code while in it, no matter how clear the plan is, and never leave the mode yourself to get around it (in Claude Code: don't call `ExitPlanMode`). Present the updated, phased plan, stop, and wait. **Skip the Execution section entirely** until the harness leaves planning mode.
- **You're not in a planning mode** (the harness has none, or the user didn't enter it): present the updated, phased plan and ask for approval yourself, in the form described under Role. That question is the gate. Only start Execution once the user approves.

Either way: what you present is the **phased** plan produced below, never the original plan you started from — restating that one is not passing the gate. Presenting it and implementing it never happen in the same turn. If you can't tell which case you're in, present the updated plan and ask — never implement unasked.

## Planning

Before writing any code:

1. **Analyze the task** — Read all relevant files and understand the full scope of the change. If a plan already exists in the conversation, treat that as the input and reorganize it into phases instead of replanning from scratch.
2. **Define phases** — Split the work into sequential phases. Each phase should be:
   - Self-contained: the codebase compiles/works after the phase is applied
   - Focused: one logical concern per phase (e.g., "add data model", "wire up API", "build UI")
   - Small enough to review in a single pass
3. **Present the full phased plan** — Write a complete, detailed plan as you normally would when planning, but organize it into numbered phases. Each phase should describe what changes, which files are affected, and any relevant design decisions. Show this restructured version in full — never point back to an earlier plan or present it unchanged, even when the phases only regroup work the user has already seen.

**Stop here** until the planning gate has been passed. Do not continue to Execution.

## Execution

> Only enter this section once the planning gate is passed — the harness left planning mode, or the user approved the plan. If you reached here any other way, you have made a mistake — stop and return to presenting the phased plan.


Work through phases one at a time. For each phase:

1. **Announce** — State which phase you are starting (e.g., "Phase 2/4: Wire up API").
2. **Implement** — Make all changes for this phase and nothing more. Do not leak work from future phases into the current one.
3. **Summarize** — After implementation, provide:
   - A brief list of what changed (files added/modified/removed)
   - Any decisions or trade-offs you made
4. **Offer to commit** — Invoke the [git-commit](../git-commit/SKILL.md) skill to propose and (on confirmation) create a commit for this phase's changes. Its confirmation gate applies.
5. **Stop and wait** — After the commit step (whether committed or skipped), do not proceed to the next phase. Ask whether to continue and wait for the answer.

## Rules

- **Never skip ahead.** Only implement the current phase.
- **Always gate.** Every approval point in this workflow stops for the user, in the form described under Role. This is non-negotiable.
- **Never commit without confirmation.** Always offer the message(s) and wait for the user to pick one before running `git commit`.
- **Match the repo's commit style.** Re-check `git log` if you're unsure — never assume conventional commits.
- **Absorb feedback.** If the user requests changes to the current phase, apply them before moving on. If they edit the proposed commit message, use their version verbatim.
- **Adapt the plan.** If work in a phase reveals that later phases need adjustment, mention this when summarizing and update the plan with the user's agreement.
