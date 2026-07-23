---
name: question
description: Answer a question about what was discussed or done in the current conversation, without modifying anything. Only use when the user explicitly invokes /question; never trigger proactively.
---

# Question

Answer the user's question using the current conversation context. This is a read-only skill: answer, then stop.

**Hard requirement: do not modify anything. No file edits, no file creation, no state-changing commands. Even if answering the question reveals a bug, a missing change, or an obvious improvement, do not fix it — mention it in the answer and let the user decide.**

## Steps

1. Take the question from the skill arguments. If no question was provided, ask the user what they want to know.
2. Answer primarily from the conversation context: prior messages, decisions made, work performed, and results already gathered this session.
3. Only if the context alone is insufficient or you need to verify a claim, use read-only tools (reading files, searching, inspection commands like `git log` or `git diff`). Never run anything that writes, deletes, or otherwise changes state.
4. Give a direct, concise answer. Lead with the answer itself; add supporting detail only where it helps. If the answer is uncertain or the context doesn't cover it, say so plainly instead of guessing.
5. Stop after answering. Do not propose or begin follow-up work unless the user asks.
