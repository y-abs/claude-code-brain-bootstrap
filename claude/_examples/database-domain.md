<!-- EXAMPLE: Delete this file after reading. Create your own domain docs following this pattern. -->

# Database Domain — Example

> This is a **worked example** of a domain knowledge doc for database patterns. Replace with your actual DB domain.

## Database Architecture

- **Primary DB**: PostgreSQL 16 (could be MySQL, MongoDB, etc.)
- **ORM / Query Builder**: Knex.js / Prisma / SQLAlchemy / GORM
- ⚠️ If using multiple DBs (read replica, write primary), document which is used where

## Schema Model

### Core Tables

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `users` | User accounts | `id`, `email`, `role`, `created_at` |
| `orders` | Business orders | `id`, `user_id`, `status`, `total`, `created_at` |
| `order_items` | Line items | `id`, `order_id`, `product_id`, `quantity`, `price` |
| `products` | Product catalog | `id`, `name`, `sku`, `price`, `stock` |

### Key Relationships

```
users 1──────N orders
orders 1──────N order_items
products 1──────N order_items
```

## Migration Patterns

- Migration tool: {{MIGRATION_TOOL}} (Knex, Prisma, Alembic, Flyway, etc.)
- ⚠️ Never mix DDL and DML in the same migration
- ⚠️ Always test rollback: `migrate up` → `rollback` → `migrate up`
- Column names: `snake_case`, scoped by table, no redundant prefixes

## Common Query Patterns

### Join Pattern (correct)
```sql
SELECT o.id, o.status, u.email, SUM(oi.price * oi.quantity) as total
FROM orders o
JOIN users u ON u.id = o.user_id
JOIN order_items oi ON oi.order_id = o.id
WHERE o.id = $1
GROUP BY o.id, u.email;
```

### Pagination Pattern
```sql
SELECT * FROM orders
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;
```

## ⚠️ Pitfalls

1. **Timestamp columns vary by table** — check which column name each table uses (`created_at` vs `create_date` vs `timestamp`)
2. **Soft deletes** — always filter `WHERE deleted_at IS NULL` unless explicitly querying deleted records
3. **Multi-tenant schemas** — migrations iterate ALL tenant schemas, not just one
4. **Index management** — new queries on large tables need `EXPLAIN ANALYZE` before shipping

