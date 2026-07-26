---
name: git-branch
description: Suggest a branch name for the current work in the repo's existing naming style. If on the default branch, create the new branch after confirmation; if on a custom branch, offer to rename it or branch off it. Records the base branch it was cut from. Use when the user asks for a branch name, wants to start a new branch, or wants to rename the current one.
---

# Git Branch

Suggest a branch name for the current work. If on the default branch, create the branch after confirmation. If on a custom branch, offer to rename it or branch off it. Whichever branch gets created, record the base it was cut from.

**Hard requirement: never create or rename a branch without an explicit user choice.** Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies.

## Steps

1. Detect the default branch with `git symbolic-ref refs/remotes/origin/HEAD` (strip the `refs/remotes/origin/` prefix). Fall back to `main` if that fails.
2. Detect the current branch with `git rev-parse --abbrev-ref HEAD`.
3. Inspect recent branch names to determine the repo's naming style. Use `git for-each-ref --sort=-committerdate --count=20 --format='%(refname:short)' refs/heads refs/remotes` and study:
   - Whether names use a prefix/type convention (e.g. `feat/`, `fix/`, `chore/`) or are freeform
   - Separator style (kebab-case, snake_case, slashes)
   - Use of ticket/issue references
   - Typical length and level of detail
4. Determine what the branch is *about*:
   - Run `git diff --cached` and `git diff` to see changes in progress.
   - Consider the full conversation context — task, intent, relevant discussion. Use this to write a more meaningful name than the diff alone would produce.
   - If there are no changes and no useful conversation context, ask the user what the branch is for before proceeding.
5. Produce up to 3 branch names, ordered from best to worst. If only one is appropriate, suggest just one. Each name should **read like the existing branches from step 3 produced it** — indistinguishable in style from the repo's history.
   - Keep names concise but descriptive
   - Match the repo's prefix/separator conventions exactly
6. Branch off the right base:
   - **If on the default branch:** the base is the default branch. Run `git fetch origin` and `git pull --ff-only` first to bring it up to date. Ask which suggested name (if any) to use, with a **Custom name** option. On confirmation, run `git checkout -b <name>` and verify with `git rev-parse --abbrev-ref HEAD`.
   - **If on a custom branch:** ask what to do, with these options:
     - **Rename this branch** to one of the suggested names — run `git branch -m <new-name>`. If the branch tracks a remote, warn the user that the remote branch will need to be updated separately (`git push origin -u <new-name>` and delete the old remote branch) and ask whether to do that now.
     - **Branch off this one** — the current branch is the base (e.g. branching a feature off `develop`). Run `git checkout -b <name>` and verify with `git rev-parse --abbrev-ref HEAD`.
     - **Custom name** and **Cancel**.
7. Record the base so later skills don't have to guess it:

   ```sh
   git config agent-branch.<new-branch>.base <base-branch>
   ```

   Do this immediately after every `git checkout -b`, with `<base-branch>` being the branch that was actually branched off — the default branch, or the custom branch in the *Branch off this one* case. On the rename path, only set the key if it isn't already there and the base is known.
8. If the user declines, do not change the branch.

## Base branch convention

`agent-branch.<name>.base` is the shared convention for "what this branch was cut from". Skills that need a review or diff base — [review-changes](../review-changes/SKILL.md) among them — read it first, because `origin/HEAD` only ever names the repo default and gets the base wrong for anything branched off an integration branch like `develop`. Setting it here is what makes that work, so never skip it.

Details that matter:

- **Own top-level section, not `branch.<name>.base`.** `branch.<name>.*` is Git's own namespace (`remote`, `merge`, `rebase`, `description`, …); a custom key there is squatting on space Git may claim later. Tools that track branch lineage keep to their own section for the same reason.
- **Git maintains it across renames and deletes.** `git branch -m` moves the whole `agent-branch.<old>.*` section to the new name, and `git branch -d/-D` removes it — so the key never goes stale on its own.
- **It's local to the clone.** `.git/config` isn't cloned or pushed, so a fresh clone or a cloud agent won't have it. That's why consumers must keep a working fallback rather than treating the key as required.
