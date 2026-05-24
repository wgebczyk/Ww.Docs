# Architecture — Event-Driven / CQRS

Load this file when the detected style is **Event-Driven** or **CQRS**.

Event-driven architecture decouples components by routing **events** (facts
about what has already happened) and **commands** (requests to change state)
through a bus or dispatcher. CQRS separates the write model (commands) from
the read model (queries), often with different storage shapes.

The two patterns commonly appear together but are not identical. This file
covers both.

---

## Invariants

1. **Events describe facts; commands describe intent.** Past tense versus
   imperative. An event was already true when it left the producer; a command
   may be rejected.
2. **Events are immutable and append-only.** Once published, the shape and
   meaning of an event cannot change. Versioning is explicit.
3. **Handlers are idempotent.** A handler that receives the same event twice
   must produce the same effect as receiving it once.
4. **Command side and query side are separate models.** Writes update the
   write model; reads come from a query model (denormalized, projected, or
   the same store accessed via different shapes).
5. **No synchronous chains across aggregates.** Cross-aggregate workflows are
   choreographed via events, not orchestrated via direct calls between
   aggregates.
6. **Failure paths are first-class.** Dead-letter queues, retry policies, and
   poison-message handling are part of the design, not afterthoughts.

---

## Detection Signals

This file applies when the repo shows:

- Explicit `Events/`, `Commands/`, `Handlers/` folders or namespaces.
- A message-bus client: MediatR, MassTransit, NServiceBus, Wolverine, Brighter,
  Spring Cloud Stream, EventBus, NATS, Kafka clients.
- Separation between command and query stacks (`Commands/`/`Queries/`,
  `WriteModel/`/`ReadModel/`).
- Event sourcing infrastructure: event store, snapshots, replay.

If the repo declares "Event-Driven" or "CQRS" in `docs/craft-docs/curated/`,
this file applies regardless of folder naming.

---

## Style-Specific Rules

In addition to the style-agnostic rules in `aspects/architecture.md`, file
these:

### Event Used as Command

**What it is:** A message named like an event ("OrderCancelled",
"PaymentReceived") is published *to cause* an action, not to record one.
Subscribers reject the message or change behavior — meaning it isn't a fact.

**Detection heuristics:**

- The publisher of `OrderCancelled` checks the response or expects success.
- A handler of `OrderCancelled` performs the cancellation work (the event was
  fired before the cancellation actually happened).
- Event handlers throw exceptions that propagate back to the publisher as if
  they could veto.
- Vocabulary mixed in one type: `CancelOrderEvent` (imperative + "Event").

**False positives:**

- A command is also published via a bus, but typed and named as a command.
- Sagas/process managers reacting to events to issue new commands are fine —
  the event is still a fact.

**Severity:**

- **Critical** when the system relies on event handlers to complete a
  business operation that the publisher considers atomic with the publish.
- **Major** when naming and direction are mixed but the actual flow works.
- **Minor** when only naming is off.

**Before:**

```csharp
// Publisher
var success = await _bus.Publish(new OrderCancelled(orderId));
if (!success) throw new ...;

// Handler
public Task Handle(OrderCancelled e)
{
    var order = _repo.Get(e.OrderId);
    order.Cancel();                  // doing the cancellation here — event used as command
    _repo.Save(order);
}
```

**After:**

```csharp
// CancelOrder use case performs the cancellation atomically and then publishes the fact.
public async Task Handle(CancelOrder cmd)
{
    var order = await _repo.Get(cmd.OrderId);
    order.Cancel();
    await _repo.SaveAsync(order);
    await _bus.PublishAsync(new OrderCancelled(order.Id, _clock.UtcNow));
}

// Downstream handlers observe the fact and react.
public Task Handle(OrderCancelled e) => _refunds.Issue(e.OrderId);
```

---

### Non-Idempotent Handler

**What it is:** A handler is not safe to invoke twice with the same input.
Re-delivery, retries, or replay will produce duplicate side effects.

**Detection heuristics:**

- A handler performs an `INSERT` without a uniqueness check or upsert on a
  natural key.
- A handler increments a counter, decrements stock, or charges a card without
  a deduplication record.
- A handler sends an email or external call without an idempotency key.
- No table tracks "processed message IDs" for at-least-once delivery.

**False positives:**

- Read-only handlers (projection updates that overwrite by ID) are naturally
  idempotent.
- Some external systems offer their own idempotency keys — verify that the
  handler uses them.

**Severity:**

- **Critical** when re-delivery would cause financial or correctness damage
  (duplicate charges, double stock decrement).
- **Major** when re-delivery causes user-visible duplicates (duplicate emails,
  duplicate notifications).
- **Minor** when re-delivery is harmless but wastes work.

**Before:**

```csharp
public async Task Handle(InvoiceIssued e)
{
    await _payments.ChargeAsync(e.CustomerId, e.Amount);   // no idempotency key
}
```

**After:**

