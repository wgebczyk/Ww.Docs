# Architecture — Clean Architecture

Load this file when the detected style is **Clean Architecture**
(Robert C. Martin's concentric-rings variant; closely related to Hexagonal).

Clean Architecture organizes code into concentric rings:

```
        ┌─────────────────────────────────┐
        │ Frameworks & Drivers (outer)    │   web, db, ui, devices
        │ ┌─────────────────────────────┐ │
        │ │ Interface Adapters          │ │   controllers, presenters, gateways
        │ │ ┌─────────────────────────┐ │ │
        │ │ │ Use Cases / Application │ │ │   application-specific business rules
        │ │ │ ┌─────────────────────┐ │ │ │
        │ │ │ │ Entities (inner)    │ │ │ │   enterprise-wide business rules
        │ │ │ └─────────────────────┘ │ │ │
        │ │ └─────────────────────────┘ │ │
        │ └─────────────────────────────┘ │
        └─────────────────────────────────┘
```

The **dependency rule** points inward: any source code in an inner ring knows
nothing about an outer ring. Names, types, and concepts from outer rings do
not appear in inner rings.

> **Relationship to Hexagonal:** Clean Architecture and Hexagonal share the
> same core idea (inward-pointing dependencies, ports owned by the domain).
> If the codebase uses Clean-Architecture vocabulary (Entities, Use Cases,
> Interface Adapters) and concentric folders, use this file. If it uses
> port/adapter vocabulary and inner-outer folders, use `hexagonal.md`. Do not
> load both.

---

## Invariants

1. **Inward-only dependencies.** Source code in a ring never references a
   ring further out. Use cases don't import controllers; entities don't
   import use cases.
2. **Entities are the most stable code.** Pure business rules with no
   dependency on application orchestration, IO, or frameworks.
3. **Use cases own the application flow.** They orchestrate entities and call
   outward through abstractions (boundaries) — never directly to adapters.
4. **Crossing boundaries is done via interfaces declared inward.** The use
   case defines a `Boundary` interface in its own ring; the adapter
   implements it.
5. **Frameworks are details.** Web framework, ORM, message bus, and UI live
   in the outermost ring and are interchangeable.

---

## Detection Signals

This file applies when the repo shows:

- Folders/projects named `Entities` / `Domain`, `UseCases` / `Application`,
  `InterfaceAdapters` / `Adapters` / `Presenters` / `Controllers`,
  `Frameworks` / `Infrastructure` / `Web` / `Persistence`.
- Project references run strictly inward: outer rings reference inner; inner
  rings reference nothing outer.
- Use cases own input/output **boundary** interfaces (often suffixed
  `InputBoundary`, `OutputBoundary`).
- Presenters convert use-case output models into view models for controllers.

If the repo declares "Clean Architecture" in `docs/craft-docs/curated/`, this
file applies regardless of folder naming.

---

## Style-Specific Rules

In addition to the style-agnostic rules in `aspects/architecture.md`, file
these:

### Dependency Rule Violation (Outward Reference from Inner Ring)

**What it is:** A class in an inner ring references a type from an outer
ring.

**Detection heuristics:**

- An entity references a use-case type.
- A use case references a controller, presenter, or any
  framework/infrastructure type.
- Project file dependencies point outward at any level.
- `using`/`import` lines in inner-ring files reference outer-ring namespaces.

**False positives:**

- A shared `SharedKernel` of pure primitives (value objects, primitive
  exception types) used by all rings is fine — it's effectively part of the
  innermost ring.
- Cross-cutting logging *abstractions* (`ILogger`) declared in the innermost
  ring are fine if implementations are outer.

**Severity:**

- **Critical** at the project-reference level — the build graph is inverted.
- **Major** when only `using`/`import` lines violate and the project graph is
  clean.
- **Minor** when a single helper crosses outward in a non-critical path.

**Before:**

```csharp
// UseCases/RegisterCustomer.cs
using Web.Controllers.Models;          // outward reference — wrong

public class RegisterCustomer
{
    public Task Handle(RegisterCustomerRequest req) { ... }   // request type lives in Web
}
```

**After:**

```csharp
// UseCases/RegisterCustomer.cs            — owns its own input model
public record RegisterCustomerInput(string Name, string Email);

public class RegisterCustomer
{
    public Task Handle(RegisterCustomerInput input) { ... }
}

// Web/Controllers — maps web request to use-case input
public class CustomerController
{
    [HttpPost]
    public Task Register(RegisterCustomerRequest req) =>
        _registerCustomer.Handle(new RegisterCustomerInput(req.Name, req.Email));
}
```

---

### Use Case Calling Adapter Directly

**What it is:** A use case calls an infrastructure adapter (repository
implementation, HTTP client, message-bus client) directly instead of through
a boundary interface owned by the use case ring.

**Detection heuristics:**

- A use case takes a concrete `EfCustomerRepository`, `HttpInvoiceClient`,
  etc. instead of an interface owned by the use case or entity ring.
- A use case instantiates an adapter (`new MailKitEmailSender(...)`).
- A use case imports framework types in its body
  (`SqlException`, `RestSharp.RestRequest`).

**False positives:**

- The composition root may pass a concrete adapter to the use case via DI —
  the use case sees only the interface type at compile time.

**Severity:**

- **Critical** when the use case directly imports framework types.
- **Major** when the use case takes a concrete adapter via constructor
  argument with no interface in between.

**Before:**

```csharp
public class RegisterCustomer
{
    private readonly EfCustomerRepository _repo;     // concrete adapter
    public RegisterCustomer(EfCustomerRepository repo) => _repo = repo;
    ...
}
```

**After:**

```csharp
// UseCases — boundary interface owned here
public interface ICustomerRepository
{
    Task AddAsync(Customer c, CancellationToken ct);
}

public class RegisterCustomer
{
    private readonly ICustomerRepository _repo;
    public RegisterCustomer(ICustomerRepository repo) => _repo = repo;
    ...
}

// Infrastructure (outer ring) — implementation
public class EfCustomerRepository : ICustomerRepository { ... }
```

---

### Missing Boundary Interface

**What it is:** A use case calls outward (to persistence, messaging, etc.)
without defining a boundary interface for that call. The use case is coupled
to whatever shape the outer ring provides today.

**Detection heuristics:**

- A use case depends on an interface declared in an outer ring (e.g. an
  `IEmailService` defined in `Infrastructure.Email`).
- A use case takes concrete adapter types and the project has no boundary
  interfaces folder.

**False positives:**

- Trivial primitives that need no abstraction (a logger, a clock) where the
  abstraction has been pulled to a shared kernel.

**Severity:**

- **Major** when use cases consistently lack boundary interfaces and reach
  outward via outer-ring contracts.
- **Minor** when the missing interface is isolated to one use case and the
  outer-ring interface happens to be stable.

**Before:**

```text
Infrastructure.Email/
  └─ IEmailService.cs                ← interface in outer ring
  └─ SmtpEmailService.cs

UseCases/
  └─ RegisterCustomer.cs             ← depends on Infrastructure.Email.IEmailService
```

**After:**

```text
UseCases/
  └─ Boundaries/INotifyNewCustomer.cs   ← boundary owned by use cases
  └─ RegisterCustomer.cs                ← depends only on INotifyNewCustomer

Infrastructure.Email/
  └─ SmtpNewCustomerNotifier.cs : INotifyNewCustomer
```

---

### Presenter Carrying Business Logic

**What it is:** Presenters or interface adapters perform business rules
(formatting decisions that depend on policy, validation, calculations) that
should live in entities or use cases.

**Detection heuristics:**

- A presenter computes discounts, totals, or status text by applying business
  rules.
- A presenter has unit tests that look like business-rule tests.
- A presenter reaches into the entity to recompute values rather than reading
  use-case output.

**False positives:**

- Format conversion (date formatting, locale handling, money string
  formatting) is presenter work, not business logic.
- Mapping a use-case output DTO to a view model is presenter work.

**Severity:**

- **Major** when business policy is computed in the presenter and would be
  wrong if a new caller of the use case bypassed the presenter.
- **Minor** when isolated and clearly pure formatting.

**Before:**

```csharp
public class OrderPresenter
{
    public OrderViewModel Present(OrderOutput o)
    {
        var discount = o.Items.Sum(i => i.Price) > 1000m ? 0.1m : 0m;   // business rule
        var total = o.Items.Sum(i => i.Price) * (1 - discount);
        return new OrderViewModel { Total = total, ... };
    }
}
```

**After:**

```csharp
// Use case computes the business outcome
public record OrderOutput(decimal Subtotal, decimal Discount, decimal Total, ...);

public class OrderPresenter
{
    public OrderViewModel Present(OrderOutput o) =>
        new OrderViewModel
        {
            TotalDisplay = o.Total.ToString("C", CultureInfo.CurrentCulture),
            ...
        };
}
```

---

## Reporting

- File these findings under `Aspect: Architecture`.
- The `Rule` field uses the headings above verbatim: `Dependency Rule
  Violation`, `Use Case Calling Adapter Directly`, `Missing Boundary
  Interface`, `Presenter Carrying Business Logic`.
- Style-agnostic rules from `aspects/architecture.md` keep their original
  rule names.
