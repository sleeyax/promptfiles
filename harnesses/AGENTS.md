# Global guidance

## Scope

- Don't make changes if I am just asking questions. Answer, and let me decide what to do about it.

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
- Never delete local or remote branches, even merged ones, and never ask or offer to.
- Attribution belongs in git commit messages only. Never put a `Co-Authored-By` trailer, a "Generated with" footer, or any other attribution in a PR or MR body, whatever the existing PRs in the repo happen to do.

## Local Docker databases

- When working with a database running in a local Docker container, prefer the tooling inside the container (via `docker [compose] exec`) to inspect or modify data. Only fall back to host tooling when the required tool is not available inside the container.

## Demo videos

- Record web app demos with a Playwright script using `recordVideo`. The Claude in Chrome GIF recorder grabs one frame per action, caps at 50 and stamps action labels, so its result plays like a slideshow.
- Keep the script in a scratch directory outside the repo and load Playwright from the project's `node_modules` with `createRequire`.
- Playwright videos show no mouse: inject a cursor through `addInitScript` that follows `mousemove` and pulses on `mousedown`, glide to each target with `page.mouse.move(x, y, { steps })`, and type with a per-key delay so viewers can follow along.
- Date and time inputs take their format from the browser's UI language, not the context `locale`, and Playwright's bundled Chromium ignores it. For local formats, launch the system Chrome or Chromium through `executablePath` with `--lang=<locale>` and the `LANGUAGE` env var.
- Hide dev overlays such as framework dev toolbars, turn off spellcheck squiggles, and scroll only when the target is out of view so sticky bars don't make the page jump.
- Trim the video to start once the page is ready, encode it as H.264 MP4 (`yuv420p`, `+faststart`), and check an ffmpeg contact sheet of its frames before handing it over.

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Memory

- Never write to memory unprompted. When something seems worth persisting, ask first whether to: write to project CLAUDE.md, write to global CLAUDE.md, save to memory, or skip it.

## Issue trackers

- When work belongs to an issue on any tracker (GitHub, GitLab, Linear, ...) that has task-list checkboxes, tick each box once the work satisfying it is pushed, through whichever CLI or MCP tool reaches that tracker.
- Tick only boxes the pushed work fully covers, and change only the checkbox markers so the rest of the issue body stays byte-identical.
