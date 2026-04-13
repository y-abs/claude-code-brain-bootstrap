<!-- EXAMPLE: Delete this file after reading. Create your own domain docs following this pattern. -->

# Messaging / Event-Driven Domain — Example

> This is a **worked example** of a domain knowledge doc for event-driven architecture. Replace with your actual messaging domain.

## Message Broker

- **Broker**: Kafka / RabbitMQ / Redis Pub/Sub / AWS SQS / NATS
- **Client library**: KafkaJS / amqplib / ioredis / etc.

## Topics / Queues

| Topic/Queue | Producer(s) | Consumer(s) | Purpose |
|-------------|-------------|-------------|---------|
| `order-created` | order-service | notification-service, inventory-service | New order event |
| `payment-completed` | payment-service | order-service | Payment confirmation |
| `inventory-updated` | inventory-service | catalog-service | Stock change |

## Message Format

```json
{
  "eventType": "ORDER_CREATED",
  "timestamp": "2026-01-01T00:00:00Z",
  "correlationId": "uuid-v7",
  "payload": {
    "orderId": "uuid",
    "userId": "uuid",
    "items": [...]
  }
}
```

## Transaction Safety — THE #1 RULE

> **NEVER emit messages inside a DB transaction.**

A DB transaction can roll back, but a sent message cannot be unsent. This creates data inconsistency.

### Safe Pattern: Deferred Callbacks
```javascript
// ✅ CORRECT — message deferred until after transaction commits
const result = await db.transaction(async (trx) => {
  const order = await createOrder(trx, data);
  return { order, pendingMessages: [{ topic: 'order-created', payload: order }] };
});
// Emit AFTER transaction committed successfully
for (const msg of result.pendingMessages) {
  await producer.send(msg);
}

// ❌ WRONG — message emitted inside transaction
await db.transaction(async (trx) => {
  const order = await createOrder(trx, data);
  await producer.send({ topic: 'order-created', payload: order }); // DANGER
});
```

### Safe Pattern: Outbox Table
```sql
-- Write message to outbox table inside the same transaction
INSERT INTO outbox (topic, payload, created_at) VALUES ('order-created', $1, NOW());
-- Separate process polls outbox and publishes to broker
```

## Consumer Patterns

- **Idempotency**: Consumers must handle duplicate messages gracefully (use `correlationId` for dedup)
- **Error handling**: Dead letter queue (DLQ) for messages that fail N times
- **Ordering**: Only guaranteed within a partition/queue — design accordingly
- **Sequential processing**: Use `for...of await`, NOT `Promise.all`, for ordered operations

## ⚠️ Pitfalls

1. **Consumer group rebalancing** — adding/removing instances causes partition reassignment; messages may be reprocessed
2. **Schema evolution** — always add new fields as optional; never remove fields without deprecation period
3. **Backpressure** — if consumer is slower than producer, messages accumulate; monitor lag
4. **Topic naming** — use kebab-case: `order-created`, not `OrderCreated` or `order_created`

