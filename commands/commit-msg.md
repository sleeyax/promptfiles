# Suggest Commit Message

Suggest a commit message for the current changes. The message MUST match the style already used in this repo — do NOT default to any particular format.

## Steps

1. Run `git log --oneline -20` to determine the repo's commit message style. Study the output carefully and identify:
   - Whether messages use a prefix/type convention or are freeform
   - Capitalization (sentence case vs lowercase)
   - Tense and mood (imperative vs past tense)
   - Use of scopes, tags, or ticket references
   - Typical length and level of detail
2. Check for a commitlint config (e.g., `commitlint.config.*`, `.commitlintrc.*`, or a `commitlint` key in `package.json`). If found, its rules take precedence.
3. Run `git diff --cached` to see staged changes. If nothing is staged, run `git diff` for unstaged changes instead.
4. Consider the full conversation context — what task was being worked on, what the user's intent was, and any relevant discussion. Use this to write a more meaningful message than the diff alone would produce.
5. Produce exactly one commit message that **reads like the existing commits from step 1 wrote it**. Your message should be indistinguishable in style from the repo's history.
   - Keep the first line under 70 characters
   - Focus on *why*, not *what*
6. If the diff is large or touches multiple concerns, suggest up to 3 alternatives ranked by preference.
7. Output only the suggestion(s) — no explanation, no preamble.
