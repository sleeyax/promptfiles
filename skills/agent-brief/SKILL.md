---
name: agent-brief
description: Render an agent-ready implementation brief — a durable, testable spec another agent can build from. Use when writing up work for an issue, a handoff, or a cloud agent to pick up.
---

# Agent Brief

Source (optional): $ARGUMENTS

Render a brief that another agent implements from. The brief is the contract: whatever discussion, issue thread, or session produced it is context, but the brief is what gets built.

This skill is a **renderer**, not an investigator. It never interviews the user, never explores the codebase on its own initiative, and never writes to a tracker — it returns markdown, and whoever called it decides where that lands. Invoked directly (`/agent-brief`), the source is the current conversation.

## Principles

- **Durable** — the brief may sit for weeks while the codebase moves. Describe interfaces, types, and behavioral contracts. Never reference file paths or line numbers, and don't assume today's implementation structure survives.
- **Behavioral, not procedural** — say *what* the system should do. The implementing agent explores fresh and decides *how*.
- **Testable** — every acceptance criterion must be independently verifiable. "Works correctly" is not a criterion.
- **Self-contained** — the brief is usually read on a tracker, where the repo's glossary isn't. Use the project's terms, but define any whose meaning a newcomer would guess wrong, and point at `CONTEXT.md` for the rest.

## Template

The heading is always `## Agent Brief`, unchanged, so a brief stays recognizable when something re-reads it later.

Each section carries a rule for when it applies. Drop the ones whose rule isn't met — an empty heading is noise.

```markdown
## Agent Brief

**Summary:** one line — what needs to happen

**Context:**
Why this is being asked for; the problem behind it.

**Current behavior:**
What happens today.

**Starting point:**
Which branch to continue from and what's already on it.

**Desired behavior:**
What should happen once the work is done, including edge cases and error handling.

**Key interfaces:**
- `TypeName` — what changes and why
- `functionName()` — current contract vs desired contract

**Decisions already made:**
- decision — and the reason, so it doesn't get relitigated

**Agent's discretion:**
- open question the implementing agent resolves itself, plus any constraint it must respect

**Acceptance criteria:**
- [ ] specific, independently verifiable criterion

**Out of scope:**
- adjacent thing that must not change
```

| Section | Include when |
| --- | --- |
| Summary | always |
| Context | the motivation isn't obvious from the summary |
| Current behavior | the work changes existing behavior — a bug's broken behavior, or the status quo an enhancement builds on |
| Starting point | work already exists that the implementer should continue from |
| Desired behavior | always |
| Key interfaces | named types or functions are involved |
| Decisions already made | the thread or session settled choices that shouldn't be reopened |
| Agent's discretion | detail was deliberately left to the implementer |
| Acceptance criteria | always |
| Out of scope | something adjacent came up and was deliberately excluded — never invent a boundary just to have one |

Under **Agent's discretion**, say explicitly that the implementing agent should pick something sensible and report what it picked, rather than stalling or asking.

## Being called by another skill

A caller supplies three things:

1. **The source material** — an issue thread, a session, a plan, or whatever the brief is being written from.
2. **Which sections apply** — the caller usually knows; where it doesn't, fall back to the rules above.
3. **How to treat unresolved detail** — either *blocking* (the caller already closed the gaps, so anything still open is a bug in its workflow) or *delegated* (open detail becomes **Agent's discretion**).

Return the rendered markdown and nothing else. The caller owns the confirmation gate and the write.

Current callers: [refine-issue](../refine-issue/SKILL.md) (issue thread + interview, gaps blocking) and [dispatch](../dispatch/SKILL.md) (session + branch state, gaps delegated).
