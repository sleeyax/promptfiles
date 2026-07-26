---
name: tailwind-v3-compat
description: Toggle Tailwind v3 compatibility behaviors back on in a Tailwind v4 project — default border color, ring width, placeholder color, button cursor, dialog margins, hover-on-mobile, and container padding.
disable-model-invocation: true
---

# Tailwind v3 Compat

The [v4 upgrade guide](https://tailwindcss.com/docs/upgrade-guide) documents seven behavior changes that ship with an official "add this to your CSS to preserve the v3 behavior" snippet. This skill walks the user through all seven, then writes (or removes) each one in the project's Tailwind v4 entry CSS under marker comments.

This is a toggle, not an install: it is safe to re-run any time to flip a flag back.

## Hard rules

- **Never write without an explicit user choice.** Every gate — entry-file pick, flag selection, container padding, apply confirmation — is a real stop: ask, then wait for the answer. Use the `AskUserQuestion` tool **when it's available in the session**; where it isn't (e.g. Codex), ask in plain text with the same numbered options and stop until the user replies. Never assume an answer. Selecting nothing means writing nothing.
- **Walk through all seven flags, every run** — both question groups, even if the user selected nothing in the first.
- **Only touch marker-wrapped blocks.** The entry CSS holds the user's own `@theme`, `@layer`, imports, and plugin directives. Never reformat, reorder, or edit anything outside the markers.
- **Existing v4 setups only.** Confirm the project is on Tailwind v4 before touching anything (step 1). If Tailwind is absent, still on v3, or has no entry CSS to edit, stop — this skill restores old defaults, it does not install or upgrade Tailwind.
- **Never modify markup.** Step 5 reports v3→v4 issues in components; it does not fix them.

## Compat catalog

Each flag is written between `/* tailwind-v3-compat:<id> */` and `/* /tailwind-v3-compat:<id> */`, which is what makes it independently detectable and removable.

| Marker ID | Flag | v4 default | v3 behavior restored |
|---|---|---|---|
| `border-color` | Default border color | `currentColor` | `gray-200` |
| `ring` | Default ring width/color | `1px`, `currentColor` | `3px`, `blue-500` ⚠️ |
| `placeholder` | Placeholder color | current text at 50% opacity | `gray-400` |
| `button-cursor` | Button cursor | `default` | `pointer` |
| `dialog-margin` | `<dialog>` margins | reset to `0` | `auto` (centered) |
| `hover` | Hover variant | only where the primary input supports hover | always applies |
| `container` | `container` utility | no centering or padding | centered with padding |

⚠️ The upgrade guide supplies the `ring` snippet but calls it out as **not idiomatic v4** — the intended fix is `ring` → `ring-3 ring-blue-500` in markup. Offer the toggle anyway, but say this in the option description and again in the final report, so the user knows it's an escape hatch rather than a destination.

### Snippets

Copy these verbatim. `@custom-variant` and `@utility` are top-level directives — never nest them in `@layer`.

```css
/* border-color */
@layer base {
  *,
  ::after,
  ::before,
  ::backdrop,
  ::file-selector-button {
    border-color: var(--color-gray-200, currentColor);
  }
}

/* ring */
@theme {
  --default-ring-width: 3px;
  --default-ring-color: var(--color-blue-500);
}

/* placeholder */
@layer base {
  input::placeholder,
  textarea::placeholder {
    color: var(--color-gray-400);
  }
}

/* button-cursor */
@layer base {
  button:not(:disabled),
  [role="button"]:not(:disabled) {
    cursor: pointer;
  }
}

/* dialog-margin */
@layer base {
  dialog {
    margin: auto;
  }
}

/* hover */
@custom-variant hover (&:hover);

/* container */
@utility container {
  margin-inline: auto;
  padding-inline: 2rem;
}
```

## Steps

### 1. Establish that this is a Tailwind v4 project

Gather two signals before doing anything else:

- **Declared version** — the `tailwindcss` entry in `package.json` (any workspace), or in `Gemfile`/`requirements.txt`/`go.mod`-adjacent tooling for projects using the standalone CLI. A missing `package.json` is not by itself disqualifying.
- **Entry CSS** — glob `**/*.{css,scss,pcss}` excluding `node_modules`, `dist`, `build`, `.next`, `vendor`, then grep for `@import ["']tailwindcss` (this also matches the granular v4 form, `@import "tailwindcss/preflight"` and `@import "tailwindcss/utilities"`) and, separately, for `@tailwind base|components|utilities`.

Resolve with this table. **Stop** means: say what was found, say why the skill doesn't apply, and do not write anything.

| Signal | Verdict |
|---|---|
| No `tailwindcss` dependency **and** no Tailwind directives in any CSS | Not a Tailwind project. Stop — this skill only edits an existing v4 setup, it does not install Tailwind. Offer to set it up instead if the user wants that. |
| `@tailwind base/components/utilities` present, or the dependency is `3.x` | Still on v3. Stop and point at the [upgrade guide](https://tailwindcss.com/docs/upgrade-guide) — there is nothing to restore until they're on v4. Offer to run `npx @tailwindcss/upgrade` first. |
| Dependency is `4.x` but no entry CSS found | v4 via CDN, a framework preset, or a path the glob missed. Ask the user for the entry CSS path; if there genuinely isn't one (CDN build), stop — there is nowhere to put the compat blocks. |
| Version is ambiguous or unreadable (no manifest, monorepo, standalone CLI) but a v4 `@import` is present | Treat as v4 and proceed, stating the assumption. |
| Multiple entry files (monorepo, multiple apps) | Ask which one, listing the candidate paths. Handle a single file per run and say so. |

Read the chosen file in full — needed for both detection and correct placement.

### 2. Detect current state

A flag is **ON** when its marker pair is present in the entry file.

Also look for hand-written equivalents *outside* the markers — an existing `@theme` containing `--default-ring-width`, a bare `@custom-variant hover`, a `dialog { margin: auto }`. When one turns up, report it, treat the flag as ON-but-unmanaged, and offer to adopt it under markers rather than writing a duplicate that would silently shadow it.

Show a table: Flag | State | What it changes. Name the entry file path above it.

### 3. Ask

With `AskUserQuestion`, one call with two multiSelect questions:

- **Preflight defaults** — border color, placeholder color, button cursor, dialog margins
- **Utilities & variants** — ring width/color, hover on mobile, container

Phrase each option in its meaningful direction: "Restore v3 …" when the flag is OFF, "Back to v4 …" when it's ON.

If `container` is newly selected, follow up with a single-select for the padding value — `2rem` (the guide's value), `1rem`, or none (center only, drop the `padding-inline` line) — since the snippet hard-codes it.

Without `AskUserQuestion`, list all seven as one numbered list in the same ON/OFF direction, ask the user to reply with the numbers to flip (e.g. `1 4 6`) or `none`, then stop and wait. Fold the container padding into that same list as a follow-up only if container was picked.

Drop any selection that already matches the current state. If nothing remains, report "no changes made" and skip to step 5.

### 4. Confirm and apply

Show the change set as `flag: ON → OFF` plus the target file, then confirm with `AskUserQuestion` (options: apply / cancel) — plain-text yes/no only when the tool is unavailable. On apply:

- **Enable** — insert the marker-wrapped block after the `@import "tailwindcss"` line and after any existing `@plugin`, `@source`, `@config`, or `@import` directives. Keep blocks in catalog order so re-runs produce stable diffs.
- **Disable** — delete the marker pair and everything between it, leaving no blank-line gap.
- Emit a separate `@theme` for the `ring` flag rather than merging into the user's — v4 merges multiple `@theme` blocks, and a separate one keeps the toggle reversible.

### 5. Report + advisory scan

Grep the project for v3→v4 changes that have **no** compat snippet and list them as a short advisory. **Do not modify them.** Scope to `{html,jsx,tsx,vue,svelte,astro,css}` outside `node_modules` and build dirs. Report each as a count plus two or three example `file:line` references — never a full dump.

| What to grep | Why it matters |
|---|---|
| `outline-none` | Renamed. v4's `outline-none` sets `outline-style: none`; the v3 behavior is now `outline-hidden` |
| `space-x-` / `space-y-` | Selector changed to `> :not(:last-child)` — breaks with reversed or inline-block children |
| `divide-x-` / `divide-y-` | Same selector change |
| Gradients under variants (`hover:from-`, `dark:via-`) | v4 preserves unset stops; `via-none` may be needed to reset |
| `theme(` in CSS | Prefer `var(--…)`, or the CSS-variable form `theme(--breakpoint-xl)` |
| `tailwind.config.js` at the root | v4 no longer auto-detects it — needs an explicit `@config "../../tailwind.config.js"` |

Then tell the user:

- Restart the dev server — CSS-first config is resolved at build time.
- If the `ring` flag was enabled, the idiomatic fix is `ring-3 ring-blue-500` in markup; this toggle is a stopgap.
- Re-running the skill flips anything back.
