---
name: review-changes
description: Review a set of changes with one or more reviewers, then fix simple findings in their own commits. Use when the user wants to self-review code before pushing, or asks to review a branch. Other skills call this one in report-only mode to do their reviewing for them. For posting a GitLab MR review use review-mr instead.
---

# Review Changes

Scope: $ARGUMENTS

Review a set of changes — the current branch's commits unless told otherwise — with a user-chosen reviewer, then fix the **simple, unambiguous** findings in their own commits so the branch lands in a ready-to-review state before it's pushed. Anything that needs human judgement is reported, not fixed.

By default the review runs **two reviewers simultaneously** — Codex and Claude Code — because different models catch different things. Their reports are merged into one deduplicated verdict before triage.

The skill runs in whichever harness the user invoked it from (Claude Code, Codex, …) and offers the reviewers that harness can actually drive. Every reviewer is read-only — either an in-process subagent or a CLI subprocess. This skill's agent is the **only editor** — it triages the findings and applies the fixes itself.

It's also the reviewing engine other skills call instead of rolling their own — see [Report-only mode](#report-only-mode).

## Hard rules

- The review step is read-only. Only this skill's agent edits files, and only after the step 7 apply gate.
- Reviewers run independently. Never feed one reviewer's findings to the other, and never let one wait on the other — the value is in two uncorrelated opinions.
- Auto-fix **only** localized, unambiguous findings (see step 6). Report everything else for the human reviewer — never silently make architectural, security-sensitive, behaviour-changing, or judgement-call edits.
- Every gate — reviewer choice, apply, dirty-tree, re-review — is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer. Commits go through the `git-commit` skill's own gate.
- Never push. The user pushes manually.
- Don't dump the full diff into a prompt or hand it to the reviewer as one blob. Give the reviewer the base ref and let it run `git diff` / read files itself.
- Never spawn a reviewer that can edit: an in-process subagent gets read-only tools, and a reviewer CLI is launched with its write tools denied. A reviewer that can't be constrained is not an option — pick another one.

## Report-only mode

Another skill can call this one to do its reviewing — [review-mr](../review-mr/SKILL.md) does, to review a merge request's diff. Run steps 1–5 and hand the result back; **stop there**. No triage, no edits, no commits, no re-review gate, and no dirty-tree gate (nothing is being written).

The caller passes `report-only` in `$ARGUMENTS` along with the scope, and gets back:

- the merged, deduplicated findings in the shape below,
- each reviewer's name + model and how it ran,
- the raw per-reviewer and merged counts.

## Finding shape

Every reviewer is asked for the same shape, so findings from two of them can be compared, merged, and handed to a caller:

- `severity` — `blocker`, `concern`, `suggestion`, or `nit`
- `file` + `line` — a line the change actually touches
- `title` — ≤10 words, stated as a fact
- `explanation` — 2–4 sentences: problem, trigger, consequence, fix
- `suggestion` (optional) — a replacement snippet for those lines

## Workflow

### 1. Determine scope

