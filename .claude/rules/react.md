---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "src/components/**"
  - "src/pages/**"
  - "src/app/**"
---

# React Conventions

> Path-scoped: auto-loaded when editing React component or page files.

- **Functional components with hooks** — no class components in new code
- **Server state via React Query / TanStack Query** — not `useEffect + fetch + useState` triples
- **Client state via Zustand or Context** — avoid prop drilling beyond 2 levels; use composition
- **Colocate tests** — `ComponentName.test.tsx` next to the component, not in a separate `__tests__/` tree
- **Extract custom hooks** when stateful logic is shared across 2+ components
- **Stable `key` props** — never array index; use domain IDs or deterministic strings
- **Composition over large prop interfaces** — prefer `children` and slot patterns over 10-prop components
- **`useCallback`/`useMemo`** only where profiling shows a problem — premature memoization adds noise

