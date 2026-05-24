# Architecture — Hexagonal (Ports and Adapters)

Load this file when the detected style is **Hexagonal**.

Hexagonal architecture (Alistair Cockburn) puts the domain at the center.
The domain exposes **ports** (interfaces it owns) and is surrounded by
**adapters** that implement those ports. The domain has no knowledge of any
adapter — it interacts only with its own port abstractions.

Ports come in two flavors:

- **Driving (primary) ports** — invoked by the outside world to drive the
  application (e.g. `IRegisterCustomerUseCase`).
- **Driven (secondary) ports** — invoked by the domain to reach the outside
  world (e.g. `ICustomerRepository`, `IEmailSender`).

---

## Invariants

1. **Domain depends on nothing infrastructural.** No framework attributes, no
   ORM types, no HTTP types, no message-bus SDKs inside the domain.
2. **Ports belong to the domain.** Port interfaces live with the domain, not
   with the adapter that implements them.
3. **Adapters depend on the domain — never the reverse.** Project references
   point from adapters into the domain.
4. **No port without a real use.** Don't invert a dependency that has no
   alternate implementation today and won't tomorrow (this is over-engineering,
   not hexagonal).
5. **Driving adapters call use cases; driven adapters implement ports.**
   HTTP controllers and message handlers translate input into use-case calls;
   persistence/email/etc. implement secondary ports.

---

## Detection Signals

This file applies when the repo shows:

- A `domain` / `core` package or project containing port interfaces
  (`IXxxRepository`, `IXxxGateway`, `IXxxNotifier`) but no implementations.
- Implementations live in adapter packages/projects named `adapters.in.*` /
  `adapters.out.*`, `*.Driving.*` / `*.Driven.*`, or
  `infrastructure.persistence` / `infrastructure.messaging`.
- The domain project has no framework or persistence dependencies in its
  manifest.

If the repo declares "Hexagonal" or "Ports and Adapters" in
`docs/craft-docs/curated/`, this file applies regardless of folder naming.

---

## Style-Specific Rules

In addition to the style-agnostic rules in `aspects/architecture.md`, file
these:

### Port Defined in Adapter

**What it is:** A port interface that should be owned by the domain is
declared in an adapter project. The dependency rule is inverted on paper but
still incorrect: the adapter dictates the contract.

**Detection heuristics:**

- An interface named like a port (`IXxxRepository`, `IXxxGateway`) lives in a
  project named like an adapter (`Infrastructure.*`, `Persistence.*`,
  `Adapters.Out.*`).
- The domain references that adapter project to use the interface (visible in
  `*.csproj`, `build.gradle`).
- The interface uses adapter-specific types in its signature
  (`IQueryable<T>`, `HttpResponseMessage`) — a sign it was designed
  adapter-out, not domain-in.

**False positives:**

- Cross-cutting adapter abstractions (`ILogger`, `IMetrics`) that are
  inherently infrastructure-shaped may live in a shared abstractions package.

**Severity:**

- **Critical** when the domain references the adapter project to use the
  interface (the project graph violates the dependency rule).
- **Major** when the interface is in the wrong place but the domain doesn't
  reference the adapter (a separate shared package mediates).
- **Minor** when only naming is off and the port works correctly.

**Before:**

```text
Domain.csproj                  (depends on Infrastructure.Persistence)  ← wrong
Infrastructure.Persistence.csproj
  ├─ ICustomerRepository.cs     ← port lives in the adapter
  └─ EfCustomerRepository.cs
```

**After:**

```text
Domain.csproj
  └─ ICustomerRepository.cs     ← port in domain
Infrastructure.Persistence.csproj (depends on Domain)
  └─ EfCustomerRepository.cs    ← adapter
```

---

### Adapter Type in Domain Signature

**What it is:** Domain types or port interfaces expose adapter-shaped types,
forcing the domain to know about the adapter's technology.

**Detection heuristics:**

- A port returns `IQueryable<T>`, `HttpResponseMessage`, `DataRow`, or another
  framework type.
