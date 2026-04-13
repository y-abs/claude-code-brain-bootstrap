<!-- EXAMPLE: Delete this file after reading. Create your own domain docs following this pattern. -->

# API Domain — Example

> This is a **worked example** of a domain knowledge doc for a REST API layer. Replace with your actual API domain.

## Endpoints Overview

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| `POST` | `/api/v1/orders` | Create a new order | Bearer token |
| `GET` | `/api/v1/orders/:id` | Get order by ID | Bearer token |
| `PUT` | `/api/v1/orders/:id/status` | Update order status | Admin role |
| `GET` | `/api/v1/orders` | List orders (paginated) | Bearer token |

## Request Validation

- All endpoints use **Zod** (TypeScript) / **Pydantic** (Python) for input validation
- Validation happens at the controller layer, before service logic
- ⚠️ `.strict()` mode rejects undeclared keys silently — always test with extra fields

## Error Handling Pattern

```
Controller → validate input → Service → Repository → DB
                                ↓ (on error)
                          ErrorBuilder.from(error)
                                ↓
                          Standardized error response
```

- 400: Validation errors (field-level details in response body)
- 401: Missing or invalid auth token
- 403: Insufficient permissions
- 404: Resource not found
- 409: Conflict (duplicate resource)
- 500: Unexpected server error (logged, not exposed to client)

## Auth Patterns

- Bearer token in `Authorization` header
- Token validated by middleware before reaching controller
- Role-based access: `admin`, `operator`, `viewer`
- ⚠️ New endpoints MUST have auth middleware — never skip

## Pagination

- Query params: `?page=1&limit=20&sort=createdAt&order=desc`
- Default limit: 20, max: 100
- Response includes `{ data, total, page, limit, pages }`

## ⚠️ Pitfalls

1. **File upload endpoints** use `multipart/form-data`, not JSON — test with actual files
2. **Status transitions** are validated server-side — the API rejects invalid transitions
3. **Soft deletes** — `DELETE` sets `deleted_at`, doesn't remove the row

