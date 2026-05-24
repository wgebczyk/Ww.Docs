# Architecture — Vertical Slice / Feature Folders

Load this file when the detected style is **Vertical Slice**.

Vertical-slice architecture organizes code by **feature**, not by technical
layer. Each feature folder contains every artifact needed to deliver that
feature — request DTO, command/query, handler, validator, response DTO,
sometimes endpoint and tests — in one place.

The trade-off versus layered/hexagonal: less ceremony per feature, looser
constraints on cross-cutting consistency. Vertical slices avoid premature
abstraction and let each feature use whatever shape fits.

---

## Invariants

1. **Each feature is self-contained.** A feature folder contains its own
   request, handler, response, validator, mapper. No shared "service" layer
   sucking logic out of features.
2. **Features do not call other features.** If two features need shared
   behavior, extract it into a domain primitive or shared kernel — never
   `Features.OrderCreate.Handler` calling `Features.OrderUpdate.Handler`.
3. **Cross-cutting concerns are pipelined, not copy-pasted.** Validation,
   logging, transactions, authorization run as middleware/pipeline behaviors,
   not handwritten in every handler.
4. **Shared primitives live in a clearly named non-feature folder.**
   Typically `Shared/`, `Common/`, or `Domain/` — and they contain only
   genuinely shared invariants (value objects, base types), not handler
   helpers.
5. **Feature folders are the unit of ownership and review.** Adding a feature
   is one folder added; removing a feature is one folder deleted.

---

## Detection Signals

This file applies when the repo shows:

- A top-level folder `Features/` (or `UseCases/`, `Slices/`) with feature-named
  subfolders (`Features/Billing/`, `Features/CreateOrder/`).
- Each feature folder co-locates request/command, handler, validator,
  response.
- MediatR or a similar mediator/dispatcher is used to route requests to
  handlers.
- Few or no "shared" service interfaces span feature folders.

If the repo declares "Vertical Slice" or "Feature Folders" in
`docs/craft-docs/curated/`, this file applies regardless of folder naming.

---

## Style-Specific Rules

In addition to the style-agnostic rules in `aspects/architecture.md`, file
these:

### Feature-to-Feature Coupling

**What it is:** One feature handler invokes another feature's handler,
dispatch, or internal types directly — turning the slice graph into a tangle.

**Detection heuristics:**

- A handler `using`s another feature's namespace.
- A handler calls `_mediator.Send(new OtherFeatureCommand(...))` from inside
  a different feature's handler.
- Two features share a private helper class that lives in one of them and is
  referenced from the other.
- A test for feature A imports types from feature B.

**False positives:**

- Reading and writing the same aggregate via a shared repository is fine.
- Two features posting to the same `IEventBus` / publishing events that the
  other observes is fine — coupling is via events, not direct calls.

**Severity:**

- **Critical** when feature handlers chain synchronously through one another
  to complete a single business operation (the slice has dissolved).
- **Major** when one or two cross-feature handler calls exist.
- **Minor** when a single helper class is shared by referencing across
  features but the call surface is read-only.

**Before:**

```csharp
// Features/CancelOrder/CancelOrderHandler.cs
public class CancelOrderHandler
{
    public async Task Handle(CancelOrder cmd)
    {
        ...
        // reach into another feature
        await _mediator.Send(new IssueRefundCommand(cmd.OrderId));
    }
}
```

**After:**

```csharp
// Features/CancelOrder/CancelOrderHandler.cs
public async Task Handle(CancelOrder cmd)
{
    var order = await _repo.Get(cmd.OrderId);
    order.Cancel();
    _repo.Save(order);
    _bus.Publish(new OrderCancelled(order.Id));
}

// Features/IssueRefund/OrderCancelledHandler.cs — own listener
public class OrderCancelledHandler
{
    public Task Handle(OrderCancelled e) => _refundService.Issue(e.OrderId);
}
```

---

### Shared Service Drift

**What it is:** A "shared service" or "manager" class accumulates logic
extracted from multiple features, recreating the layered service-class
anti-pattern that vertical slice was meant to avoid.

**Detection heuristics:**

- A class in `Shared/`, `Services/`, or `Common/` has methods that are
  obviously feature-specific (`CalculateBillingForCancelOrder`,
  `BuildRefundEmailBodyForOrderRefund`).
- The same shared class has methods used by exactly one feature each.
- The class grows steadily with each new feature.

**False positives:**

- A genuine domain primitive (`Money`, `EmailAddress`, `IbanNumber`) shared by
  many features is fine — that's the point of `Shared/`.
