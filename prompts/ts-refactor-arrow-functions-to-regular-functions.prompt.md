---
agent: edit
description: Refactor arrow functions to regular functions
---
Refactor the arrow functions to regular functions. Ignore arrow functions that are used as callbacks or in expressions. Focus on standalone arrow functions or React components that can be converted to regular function declarations.

Example:

```typescript
// Before
export const myFunction = async () => {
  console.log("Hello, world!");
};  

// After
export async function myFunction() {
  console.log("Hello, world!");
}
```