1. Detect the current branch: `git rev-parse --abbrev-ref HEAD`.
2. Detect the base branch. **Do not assume the repo default** — a branch cut from an integration branch like `develop` diffs against *that*, not `main`. Take the first of these that resolves, and don't fall through to the next once one does:
   1. **Recorded base** — `git config --get agent-branch.<current>.base`, set by the [git-branch](../git-branch/SKILL.md) skill when the branch was created. Use it if the ref still exists (`git rev-parse --verify`).
   2. **Nearest branch by fork distance** — the branch whose fork point is closest to HEAD:

      ```sh
      cur=$(git rev-parse --abbrev-ref HEAD)
      git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin |
        grep -vxE "origin/HEAD|$cur|origin/$cur" |
        while read -r ref; do
          mb=$(git merge-base "$ref" HEAD) || continue
          echo "$(git rev-list --count "$mb..HEAD") $(git rev-list --count "$mb..$ref") $ref"
        done | sort -n -k1,1 -k2,2 | head -5
      ```

      Column 1 is how many commits HEAD has since the fork — the review scope — and column 2 how far the candidate has moved on since. Take the lowest column 1. Compare fork points, **not** `merge-base --is-ancestor`: an ancestor test only matches a base that hasn't advanced since the fork, and silently falls through to `main` the moment the integration branch gets one more commit — which is exactly the failure this ladder exists to prevent.

      On a tie in column 1, prefer a candidate that exists on `origin` (integration branches are pushed; local scratch branches often aren't). If it's still tied, ask the user which base to use rather than picking one.
   3. **Repo default** — `git symbolic-ref refs/remotes/origin/HEAD` (strip the `refs/remotes/origin/` prefix); fall back to `main`.
3. State the resolved base and which of the three rules produced it before running the review, so a wrong guess is visible immediately instead of surfacing as a bloated diff.
4. Default scope is the branch's committed changes vs the base: `<base>...HEAD`.
5. `$ARGUMENTS` may override:
   - a branch name → use it as the base, skipping the detection above.
   - a commit range (`<a>...<b>`, `<a>..<b>`, or two SHAs) → use it as the scope verbatim, skipping the detection above.
   - `uncommitted` → review staged + unstaged + untracked changes instead.
   - `-- <path> …` → restrict the review to those paths.
   - `report-only` → [report-only mode](#report-only-mode).
6. If there's no diff in scope, report that there's nothing to review and stop.

### 2. Identify the current harness

You already know this: your own system prompt names the harness you're running in — Claude Code ("You are Claude Code") or Codex ("You are Codex"). Use that. Don't infer it from which tools you happen to have. If you genuinely can't tell, ask the user which harness this is instead of guessing.

It decides how a reviewer is launched — in **Claude Code** the Claude reviewer is an in-process subagent; in **Codex** both reviewers run as CLI subprocesses (`codex review`, `claude -p`).

Then check which reviewer CLIs are installed — `command -v codex claude` — so step 3 only offers what can actually run. The default **Both** option needs every CLI its harness drives: the Codex CLI in Claude Code, and both CLIs in Codex.

### 3. Choose the reviewer

Ask — "Review changes?". Default to **Both**: two models reviewing the same diff independently catch noticeably more than either alone, and agreement between them is itself a signal. The single-reviewer options stay available for a quicker, cheaper pass.

In **Claude Code**:

- **Both** (Recommended) — Codex CLI and a read-only Claude review subagent, run simultaneously.
- **Codex** — Codex CLI, default model.
- **Claude Code** — a read-only review subagent, default model.
- **Skip** — exit cleanly without reviewing.

In **Codex**:

- **Both** (Recommended) — `claude -p` and a nested `codex review`, run simultaneously.
- **Claude Code** — `claude -p`, default model.
- **Codex** — a nested `codex review` subprocess, default model.
- **Skip** — exit cleanly without reviewing.

`AskUserQuestion`'s built-in **Other** entry covers the free-form case: the user names a harness + model (e.g. `claude code sonnet`, `codex gpt-5-codex`). Where that tool isn't available, list **Other** as a fifth numbered option.

Drop any option whose CLI is missing, and say why it's missing. If only **Skip** remains, report that and stop.

### 4. Run the review (read-only)

Route by the choice. Give every reviewer the quality bar below, plus the base ref (`<base>...HEAD`) or the uncommitted scope — never the diff itself.

- **Codex CLI** → `codex review --base <base> "<quality bar + finding shape>"` (or `codex review --uncommitted "…"` for the uncommitted scope). The quality bar goes in `codex review`'s positional `[PROMPT]` argument — there is no flag for it. Select a model with `-c model="<model>"`; `codex review` has no `-m`/`--model`. Capture stdout as the findings report. Same command whichever harness you're in.
- **Claude Code, in-process** (Claude Code only) → spawn a subagent (Agent tool) constrained to read-only tools (read / search / read-only git like `git diff`, `git log`, `git show`; no edit/write), with the model override if one was named. Prompt it with the base ref + the quality bar and have it return a findings report.
- **Claude Code, CLI** (from Codex or another harness) → one non-interactive run with write tools withheld:

  ```sh
  claude -p --allowed-tools "Read Grep Glob Bash(git diff:*) Bash(git log:*) Bash(git show:*)" \
    --disallowed-tools "Edit Write NotebookEdit" \
    "<review prompt: base ref + scope + quality bar + output format>"
  ```

  Add `--model <model>` when one was named. Capture stdout as the findings report.
- **Both** → start the two routes above for the current harness at the same time, then wait for both:
  - In **Claude Code**: spawn the review subagent in the background and launch `codex review` as a backgrounded Bash command in the *same* message, so neither blocks the other, then collect both reports.
  - In **Codex**: run both CLIs as concurrent background jobs writing to temp files, and `wait`:

    ```sh
    out_codex=$(mktemp); out_claude=$(mktemp)
    codex review --base <base> "<quality bar + finding shape>" >"$out_codex" 2>&1 &
    claude -p --allowed-tools "..." --disallowed-tools "..." "<review prompt>" >"$out_claude" 2>&1 &
    wait
    ```
- **Other** → parse the input: `claude` / `claude code` family → the Claude Code route for the current harness with that model; `codex` family → `codex review -c model="<model>" --base <base> "<quality bar + finding shape>"`. An unrecognized harness → ask the user for the exact non-interactive, read-only review command to run.

If a reviewer fails (non-zero exit, missing or unauthenticated CLI), surface its stderr and suggest the likely fix (e.g. `codex login`, `claude login`). With **Both**, keep going on the surviving reviewer's report and say the review is single-sourced; if it was the only reviewer, offer to pick a different one. Do not silently fall back to reviewing inline.

**Quality bar:** concrete bugs, correctness issues, security problems, and maintainability risks *introduced by these changes* — cite file + line, verify against the actual files, no speculation. Nits and style are in scope, at `nit` severity. Every reviewer returns its findings in the [finding shape](#finding-shape).

### 5. Merge the reports

Skip this when only one reviewer ran. Otherwise fold both reports into a single verdict — the two will overlap, and the same bug reported twice must not become two findings, two fixes, or two commits.

Two findings are the same when they describe the same defect in the same place: same file and same root cause, even if the line numbers drift, the severities disagree, or the wording is entirely different. Merge those into one entry — keep the clearer explanation and the more precise location, take the higher severity, and tag it with the reviewers that raised it.

- Sort agreed findings first. Both reviewers landing on the same defect is the strongest signal in the report; say so.
- A finding only one reviewer raised is not weaker evidence, just unconfirmed — these are often the most valuable ones. Verify it against the file yourself, and drop it only if verification shows it's plainly wrong, noting what you dropped and why.
- Never merge two distinct defects because they share a file, and never merge a specific finding into a vaguer one that happens to overlap it.
- When the two reviewers propose *contradictory* fixes for one defect, keep both proposals on the entry and treat it as complex/uncertain in step 6 unless one is obviously correct.

Print the merged list with a source tag per finding — `[both]`, `[codex]`, `[claude]` — and state the raw and merged counts (e.g. "14 findings from 2 reviewers → 9 unique, 5 agreed"). In report-only mode this list is the return value: hand it back and stop.

### 6. Triage the findings

Split every finding from the merged list into one of two buckets:

- **Simple / safe (auto-fixable)** — one obvious correct fix, confined to lines/files already in the diff, with no behaviour/API/design change and no new dependency (e.g. null check, off-by-one, wrong variable, missing `await`, obvious resource leak, logic typo).
- **Complex / uncertain (leave for the reviewer)** — architectural, security-sensitive, ambiguous, behaviour-changing, or otherwise a judgement call.

Print a numbered list. For each finding show its bucket, location, and — for the simple ones — the proposed fix.

### 7. Apply the fixes

First, if the working tree is dirty, ask: **Stash** (restore after) / **Proceed anyway** / **Report only** — so per-finding fix commits stay clean.

Then ask: **Apply proposed fixes** / **Pick a subset** / **Report only (no changes)**.

On apply: edit only the chosen simple findings. Keep the change tight to each finding — no unrelated refactors — and confirm each fix is actually correct.

### 8. Commit the fixes

One commit per finding, grouped only when a few fixes clearly belong together. For each commit, invoke the [git-commit](../git-commit/SKILL.md) skill (its confirmation gate applies). These commits land **after** the existing branch commits.

### 9. Offer a re-review

Ask: **Re-review** (run another pass from step 3, to confirm the fixes are clean and catch anything new) / **Finish**.

### 10. Report

Summarize:

- The base branch the review ran against.
- Each reviewer + model used, and how it ran (in-process subagent or CLI).
- Counts: raw findings per reviewer / unique after merging / agreed by both / fixed / left for the reviewer.
- The fix commit SHAs.
- The list of complex/uncertain findings the human reviewer should still address.
