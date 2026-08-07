---
name: brainstorm
description: Shape a raw idea into a direction worth refining — ground it in the codebase, frame the problem, surface the angles and edge cases the user hasn't considered, and weigh candidate approaches. Use when the user has an idea but no plan yet.
argument-hint: "The idea to brainstorm"
---

# Brainstorm

Idea: $ARGUMENTS

Take a raw idea and shape it into something worth refining. The idea arrives as a sentence; it leaves as a framed problem, a chosen direction, and a list of things the user hadn't thought about yet.

This is the *divergent* half. It widens the idea — finds the edge cases, the second-order effects, the approaches worth comparing. [refine](../refine/SKILL.md) is the convergent half that narrows it back down, one question at a time, and it needs a design tree to walk. This skill builds that tree.

## Hard rules

- Read-only. No edits, no commits, no tracker writes. The output is a conversation and a shaped idea, nothing on disk.
- Every gate is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer.
- Ask exactly one question per turn. Never batch, never self-answer and move on.
- **Don't design the solution.** This skill settles *what problem* and *which direction*. `refine` resolves *how*. Stop once the design tree exists.
- **Don't invent the motivation.** If the idea doesn't say why it's wanted, that's the first question, not a guess.

## Workflow

### 1. Ground it

Search the codebase before asking the user anything the code can answer. Does something like this already exist, whole or in part, possibly under another name? What would the change touch? Who calls it today?

If `CONTEXT.md` or `CONTEXT-MAP.md` exists at the repository root, read it so the session speaks the project's language, and use the `domain-modeling` skill throughout, if it is available — challenge fuzzy terms as they come up and record what crystallises.

### 2. Frame the problem

Who's affected, what's wrong today, what "done" looks like, what constrains it. Skip whatever step 1 already answered — asking the user something the code just told you wastes their turn.

### 3. Surface what the user hasn't considered

The generative step, and the reason this skill exists. The user knows their idea; what they need is the part they can't see from inside it. Go looking for:

- edge cases and degenerate inputs the idea assumes away
- second-order effects — caching, auth, migrations, existing callers
- adjacent surfaces that inherit the change
- failure modes: what happens when the new thing is unavailable, slow, or wrong
- unstated constraints the codebase imposes
- the null case: who or what this *shouldn't* apply to

Split what you find into **worth deciding now** and **noted, safe to defer**. An undifferentiated list of twenty concerns is as useless as none. Anything that would change which direction gets chosen belongs in "now"; everything else is a "defer" the user can wave through.

Prefer concerns grounded in something you actually read in step 1 over generic checklist items, and say plainly when a concern is speculative.

### 4. Generate directions — only if there are real ones

Where the idea genuinely admits several approaches, lay out 2–4 that differ in substance, not in detail. Each gets a one-line description, what it costs, and what it gives up. Recommend one and say why. Include "do nothing" or "solve it elsewhere" when that's a real option.

**Never manufacture alternatives.** Plenty of ideas have exactly one sensible implementation, and padding the list with approaches nobody would pick is worse than offering none — it wastes the user's attention and makes the recommendation look staged. When there's one obvious direction, say so in a sentence, say why the alternatives don't hold up if any came to mind, and go straight to step 6.

### 5. Pick a direction

Gate — reached only when step 4 produced a real choice. The options are the directions it laid out, plus revising them, plus an open-ended choice.

With a single direction there's nothing to pick; fold the confirmation into step 6's gate instead.

### 6. Restate and hand off

Restate the shaped idea: the problem, the chosen direction and why, the constraints established, the deferred concerns from step 3, and what's still open. This restatement *is* the design tree `refine` walks, so it has to stand on its own without the conversation around it.

Then ask:

- **Refine it** (Recommended) — invoke the [refine](../refine/SKILL.md) skill with the restatement as its subject
- **Keep brainstorming** — the idea isn't ready yet
- **Stop here** — the user takes it from here

### Looping

An idea rarely lands in one pass, so **Keep brainstorming** is a first-class outcome, not a failure. Ask what to dig into — a direction that needs comparing, a deferred concern promoted to now, a part of the problem that's still fuzzy, or an open-ended "something else" — then re-enter at whichever step answers it and come back to this gate. There's no iteration count; the loop ends when the user picks refine or stop.

Every pass carries forward what's already settled. Never re-ask a resolved question, never re-raise a concern the user dismissed, and never reopen a chosen direction unless the user asks. The step 6 restatement is cumulative: it grows across passes rather than being rewritten from the latest one.

## Notes

- The chain this sits in: `brainstorm` shapes the idea, [refine](../refine/SKILL.md) resolves it, then [dispatch](../dispatch/SKILL.md) files it as an issue for an agent or [phase](../phase/SKILL.md) builds it now. Each step is the user's call, offered and never assumed.
- If the idea turns out to already exist in the codebase, say so and stop. That's the most valuable outcome this skill has.
