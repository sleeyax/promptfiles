# Global guidance

## Scope

- Don't make changes if I am just asking questions. Answer, and let me decide what to do about it.
- Never create files or directories in my home directory unless I ask for it, apart from changes inside the project you're working on.

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
- Don't delete local or remote branches yourself, even merged ones, and don't ask or offer to.
  This covers only your own actions: it says nothing about how the repo or its host handles branches on merge, so don't draw conclusions about that from it.
- Attribution belongs in git commit messages only. Never put a `Co-Authored-By` trailer, a "Generated with" footer, or any other attribution in a PR or MR body, whatever the existing PRs in the repo happen to do.

## Local Docker databases

- When working with a database running in a local Docker container, prefer the tooling inside the container (via `docker [compose] exec`) to inspect or modify data. Only fall back to host tooling when the required tool is not available inside the container.

## Memory

- Never write to memory unprompted. When something seems worth persisting, ask first whether to: write to project CLAUDE.md, write to global CLAUDE.md, save to memory, or skip it.

## Issue trackers

- When work belongs to an issue on any tracker (GitHub, GitLab, Linear, ...) that has task-list checkboxes, tick each box once the work satisfying it is pushed, through whichever CLI or MCP tool reaches that tracker.
- Tick only boxes the pushed work fully covers, and change only the checkbox markers so the rest of the issue body stays byte-identical.
