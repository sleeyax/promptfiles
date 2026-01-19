---
agent: edit
---
Refactor all interfaces to types in the selected file(s).

- Convert each `interface` declaration to a `type` declaration
- Maintain all properties, methods, and generics
- Update any intersection types if needed (use `&` instead of `extends`)
- Process all interfaces in the selection, file by file
