---
name: refine
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, refine their design, or mentions "refine this".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

# Asking questions

Ask exactly one question per turn, then halt and wait for the user's response before continuing. Never batch questions, never proceed on assumed answers, never self-answer and move on. The user must remain in control of the pace.

If a structured question tool is available in the current harness (e.g. `AskUserQuestion` in Claude Code), use it: provide your recommended answer plus alternatives as choices, and always include a final open-ended option for free-form input.

If no such tool is available, fall back to plain text: state the question, list the options including your recommendation, and explicitly stop output to wait for the user.
