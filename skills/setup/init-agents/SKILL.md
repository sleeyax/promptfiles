---
name: init-agents
description: Initialize or improve an AGENTS.md file with a trimmed, non-obvious-only codebase guide, plus a CLAUDE.md stub that imports it.
disable-model-invocation: true
---

# Init AGENTS.md

Analyze this codebase and create an AGENTS.md file at the project root, which will be given to AI agents (Claude Code and others) operating in this repository.
Also create a CLAUDE.md at the project root whose entire contents are:

```
@AGENTS.md
```

This makes Claude Code inline AGENTS.md while other tools read AGENTS.md directly, so there is a single source of truth.

## Guiding principle

Agents are excellent at figuring out where code is located and how a codebase is structured — they do not need a map.
AGENTS.md is a guide towards success, not a 1:1 mapping of where source code lives.
Every line must pass this test: "Would removing this cause an agent to make mistakes?" If not, cut it.
When in doubt, leave it out — a short file that is entirely load-bearing beats a long file that is mostly discoverable.

## Workflow

### 1. Check for existing files

Check the project root for an existing AGENTS.md and CLAUDE.md before doing anything else.

- **AGENTS.md exists**: don't overwrite. Read it, explore the codebase (step 2), then propose targeted edits — additions for what's missing, removals for anything that fails the guiding principle or has gone stale. Ask before applying.
- **CLAUDE.md exists with real content** (anything beyond an `@AGENTS.md` import): its content belongs in AGENTS.md. Fold the parts that survive the guiding principle into the new or existing AGENTS.md, then replace CLAUDE.md with the `@AGENTS.md` stub. Ask before replacing it.
- **Neither exists**: proceed to step 2 and write both files fresh.

### 2. Explore the codebase

Survey the project: manifest files (package.json, Cargo.toml, pyproject.toml, go.mod, etc.), README, Makefile/build configs, CI config, and any existing AI tool configs (.cursor/rules/, .cursorrules, .github/copilot-instructions.md, .windsurfrules, .clinerules). If the harness can spawn subagents (e.g. the Agent tool in Claude Code), delegate the survey to one to keep the file dumps out of the main context; otherwise do it inline.

Detect:

- Build, test, and lint commands — especially non-standard ones, and how to run a single test
- Code style rules that differ from language defaults
- Non-obvious gotchas, required env vars, or workflow quirks
- Repo etiquette (branch naming, PR conventions, commit style) if evidenced by config or git history

If existing AI tool configs contain important rules, carry those into AGENTS.md.

### 3. Write AGENTS.md

Prefix the file with:

```
# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.
```

Include only:

- Commands an agent can't guess: non-standard scripts, flags, or sequences, including how to run a single test
- Code style rules that differ from language defaults (e.g. "prefer type over interface")
- Required env vars or setup steps
- Repo etiquette that isn't discoverable (branch naming, commit style, PR conventions)
- Non-obvious gotchas and the reasoning behind unusual architectural decisions

Exclude:

- Directory layouts, file-by-file structure, or component lists — agents find code themselves
- "High-level architecture" narration that just restates what reading the code reveals
- Standard commands obvious from manifest files (npm test, cargo test, pytest)
- Generic advice ("write clean code", "handle errors", "write tests")
- Made-up sections like "Common Development Tasks" or "Tips for Development" — only include information expressly found in files you read

Be specific: "Use 2-space indentation in TypeScript" beats "Format code properly."

### 4. Write the CLAUDE.md stub

Write CLAUDE.md containing exactly `@AGENTS.md` and nothing else.

### 5. Report

Summarize what was written and remind the user the files are a starting point they should review and tweak.
For every line kept in AGENTS.md, you should be able to say what mistake it prevents — if the user asks, justify any line or cut it.
