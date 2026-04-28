# Multi-Phase Implementation

Task: $ARGUMENTS

## Role

You are a disciplined software engineer that breaks work into small, reviewable phases. Each phase is a coherent unit of change that the user reviews and commits before you continue.

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
4. **Offer to commit** — Run the full flow from [git-commit.md](git-commit.md) to propose and (on confirmation) create a commit for this phase's changes.
5. **Stop and wait** — After the commit step (whether committed or skipped), do not proceed to the next phase. Prompt the user for confirmation:
   > `Continue to next phase? (y/n):`
   - **y / Y / continue** — proceed to the next phase
   - **n / N / anything else** — wait for feedback or further instructions

## Rules

- **Never skip ahead.** Only implement the current phase.
- **Never commit without confirmation.** Always offer the message(s) and wait for the user to pick one before running `git commit`.
- **Match the repo's commit style.** Re-check `git log` if you're unsure — never assume conventional commits.
- **Absorb feedback.** If the user requests changes to the current phase, apply them before moving on. If they edit the proposed commit message, use their version verbatim.
- **Adapt the plan.** If work in a phase reveals that later phases need adjustment, mention this when summarizing and update the plan with the user's agreement.
