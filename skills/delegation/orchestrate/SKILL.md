---
name: orchestrate
description: Turn this session into a work orchestrator for the current repo — survey the plan, interview me on how to run it, then drive subagents item by item until the goal is reached.
disable-model-invocation: true
---

# Orchestrate

Input: $ARGUMENTS (optional — a hint at the plan source or goal, e.g. `milestone 1.4` or `the roadmap issue`)

You become this repo's orchestrator: you plan, delegate, watch and report, and write no code yourself. Every worker is an **in-session subagent**, never a detached top-level agent per item: detached agents fill the session tree with unexplained siblings and deliver fragments. Boundary: repos where the caller has write latitude — anything outward to a project they don't own stays gated by the global rules, campaign or not.

## Harness

This runs in Claude Code and in Codex; your system prompt says which. Only the mechanics differ:

- **Asking** — Claude Code: `AskUserQuestion`, batched (≤4 per call). Codex: plain text with numbered options, then stop until the caller replies; render what would be a preview inline. Either way every question takes a free-form answer too.
- **Workers** — Claude Code: the Agent tool, with `isolation: "worktree"` for code work and a model override per the models setting. Codex: its subagents, which have no isolation of their own, so a code worker creates its worktree with `git worktree add` outside the main checkout and removes it when done.

## Worker contract

A worker has no one to ask, so every brief carries these:

- **Full auto.** Pre-answer every gate the workflow it follows would stop on — branch name, plan approval, reviewer choice. A gate the brief missed takes its recommended option, and the report names the option taken.
- **Worktree-bound.** A worker changes and verifies only what lives in its worktree. A step that acts on the live machine — deploying, installing, restarting a service — goes into its report for the caller.
- **Reports to you** — what shipped (branch, PR/MR), what it decided on its own, what is left.

## 1. Survey

Establish, delegating to read-only subagents where the sweep fans out:

- **Conventions** — the repo's own docs, and the skills covering this repo's work, looked up by name: `file-issue`, `implement`, `review-changes`, `publish-mr`, `git-commit`, `refine-scope`, `to-spec`. Resolve against the skills this session actually lists, never against a constructed `<org>-skills:<name>`. Where a name resolves to several, prefer the one whose namespace matches the repo's org; else the unnamespaced one. Where it resolves to none, the fallback is a plain implement → self-review → draft PR/MR pass — attended, ask before falling back; AFK, fall back and note it in the report.
- **The tracker** — GitHub, GitLab or Linear, from the plan source or the origin remote.
- **The plan source** — an epic, a milestone, a roadmap issue, or just the open issues, preferred in that order; $ARGUMENTS wins when it names one.
- **In-flight work** — open PRs/MRs, assigned issues, claim markers. Anything already claimed, by anyone, is off the plan.
- **Order** — the dependency order where the source fixes one; your own proposal where it doesn't.

## 2. Interview

Campaign **settings** are repo-shaped, so they persist at `${XDG_CONFIG_HOME:-~/.config}/orchestrate/<key>.json` — key the origin remote URL sanitized to a filename, else the main checkout's absolute path. When the file exists, ask first: reuse as saved / revisit some / start fresh — quoting the saved values and their date. The **work order, goal and attendance are per-run and never saved**.

1. **Work order** — three proposals, each a preview of its actual ordered item list; recommend one. Ask this alone, so the previews render side by side.
2. **Goal** — when the campaign stops. Proposals from the survey: plan source exhausted (milestone or epic done), next N items, until the horizon is empty or everything left is blocked, time-boxed.
3. **Attendance** — is the caller staying nearby for this run? *Attended*: forward the genuine questions — an under-specified item's scope, a fork in the plan — batched, and asked while workers are still running so a slow answer costs nothing; everything routine is still decided, never asked. *AFK*: decide-and-report, parking what is truly the caller's for the final report — a question would block for hours. *Attended for now*: attended until a stated time or item count, AFK rules for whatever is still open after. Workers are full auto under every mode; attendance only governs what you ask.
4. **Settings** (the saved ones):
   - **Merge policy** — self-review then draft PR/MR awaiting the caller (recommend in shared repos); draft PRs/MRs with a WIP cap (default 3) that pauses new code work while full; orchestrator merges its own work once self-review is clean and the repo's checks pass — CI where there is one, else the checks its docs name (recommend in personal repos).
   - **Stacking**, when the next item depends on an unmerged PR/MR — stack on it freely; prefer independent items and stack only when nothing independent remains; never stack, work around.
   - **Models** — in Claude Code default Fable for planning, specs and issue writing, Opus for code and review; in Codex, offer the models it can select.
   - **Parallelism** — 1 / 2 / 3 / unlimited subagents at once. Recommend 2, and say why unlimited bites: usage, and under any non-merging policy an unreviewed-PR pile-up.
   - **Dynamic adds** — issues surfacing mid-run are *always filed*; do they join this plan? Never; only when they block a planned item (recommend); orchestrator's judgment — which may reorder within the goal, never extend it.

Write the settings file back with today's date.

## 3. Run

The loop, until the goal:

- **Claim before spawning.** Flip the item's tracker state by the repo's convention (assignment, status label), else self-assign, so reruns and other agents see it. Parallel spawns only for items independent of one another.
- **Spawn.** Code work runs on the code model in a worktree of its own; planning, spec and filing work on the writing model. Brief it per the worker contract and point it at the skills from the survey.
- **Harvest.** Read each report as it lands, post one short interim message per completed item, keep the plan current.
- **Failures: retry once, then park.** The second spawn gets the failure context; a second failure parks the item with a tracker note and the loop moves on. Halt the whole campaign only when the goal itself has become unreachable — and say so immediately.
- **Under-specified items** — attended, forward the scoping question rather than guess; AFK, draft the spec yourself (planning subagent) when the intent is clear enough to pin down, and park as needs-scoping when it genuinely isn't.
- **New issues** are filed by repo conventions the moment they surface, and join the plan only as the dynamic-adds setting allows.

## 4. Stop

Reaching the goal **drains** in-flight subagents — never abandon one mid-item. Release the claims on items claimed but never started. Then one campaign report: shipped, parked and why, filed, the live-machine steps workers left for the caller, and what the next campaign should start with; its first sentence is what a notification shows, so make it the summary. Resuming a killed campaign is simply running this skill again — step 1 re-reads the claims and PRs/MRs, so no other state is kept.
