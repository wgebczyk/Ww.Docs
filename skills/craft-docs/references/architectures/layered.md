# Architecture — Layered (N-Tier)

Load this file when the detected style is **Layered**.

Layered architecture organizes code into horizontal layers — typically
Presentation → Application → Domain → Data — with dependencies pointing
strictly downward. Each layer depends only on the layer directly below.

---

## Invariants

1. **Top-down dependencies only.** Higher layers depend on lower; lower layers
   never reference higher. No upward `using`/`import` statements; no upward
   project references.
2. **One concern per layer.** Presentation = HTTP/UI concerns. Application =
   orchestration of use cases. Domain = business rules. Data = persistence.
3. **Layer skipping is discouraged.** Presentation typically calls
   Application, not Domain or Data directly. (Strict variants forbid skipping;
   relaxed variants allow it for read-only paths — declare which in an ADR.)
4. **Persistence types stay in the Data layer.** ORM entities, framework
   attributes, and connection objects do not appear in Domain or Application
   signatures.

---

## Detection Signals

This file applies when the repo shows:

- Folders or projects named `Presentation` / `Web` / `Api` / `Controllers`,
  `Application` / `Services`, `Domain` / `Core` / `Models`, `Data` /
  `Persistence` / `Repositories` / `Infrastructure`.
- Project references form a strict top-down chain: `Web → Application →
  Domain`; `Data → Domain` (Data implements Domain interfaces).
- `using` / `import` graph respects the same direction.

If the repo declares "Layered" in `docs/craft-docs/curated/`, this file applies
regardless of folder naming.

---

## Style-Specific Rules

In addition to the style-agnostic rules in `aspects/architecture.md` (Boundary
Leak, Dependency Direction, Missing Public Boundary, Composition-Root Bleed),
file these:

### Upward Dependency

**What it is:** A lower layer references a type from a higher layer.

**Detection heuristics:**

- `Domain` types referencing `Application` services.
- `Data` types referencing `Application` or `Presentation`.
- Project file (`*.csproj`, `build.gradle`) shows the wrong direction.
- A repository depends on a use-case orchestrator.

**False positives:**

- A shared `Kernel`/`SharedKernel` package that all layers reference is fine
  if it contains only primitives and pure value objects.

**Severity:**

- **Critical** at the project-reference level.
- **Major** when only individual `using`/`import` lines violate.
- **Minor** when a single helper crosses upward in a non-critical path.

**Before:**

```csharp
// Domain/Customer.cs
public class Customer
{
    public void SendWelcome(IEmailService email) => email.Send(...); // domain calls Application
}
```

**After:**

```csharp
// Domain/Customer.cs                       — no Application reference
public class Customer { ... }

// Application/RegisterCustomerHandler.cs   — orchestrates
public class RegisterCustomerHandler
{
    public RegisterCustomerHandler(IEmailService email, ...) { ... }
    public void Handle(RegisterCommand cmd)
    {
        var customer = new Customer(cmd.Name, ...);
        _repo.Add(customer);
        _email.SendWelcome(customer.Email);
    }
}
```

---

### Anemic Domain Model

**What it is:** Domain classes are pure data containers (getters/setters with
no behavior), while business logic accumulates in Application services.
Common in layered codebases — the Domain layer becomes a folder of DTOs.

**Detection heuristics:**

- Domain types are records/POCOs with no methods beyond constructors and
  property accessors.
- Application services contain large `if/else` blocks operating on domain
  fields and writing them back.
- Validation logic lives in Application or Presentation rather than on the
  Domain entity.

**False positives:**

- A genuinely simple read model (CQRS read side) is correctly anemic.
- Persistence-shaped DTOs at the Data boundary are not Domain entities.

**Severity:**

- **Major** when business invariants are enforced outside the domain class
  and could be bypassed by a new caller.
- **Minor** when domain logic is light but invariants are enforced
  consistently in one application service.

**Before:**

```csharp
// Domain
public class Account { public decimal Balance { get; set; } }

// Application
public void Withdraw(Guid id, decimal amount)
{
    var a = _repo.Get(id);
    if (a.Balance < amount) throw new InsufficientFundsException();
    a.Balance -= amount;            // invariant lives outside the entity
    _repo.Save(a);
}
```

**After:**

```csharp
// Domain
public class Account
{
    public decimal Balance { get; private set; }
    public void Withdraw(decimal amount)
    {
        if (Balance < amount) throw new InsufficientFundsException();
        Balance -= amount;
    }
}

// Application
public void Withdraw(Guid id, decimal amount)
{
    var a = _repo.Get(id);
    a.Withdraw(amount);             // invariant enforced inside the entity
    _repo.Save(a);
}
```

---

### Repository Returning ORM Types

**What it is:** The repository's public surface returns persistence types
(`IQueryable<T>`, ORM entities decorated with `[Column]`/`[Index]`), causing
those types to spread upward into Application and Presentation.

**Detection heuristics:**

- Repository method signatures expose `IQueryable<T>` to callers in higher
  layers.
- Domain entity types carry ORM attributes (`[Table]`, `[Key]`, `[Column]`).
- Lazy-loading proxies are observable in Application or Presentation code.

**False positives:**

- A repository internally uses ORM types — only flag when they leak out.

**Severity:**

- **Critical** when `IQueryable` crosses out of the Data layer (caller can
  compose queries against the database, breaking encapsulation).
- **Major** when domain types are decorated with ORM attributes but signatures
  use them only in the Data layer.
- **Minor** when a single repository returns an entity type that happens to
  coincide with the domain type and no leakage propagates.

> Closely related to the style-agnostic `Boundary Leak` rule in
> `aspects/architecture.md`. File this rule (`Repository Returning ORM
> Types`) only when the issue is specifically at the Data/Domain layer
> seam; otherwise file the generic `Boundary Leak`.

**Before:**

```csharp
public interface ICustomerRepository
{
    IQueryable<Customer> Query();                     // exposes EF query surface
}
```

**After:**

```csharp
public interface ICustomerRepository
{
    Task<Customer?> GetByIdAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<Customer>> FindByCountryAsync(string iso, CancellationToken ct);
}
```

---

## Reporting

- File these findings under `Aspect: Architecture`.
- The `Rule` field uses the headings above verbatim: `Upward Dependency`,
  `Anemic Domain Model`, `Repository Returning ORM Types`.
- Style-agnostic rules from `aspects/architecture.md` keep their original
  rule names.
