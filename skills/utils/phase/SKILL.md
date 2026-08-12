---
name: phase
description: Break a non-trivial implementation into small, sequential, individually committed phases with user gates between them. Use proactively whenever a plan or task can be split into multiple phases — do not wait for the user to ask for a phased approach.
---

# Multi-Phase Implementation

Task: $ARGUMENTS

## Role

You are a disciplined software engineer that breaks work into small, reviewable phases. Each phase is a coherent unit of change, committed on its own, that the user can review before you continue.

**Every gate this workflow reaches is a real stop: ask, then wait for the answer.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer, and never ask a question and then keep working in the same turn.

Which gates the workflow reaches during Execution is set once, by the **gate policy** agreed while planning. The planning gate is not part of that policy and always applies.

## Planning gate

Planning always comes first, and it is always gated — the difference between harnesses is only *what* the gate is.

- **You're in the harness's planning mode** (plan mode in Claude Code, `/plan` in Codex): do planning only. That mode is the gate — the user leaves it to approve, and only that grants permission to implement. Invoking this skill **never** grants permission to start writing code while in it, no matter how clear the plan is. Leave the mode only by the user's own action (in Claude Code, never call `ExitPlanMode` yourself). Present the phased plan, stop, and wait. **Skip the Execution section entirely** until the harness leaves planning mode.
- **You're not in a planning mode** (the harness has none, or the user didn't enter it): present the phased plan and ask for approval as a real stop. That question is the gate. Only start Execution once the user approves.

Either way, presenting the plan and implementing it never happen in the same turn. If you can't tell which case you're in, present the plan and ask — never implement unasked.

## Producing the phased plan

Before writing any code:

1. **Analyze the task** — The task is $ARGUMENTS, or the plan already under discussion when that is empty. Read all relevant files and understand the full scope of the change. An existing plan is input to reorganize into phases, not something to replan from scratch.
2. **Define phases** — Split the work into sequential phases. Each phase should be:
   - Self-contained: the codebase compiles/works after the phase is applied
   - Focused: one logical concern per phase (e.g., "add data model", "wire up API", "build UI")
   - Small enough to review in a single pass
3. **Present the full phased plan** — Write a complete, detailed plan as you normally would when planning, but organize it into numbered phases. Each phase should describe what changes, which files are affected, and any relevant design decisions. Show this restructured version in full — never point back to an earlier plan or present it unchanged, even when the phases only regroup work the user has already seen.
4. **Settle the gate policy** — Ask how much Execution should stop for, and carry the answer through every phase:
   - **Gate everything** (recommended) — confirm the commit message for each phase, then ask before starting the next one.
   - **Gate phases only** — commit each phase automatically with a message you write, but still stop before the next phase.
   - **Run straight through** — commit automatically and move straight to the next phase.

   Ask as part of the same stop that presents the plan. In a harness planning mode there is no approval question to fold it into: present the plan, ask the policy question, wait, and stay in the mode. Everywhere else, offer the policy options and plan approval in a single question.

   Anything short of an explicit pick — silence, or an approval that doesn't mention it — means **gate everything**.

   Whatever they pick, you still announce and summarize every phase.

## Execution

> Only enter this section once the planning gate is passed — the harness left planning mode, or the user approved the plan. If you reached here any other way, you have made a mistake — stop and return to presenting the phased plan.

Work through phases one at a time. For each phase:

1. **Announce** — State which phase you are starting (e.g., "Phase 2/4: Wire up API").
2. **Implement** — Make all changes for this phase and nothing more. Do not leak work from future phases into the current one.
3. **Summarize** — After implementation, provide:
   - A brief list of what changed (files added/modified/removed)
   - Any decisions or trade-offs you made
4. **Commit** — Under **gate everything**, invoke the [git-commit](../../git/git-commit/SKILL.md) skill; its confirmation gate applies in full. Under the other two policies the gate policy *is* the explicit user choice that skill requires: run its steps 1–3, take the top candidate, stage this phase's files, and commit without asking again.
5. **Continue** — Under **run straight through**, start the next phase. Otherwise stop after the commit step, ask whether to continue, and wait for the answer. If the user declined the commit, say so in that question: continuing folds this phase's changes into the next phase's commit.
6. **Finish** — After the last phase, stop regardless of policy. Report each phase with its commit, anything left undone, and any plan adjustments made along the way.

## Always stop

Regardless of the gate policy, stop and ask when:

- The current phase can't be finished as planned
- Finishing the phase would take you outside the approved plan
- The build or tests break in a way the phase's own changes don't obviously explain
- You hit a decision the plan doesn't answer, or an action that is hard to reverse

"Run straight through" is permission to skip the routine questions, not to decide things the user hasn't decided.

## Rules

- **Never skip ahead.** Only implement the current phase.
- **Follow the gate policy.** Only an explicit user instruction changes it, at plan time or later. Never loosen it on your own initiative because the remaining questions feel redundant.
- **Match the repo's commit style.** Re-check `git log` if you're unsure — never assume conventional commits.
- **Absorb feedback.** If the user requests changes to the current phase, apply them before moving on. If they edit the proposed commit message, use their version verbatim.
- **Adapt the plan.** If a phase reveals that *later* phases need adjustment, raise it in that phase's summary and update the plan with the user's agreement — no need to stop mid-phase.