- A pipeline behavior (validation, logging) is shared by design.

**Severity:**

- **Major** when a shared class has > 5 feature-specific methods.
- **Minor** when one or two methods drifted in and would be cheaply moved
  back into their feature.

**Before:**

```csharp
public class OrderService     // in Shared/
{
    public void CalculateBillingForCreate(Order o) { ... }
    public void CalculateBillingForCancel(Order o) { ... }
    public void CalculateBillingForUpdate(Order o) { ... }
    public string BuildEmailBodyForCancel(Order o) { ... }
    public string BuildEmailBodyForRefund(Order o) { ... }
}
```

**After:**

```text
Features/CreateOrder/  → BillingCalculator.cs   (feature-private)
Features/CancelOrder/  → BillingCalculator.cs   (feature-private)
Features/UpdateOrder/  → BillingCalculator.cs   (feature-private)

Shared/Domain/Money.cs                          (genuine primitive — shared)
```

---

### Cross-Cutting Concern Copy-Paste

**What it is:** A cross-cutting concern — validation, logging, auth,
transaction, tenant scoping — is hand-coded inside multiple handlers instead
of running as a pipeline behavior.

**Detection heuristics:**

- Repeated `if (!_authz.CanDo(...)) throw new UnauthorizedException();` lines
  at the top of multiple handlers.
- Repeated `_log.LogInformation("Handling X for {id}", cmd.Id);` boilerplate.
- Validation logic duplicated in handler bodies even though a validator class
  exists.
- `BeginTransaction` / `CommitAsync` repeated in every command handler.

**False positives:**

- A handler doing one bespoke authorization decision that is unique to it
  (e.g. checking ownership of a specific resource) is *not* copy-paste —
  it's domain logic.

**Severity:**

- **Major** when the same boilerplate appears in ≥ 3 handlers and a pipeline
  behavior would absorb it cleanly.
- **Minor** when the duplication is mild and the pipeline shape isn't yet
  established.

**Before:**

```csharp
public async Task<Unit> Handle(CreateOrder cmd, CancellationToken ct)
{
    _log.LogInformation("Creating order for {Customer}", cmd.CustomerId);
    if (!_authz.CanCreate(cmd.CustomerId, _user)) throw new UnauthorizedException();
    var v = await _validator.ValidateAsync(cmd, ct);
    if (!v.IsValid) throw new ValidationException(v.Errors);

    using var tx = _db.BeginTransaction();
    ...   // actual handler work
    await tx.CommitAsync(ct);
    return Unit.Value;
}
```

**After:**

```csharp
public async Task<Unit> Handle(CreateOrder cmd, CancellationToken ct)
{
    ...   // actual handler work only
    return Unit.Value;
}

// Pipeline behaviors handle logging, auth, validation, transaction once.
```

---

### Feature Folder Without a Slice

**What it is:** A feature folder exists but the actual work happens elsewhere
— the folder contains only a thin handler that forwards to a shared service,
or a request DTO that's deserialized by a controller that itself does all the
work.

**Detection heuristics:**

- A handler body is one line forwarding to a shared service.
- A feature folder has only DTOs and no handler.
- The matching controller for the feature contains substantial business
  logic rather than a thin dispatch.

**False positives:**

- Read-side queries that are genuinely a single repository call are
  legitimately thin.

**Severity:**

- **Major** when a write-side feature is hollowed out and all work lives in
  a controller or shared service.
- **Minor** when only one read-side feature is thin and adequate.

**Before:**

```csharp
// Features/CreateOrder/CreateOrderHandler.cs — empty shell
public class CreateOrderHandler
{
    public Task Handle(CreateOrder cmd) => _orderService.Create(cmd);  // forwards
}
```

**After:**

```csharp
// Features/CreateOrder/CreateOrderHandler.cs — owns the slice
public class CreateOrderHandler
{
    private readonly IOrderRepository _repo;
    private readonly IClock _clock;
    public CreateOrderHandler(IOrderRepository repo, IClock clock) { _repo = repo; _clock = clock; }

    public async Task Handle(CreateOrder cmd)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Lines, _clock.UtcNow);
        await _repo.AddAsync(order);
    }
}
```

---

## Reporting

- File these findings under `Aspect: Architecture`.
- The `Rule` field uses the headings above verbatim: `Feature-to-Feature
  Coupling`, `Shared Service Drift`, `Cross-Cutting Concern Copy-Paste`,
  `Feature Folder Without a Slice`.
- Style-agnostic rules from `aspects/architecture.md` keep their original
  rule names.
