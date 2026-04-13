---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "tsconfig.json"
---

# TypeScript Conventions

> Path-scoped: auto-loaded when editing `.ts`/`.tsx` files.

- **Strict mode** — `"strict": true` in `tsconfig.json`, no exceptions
- **`unknown` over `any`** — narrow the type rather than cast away the problem
- **Interfaces for object shapes** — use discriminated unions for variant types (`type Foo = A | B`)
- **`const` over `let`**, never `var`
- **Zod at input boundaries** — validate API payloads, env vars, and message bodies at the entry point
- **Optional chaining + nullish coalescing** — `value?.nested ?? fallback` over `value && value.nested`
- **Return type annotations** on all exported functions — improves IDE feedback and reviewer clarity
- **Use the project's configured linter** — check `biome.json` or `eslint.config.*` before adding lint rules
- **Avoid barrel re-exports** (`index.ts` that re-exports everything) — they hide circular deps and slow TS