- Domain methods accept `JObject`, `XmlElement`, or other parsing-layer types.
- A port exposes pagination using EF Core or Spring Data types instead of a
  domain-shaped result object.

**False positives:**

- `CancellationToken` / `IAsyncEnumerable<T>` / `Task<T>` are language-runtime
  primitives, not adapter types.
- `IReadOnlyList<T>` over domain types is fine.

**Severity:**

- **Critical** when the leak forces every adapter to share a common
  technology (e.g. all repositories must use EF Core because `IQueryable` is
  in the port).
- **Major** when one port leaks one adapter type.

**Before:**

```csharp
// Domain
public interface ICustomerRepository
{
    IQueryable<Customer> Query();
}
```

**After:**

```csharp
// Domain
public interface ICustomerRepository
{
    Task<Customer?> GetByIdAsync(CustomerId id, CancellationToken ct);
    Task<IReadOnlyList<Customer>> FindByCountryAsync(CountryCode iso, CancellationToken ct);
}
```

---

### Driving Adapter Bypassing Use Case

**What it is:** A driving adapter (HTTP controller, message handler, CLI)
manipulates domain entities directly instead of invoking a use case / primary
port. This drains the application's intent layer.

**Detection heuristics:**

- A controller takes a repository as a constructor argument (instead of a use
  case interface).
- A controller mutates entity properties and saves them via a repository,
  inline.
- Message handlers contain business logic instead of dispatching to a use
  case.

**False positives:**

- Simple read endpoints may legitimately call a query directly without a use
  case wrapping.
- CLI tools used only by operators may be thin.

**Severity:**

- **Critical** when business invariants are enforced in the driving adapter
  rather than the domain/use case.
- **Major** when use cases exist but the driving adapter skips them for some
  endpoints.

**Before:**

```csharp
[HttpPost("/customers/{id}/deactivate")]
public IActionResult Deactivate(Guid id)
{
    var c = _repo.Get(id);
    c.Active = false;            // business invariant set in controller
    c.DeactivatedAt = DateTime.UtcNow;
    _repo.Save(c);
    return Ok();
}
```

**After:**

```csharp
[HttpPost("/customers/{id}/deactivate")]
public async Task<IActionResult> Deactivate(Guid id)
{
    await _deactivateCustomer.Handle(new DeactivateCustomer(new CustomerId(id)));
    return Ok();
}

// Domain — invariant lives in the use case + entity
public class DeactivateCustomerHandler { ... }
```

---

### Speculative Port

**What it is:** A port introduced "in case we need to swap" with one trivial
implementation, no plausible second one, and a one-to-one mirror of the
adapter. Hexagonal must be applied where polymorphism earns its keep.

**Detection heuristics:**

- An interface has exactly one implementation and the method signatures match
  the implementation 1:1 with no abstraction gain.
- The interface was introduced in the same commit as its only implementation
  and has not gained a second since.
- Test doubles for the interface are also 1:1 mirrors (no behavior added).

**False positives:**

- Cross-cutting infrastructure (clock, ID generator) — a port is justified
  even with one production implementation, because tests need a fake.
- A port intended to swap providers for compliance (e.g. payments per region)
  is fine even before the second implementation exists, *if* the plan is
  recorded in an ADR.

**Severity:**

- **Minor** in most cases — over-engineering rather than risk.
- **Major** when speculative ports proliferate (≥ 5 in a module) and create
  navigation overhead.

**Before:**

```csharp
public interface ICustomerNameFormatter
{
    string Format(string first, string last);
}

public class CustomerNameFormatter : ICustomerNameFormatter
{
    public string Format(string first, string last) => $"{first} {last}";
}
```

**After:**

```csharp
public static class CustomerName
{
    public static string Format(string first, string last) => $"{first} {last}";
}
```

---

## Reporting

- File these findings under `Aspect: Architecture`.
- The `Rule` field uses the headings above verbatim: `Port Defined in Adapter`,
  `Adapter Type in Domain Signature`, `Driving Adapter Bypassing Use Case`,
  `Speculative Port`.
- Style-agnostic rules (Boundary Leak, Dependency Direction, etc.) keep their
  original names from `aspects/architecture.md`.
