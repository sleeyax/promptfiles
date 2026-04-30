# Git Branch

Suggest a branch name for the current work. If on the default branch, create the branch after confirmation. If on a custom branch, propose renaming it.

**Hard requirement: never create or rename a branch without an explicit user choice via `AskUserQuestion`.**

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
   - **If on the default branch:** run `git fetch origin` and `git pull --ff-only` first to bring it up to date. Use `AskUserQuestion` to confirm which suggested name (if any) to use, with a **Custom name** option. On confirmation, run `git checkout -b <name>` and verify with `git rev-parse --abbrev-ref HEAD`.
   - **If on a custom branch:** use `AskUserQuestion` to confirm renaming the existing branch to one of the suggested names, with a **Custom name** option and a **Cancel** option. On confirmation, run `git branch -m <new-name>`. If the branch tracks a remote, warn the user that the remote branch will need to be updated separately (`git push origin -u <new-name>` and delete the old remote branch) and ask whether to do that now.
7. If the user declines, do not change the branch.
