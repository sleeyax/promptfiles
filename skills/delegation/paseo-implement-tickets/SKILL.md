---
name: paseo-implement-tickets
description: Implement one or more tickets, expanding sub-tickets, by running each in a fresh Paseo session in the current workspace.
argument-hint: "One or more ticket IDs, URLs, or file paths"
disable-model-invocation: true
---

# Implement Tickets via Paseo

Tickets: $ARGUMENTS

You are an orchestrator running inside a Paseo agent.
You write no code yourself: each ticket gets its own fresh Paseo session in the current workspace, which runs `/mattpocock-skills:implement <ticket>`.

## 1. Resolve the queue

1. Parse the tickets from the input. If it names none, ask for one and stop.
2. Work out which tracker each ticket lives in from its reference, the repo's remotes, and the tools at hand (a forge CLI such as `gh` or `glab`, a tracker MCP such as Linear, or local files), and read it there with its sub-tickets and state. If a reference stays ambiguous, ask.
3. Expand each ticket recursively:
   - A ticket with sub-tickets is a container: queue its open sub-tickets (depth-first, in the tracker's order), not the container itself.
   - A ticket without sub-tickets is a leaf: queue it if it is open.
   - Skip closed tickets and anything already queued.
4. Show the queue as a numbered list of `<id> <title>` and the skipped tickets with the reason, then proceed.

The queue is done when every input ticket is either queued as a leaf, expanded into its sub-tickets, or listed as skipped.

## 2. Run the queue

All sessions share one working tree, so run them strictly one at a time: the next session starts only after the previous one is idle.

Pick the provider once: read `Provider` and `Mode` from `paseo inspect "$PASEO_AGENT_ID" --json`.
Reuse the provider if it is a Claude provider (`claude`, `claude-tty`), since the prompt is a Claude Code slash command; otherwise use `claude-tty`.
Reuse the mode only when you reuse the provider.

For each queued ticket, in order:

1. Start the session and capture its ID, passing the ticket in the most self-contained form the tracker offers (a URL over a bare ID):

   ```bash
   paseo run -d -q --provider <provider> [--mode <mode>] --title "<id> <title>" "/mattpocock-skills:implement <ticket>"
   ```

   Without `--workspace`, Paseo places the agent in the caller's workspace, which is the target.
2. Wait with `paseo wait <id>`. It blocks until the agent is idle, which can take far longer than a shell tool's timeout, so run it as a background command (Bash `run_in_background` in Claude Code) and resume when it exits.
3. Read the outcome from the end of `paseo logs <id>`.
   - Finished: note the result and continue with the next ticket.
   - Asked a question, hit an error, or stopped short: halt the queue, and tell the user which session needs them and what it is waiting on. They can answer it in Paseo and re-run this skill for the remaining tickets.

## 3. Report

A table with one row per ticket: ID, title, agent ID, and outcome (done, halted, not started, skipped).
