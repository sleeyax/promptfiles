# Global guidance

## Comments & commit messages

- Well-named functions and obvious helpers or utilities don't need a comment narrating them; it's noise. Only add a comment to explain non-obvious _why_ (constraints, gotchas), not the _what_ of readable code.
- Never restate the branch in a comment. Comments are read against the code as it stands, not the change that produced it: no rejected alternatives, no what-a-naive-version-would-do, no bug the test reproduces, no investigation notes. That goes in the commit message.
- State a constraint once. If the same rationale fits in two places, name a helper or type after it instead of copying the comment.
- In code comments and git commit messages, put each sentence on its own single line.
- Never hard-wrap: do not break a sentence across multiple lines, no matter how long the line gets.
- Never split or hyphenate a word across lines.
- If you need a paragraph-long comment to justify why the workaround is OK, the code is wrong — fix the code.

## Git

- Prefer conventional commits unless otherwise specified.

## Local Docker databases

- When working with a database running in a local Docker container, prefer the tooling inside the container (via `docker [compose] exec`) to inspect or modify data. Only fall back to host tooling when the required tool is not available inside the container.

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Memory

- Never write to memory unprompted. When something seems worth persisting, ask first whether to: write to project CLAUDE.md, write to global CLAUDE.md, save to memory, or skip it.