```csharp
public async Task Handle(InvoiceIssued e)
{
    await _payments.ChargeAsync(
        e.CustomerId,
        e.Amount,
        idempotencyKey: $"invoice-{e.InvoiceId}");          // safe to retry
}
```

---

### Cross-Aggregate Sync Call

**What it is:** A handler in one aggregate makes a synchronous call into
another aggregate's repository or service to complete a business operation,
breaking eventual-consistency boundaries.

**Detection heuristics:**

- A command handler for aggregate A loads aggregate B, mutates it, and saves
  it in the same transaction.
- A handler reaches across modules synchronously to enforce an invariant that
  spans aggregates.
- A handler awaits an HTTP call to another service to decide whether to
  proceed.

**False positives:**

- Read queries that traverse multiple aggregates are fine — that's the read
  model's job.
- Sagas/process managers reading state to decide next steps are fine.

**Severity:**

- **Critical** when cross-aggregate writes are committed in one transaction
  and create distributed-locking or contention problems.
- **Major** when synchronous cross-aggregate reads block the write path.

**Before:**

```csharp
public async Task Handle(PlaceOrder cmd)
{
    var order = ...;
    var inventory = await _inventoryRepo.GetAsync(cmd.ProductId);     // other aggregate
    inventory.Reserve(cmd.Quantity);
    await _inventoryRepo.SaveAsync(inventory);
    await _orderRepo.SaveAsync(order);                                 // both in one tx
}
```

**After:**

```csharp
public async Task Handle(PlaceOrder cmd)
{
    var order = Order.Place(cmd);
    await _orderRepo.SaveAsync(order);
    await _bus.PublishAsync(new OrderPlaced(order.Id, cmd.ProductId, cmd.Quantity));
}

// Inventory aggregate reacts:
public async Task Handle(OrderPlaced e)
{
    var inv = await _inventoryRepo.GetAsync(e.ProductId);
    inv.Reserve(e.Quantity);
    await _inventoryRepo.SaveAsync(inv);
    if (!inv.WasReserved) await _bus.PublishAsync(new InventoryReservationFailed(e.OrderId));
}
```

---

### Event Schema Drift

**What it is:** An event's shape or meaning changes without an explicit
versioning strategy. Old consumers break or, worse, silently misinterpret
new events.

**Detection heuristics:**

- Event classes are edited in place (fields renamed, removed, semantics
  changed) without a version suffix or schema registry entry.
- Multiple field names mean the same thing across producers/consumers
  (`amount`, `total`, `value`) suggesting drift over time.
- Consumers use `try/catch` to handle unexpected event shapes.
- No event-versioning policy exists in `docs/craft-docs/curated/` and the
  codebase has been event-driven for > 6 months.

**False positives:**

- Internal in-process mediator messages (e.g. MediatR within a single deploy
  unit) don't need a versioning strategy as long as senders and handlers
  always deploy together.

**Severity:**

- **Critical** when events cross deploy-unit or service boundaries and there
  is no versioning.
- **Major** when versioning is ad-hoc and inconsistent.
- **Minor** when only naming inconsistency exists.

**Before:**

```csharp
public record CustomerRegistered(Guid Id, string Email);
// — later, in the same class, no migration:
public record CustomerRegistered(Guid Id, string Email, string CountryIso);
```

**After:**

```csharp
public record CustomerRegisteredV1(Guid Id, string Email);
public record CustomerRegisteredV2(Guid Id, string Email, string CountryIso);

// Upcast V1 → V2 on read; producers emit V2.
```

---

### Read Model Bypass

**What it is:** Query code reaches into the write model (write-side aggregates,
EF DbContext, command-side store) instead of using the projected read model,
defeating CQRS.

**Detection heuristics:**

- A query handler loads write-side aggregates and projects them inline.
- A controller reads from the write-side repository for a list endpoint.
- The read model exists but only some queries use it; others still hit the
  write side.

**False positives:**

- A very small system may legitimately defer building a separate read model.
  If an ADR declares "no separate read model yet", record as Accepted Trade-off.

**Severity:**

- **Major** when CQRS is declared and the read model exists but is bypassed.
- **Minor** when bypass is occasional and confined to admin tooling.

**Before:**

```csharp
public class GetOrdersHandler
{
    public Task<List<OrderDto>> Handle(GetOrders q) =>
        _writeContext.Orders                              // hits write side
            .Where(o => o.CustomerId == q.CustomerId)
            .Select(o => new OrderDto { ... })
            .ToListAsync();
}
```

**After:**

```csharp
public class GetOrdersHandler
{
    public Task<List<OrderDto>> Handle(GetOrders q) =>
        _readModel.OrdersByCustomer(q.CustomerId);        // read-side projection
}
```

---

## Reporting

- File these findings under `Aspect: Architecture`.
- The `Rule` field uses the headings above verbatim: `Event Used as Command`,
  `Non-Idempotent Handler`, `Cross-Aggregate Sync Call`, `Event Schema Drift`,
  `Read Model Bypass`.
- Style-agnostic rules from `aspects/architecture.md` keep their original
  rule names.
