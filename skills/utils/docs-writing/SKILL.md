---
name: docs-writing
description: Write or edit project documentation — READMEs, guides, module and API docs, docs/ pages. Use when creating a new doc, restructuring docs that have drifted or duplicated, or reviewing prose for staleness and filler. Not for code comments or commit messages.
disable-model-invocation: true
---

# Writing documentation

A newcomer should be able to read the page once and understand the mechanism.
Everything below serves that.

## Where a document goes

**Document a thing next to the thing.**
A command's guide sits beside the command; a module's guide sits in the module.
If the reader has to guess which directory holds the explanation, it is in the wrong place.

**Say each thing in exactly one place.**
The top-level document carries orientation and links out; the component's own document carries the detail.
When the same explanation appears in two files, decide which one owns it, cut the other to a sentence and a link.

**Link with relative paths, and check they resolve.**
Anchors too: if you move a section, fix the links that pointed at it.

## What to write

Open with what the thing *is* and what it is *for*, in a few sentences, before any mechanism.

Then, roughly in this order:

- the entry point, so the reader can run or call something immediately
- an overview or diagram of how it works
- the detail: options, configuration, guarantees, failure modes

**Explain every member of a set you introduce.**
A table of subcommands, modes, roles or environments needs a line per row saying what that one is for.
A reader cannot infer purpose from a column of `yes` and `no`.

**Gloss jargon the reader cannot decode.**
Internal abbreviations, flag names and column names get a one-line explanation the first time they appear.
You know what `--strict-peer` or `is_canonical` means; the newcomer does not.

**Prefer a diagram for anything with a flow or a branch.**
ASCII inside a fenced block renders in a terminal, in an editor and on the web.
Label the arrows with what decides the branch.

```
  request ──▶ cache hit? ──yes──▶ serve stored copy
                 │
                 no
                 ▼
             fetch, store, serve
```

**Tables for reference, prose for why.**
A table of "stage → file" or "flag → effect" is easier to scan than the same content in sentences.
The reason a check exists is not.

## What not to write

**No counts of things that can change.**
"Three commands", "the two guards", "four roles", "all seventeen call sites" — every one of these goes stale on the next commit.
Write "the commands", "the guards", "every call site that takes a token".

Where a concrete list genuinely helps, keep the table but frame it as a snapshot and name its source of truth:

> The roles are defined in `roles.ts`, and adding one is a line in that file.
> As it stands:

The same goes for measured numbers — row counts, benchmark figures, file sizes, supported versions.
Either drop them or point at where the current figure can be read.

**No contentless asides.**
Delete anything that would leave the sentence's meaning intact if removed.

> ❌ nothing configured, and — this is the point — no records anywhere
> ✅ nothing configured, and no records anywhere

Em-dashes are fine when they hold a list or a clarification (`— staging, canary, production —`).
They are not fine when they hold a remark about your own writing.

**No performative phrasing where a plain word exists.**

> ❌ the heaviest configuration there is · the case nobody designs for
> ✅ the maximal configuration · an awkward case

**No narrating the document.**
Do not announce what a section will cover, then cover it. Just cover it.

**No restating the obvious.**
If the command name, the table header or the signature says it, do not repeat it in prose.

## Accuracy

**Verify before asserting.**
Read the code for anything you claim it does. Grep for a flag or setting before describing what it controls.

**Do not upgrade a description into a claim.**
If a field is stored but nothing branches on it, say what the field means — not what the system does with it.

**Use real identifiers in examples.**
Sample output, sample queries and sample payloads should name things that exist in this project.
An invented `users.email` in a codebase whose users table is `account_profiles` teaches the reader something false.

**State the guards and refusals.**
Where a tool refuses to run — wrong environment, missing prerequisite, non-reversible step — say so, and say what the reader does instead.
That is the sentence that saves the support question.

**Write for the current state, not the change that produced it.**
No rejected alternatives, no "previously this did X", no migration narration.
That belongs in the commit message or a changelog.

## Formatting

One sentence per line.
Never hard-wrap a sentence across lines, however long it gets; never split or hyphenate a word across lines.
This keeps diffs to the sentence that changed.

Keep paragraphs to a few lines. A page of dense prose is a page nobody finishes.

Bold the label at the start of a point rather than adding a heading for every paragraph.

Match the surrounding documents: their heading depth, their code-fence language tags, their voice.
A new page that reads like a different project is worse than a plainer one that fits.

## Review pass

Before finishing, reread and ask:

- Could a newcomer follow this and know what happened?
- Is any count or figure in the prose going to be wrong after the next change?
- Which sentences could I delete without losing information? Delete them.
- Does anything here also appear in another file? Cut one and link.
- Did I check each factual claim against the code?
- Does every link and anchor resolve?
