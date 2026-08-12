---
name: granola-notes
description: Fetch the notes from a shared Granola meeting document (notes.granola.ai) and render them as markdown. Use whenever the user asks to fetch, read, summarize, or import notes or a transcript from a Granola link.
---

# Granola Notes

Document: $ARGUMENTS

Pull a Granola meeting document down and hand back its notes as markdown. Example invocations: `/granola-notes <share-url>`, `/granola-notes ec46e3a2-335f-4fca-b9b0-e41c188ebebd`.

`$ARGUMENTS` is the share URL (query string and all) or the bare document UUID. Empty means the link is somewhere in the conversation — use it; if there is none, ask.

## Hard rules

- Use `fetch-granola.py`, which lives next to this file. Do not fetch the URL with `WebFetch` (Granola answers HTTP 403 without a browser User-Agent) and do not reach for browser automation — the page's data is in the served HTML.
- **What a share link exposes is Granola's AI-written summary, not the verbatim transcript.** Never present it as a word-for-word record, and never fill gaps by inventing speech.
- Do not follow the "Chat with meeting transcript" link (`notes.granola.ai/t/...`) that Granola appends to the notes. It requires a login and redirects away. If the user wants the raw transcript, say it isn't reachable from a share link and let them export it from the Granola app.
- Granola's speech-to-text mangles names, product names and jargon. Correct them against what you already know from the conversation or the destination notes, and say which ones you changed.
- When writing the notes somewhere (a file, Logseq, an issue), report anything in the source that contradicts what's already there rather than silently overwriting or silently keeping both.

## Workflow

### 1. Resolve the document

Take the URL or UUID from `$ARGUMENTS`, or from the conversation. A `/t/` transcript URL is not usable — ask for the `/d/` document URL.

### 2. Fetch

```
./fetch-granola.py <url-or-id>
```

Markdown goes to stdout: title, creation timestamp, owner, source URL, then the notes. Add `--format json` when you need the raw ProseMirror document instead of prose — for example to map the note hierarchy onto another tool's block structure.

Errors go to stderr with a non-zero exit and are self-explanatory (403 for a private or revoked link, 404 for a bad id, "no document content" when the link grants no access). Report the failure rather than guessing at the content or retrying with a different tool.

### 3. Deliver

Default to showing the notes in chat, structured as Granola had them.

If the user asked for them to land somewhere — a file, a Logseq block, an issue, a message — write them there instead, matching that destination's existing structure, heading depth and wording conventions rather than pasting Granola's formatting verbatim. Preserve the nesting: it carries which point was made in support of which.

Keep the source URL with the notes so the original is traceable.

### 4. Report

State where the notes landed, and flag:
- names or terms you corrected
- anything the source contradicts in the destination
- that this is the summary, not the transcript, if the user asked for a transcript

Then stop.
