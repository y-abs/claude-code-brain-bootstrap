---
paths:
  - "**/routes/**"
  - "**/controllers/**"
  - "**/middleware/**"
  - "**/middlewares/**"
  - "**/features/**"
  - "**/handlers/**"
  - "**/usecases/**"
  - "**/runners/**"
  - "**/jobs/**"
  - "**/shared/**"
  - "**/workers/**"
  - "**/public/**"
  - "**/private/**"
  - "**/listeners/**"
  - "**/consumers*/**"
  - "**/server/**"
  - "**/api/**"
  - "**/src/**"
  - "**/app/**"
  - "**/lib/**"
  - "**/sources/**"
  - "**/sinks/**"
  - "**/adapters/**"
  - "**/integrations/**"
  - "**/audience/**"
  - "**/core/**"
  - "**/domain/**"
  - "**/config/**"
  - "routes/**"
  - "server/**"
  - "api/**"
---

# Node.js Backend Conventions

> Path-scoped: auto-loaded when editing API, route, server, or middleware files.

- **Typed route handlers** — no `any` on `req`/`res`; use typed wrapper (Express generics, Fastify schema)
- **Repository pattern** for data access — no DB calls directly in route handlers
- **Zod validation at the route boundary** — validate body, params, and query before touching business logic
- **Correct HTTP status codes** — 201 for creation, 204 for empty success, 404 for not found, 409 for conflict
- **Structured logging** — pino / winston with request IDs; never `console.log` in production paths
- **Async error middleware** — single `(err, req, res, next)` handler at app level; avoid try/catch in every route
- **Rate limiting on auth endpoints** — protect login/token/reset routes from brute force
- **NEVER emit side effects (HTTP calls, queue publishes) inside a DB transaction** — use deferred dispatch

