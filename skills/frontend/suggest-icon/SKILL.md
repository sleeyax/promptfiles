---
name: suggest-icon
description: Suggest an icon for a given concept, using the most appropriate icon library available in the project. Use when the user asks for icon suggestions or which icon to use for something.
---

# Suggest Icon

Suggest one or more fitting icons for the concept the user describes, sourced from the icon library the project already uses. This is an advisory skill: suggest, then stop — do not edit files unless the user asks you to apply the suggestion.

## Steps

1. Take the concept from the skill arguments or conversation. If it's unclear what the icon is for, ask.
2. Determine which icon library to suggest from:
   - If specific icon libraries are mentioned in project instructions, comments, or by the user, prioritize those.
   - Otherwise, detect installed icon libraries from the project's dependencies (e.g. `lucide-react`, `react-icons`, etc.).
   - If none are installed, say so and suggest a suitable library along with the icon, but don't install anything.
3. Check how the codebase already imports and uses icons from that library, so suggestions match existing conventions (import style, size/class props, wrapper components).
4. Suggest the best-fitting icon, plus one or two alternatives when the choice is debatable. For each, give the exact identifier and a ready-to-paste snippet in the format appropriate for the detected library and codebase conventions.
5. Only verify an icon name exists (in the installed package's exports or the library's docs) when unsure — icon names vary between libraries and versions, and a wrong guess wastes the user's time.
