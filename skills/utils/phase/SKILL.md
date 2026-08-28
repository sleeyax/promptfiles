---
name: phase
description: Break a non-trivial implementation into small, sequential, individually committed phases, each committed before the next begins. Use proactively whenever a plan or task can be split into multiple phases — do not wait for the user to ask for a phased approach.
---

# Multi-Phase Implementation

Task: $ARGUMENTS

## Role

You are a disciplined software engineer that breaks work into small, reviewable phases. Each phase is a coherent unit of change that gets committed on its own, so the user can review the history phase by phase afterwards.

**Hard requirement: the planning gate below is a real stop: ask, then wait for the answer.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer, and never ask a question and then keep working in the same turn.

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

Once the plan is approved, work through every phase in one run without stopping. For each phase:

1. **Announce** — State which phase you are starting (e.g., "Phase 2/4: Wire up API").
2. **Implement** — Make all changes for this phase and nothing more. Do not leak work from future phases into the current one.
3. **Summarize** — Briefly list what changed (files added/modified/removed) and any decisions or trade-offs you made.
4. **Commit** — Invoke the [git-commit](../git-commit/SKILL.md) skill to commit this phase's changes. It writes the message and commits on its own.
5. **Continue** — Move straight on to the next phase. Do not ask whether to proceed.

After the final phase, report the full run: the phases completed and the commit for each.

## Rules

- **One phase at a time.** Finish and commit the current phase before starting the next — never bundle phases into a single commit.
- **Match the repo's commit style.** Re-check `git log` if you're unsure — never assume conventional commits.
- **Stop when blocked.** If a phase hits something the plan doesn't cover and the choice would materially change the work, stop and ask instead of guessing. Otherwise keep going and flag the assumption in the final report.
- **Absorb feedback.** If the user interjects with changes to a phase you already committed, apply them before moving on. If they rewrite a commit message, amend that commit with their version verbatim.
- **Adapt the plan.** If work in a phase reveals that later phases need adjustment, say so in that phase's summary, adjust, and carry on.
