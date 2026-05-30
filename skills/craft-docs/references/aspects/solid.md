# Aspect — SOLID

SOLID is the **second** analysis pass. Apply after Architecture. Skip any finding whose root cause was already filed as an Architecture violation.

**CONSTRAINT [HARD-FORMAT]:** Every finding uses the per-finding structure from `output-format.md` with `Aspect: SOLID` and `Rule:` exactly one of `SRP | OCP | LSP | ISP | DIP`.

---

## SRP — Single Responsibility Principle

**What it is:** A class or module has one reason to change — one stakeholder,
one axis of variation.

**Detection heuristics:**

- Public methods cluster into ≥ 2 cohesion groups by collaborator set (half
  touch persistence, half format presentation).
- Method names contain "And"/"Or" or two verbs (`SaveAndNotify`).
- The file imports both persistence types *and* presentation/format types.
- > 7 public methods on a class whose dependencies span ≥ 2 architectural layers.
- High git churn from unrelated tickets touching the same file (when history
  is available).

**False positives:**

- Facades that compose other types and hold no logic are fine.
- DTOs with many fields have one responsibility: carry data.
- Composition roots wire many things — that's their job.
- Aggregate-root repositories may have many methods around a single axis.

**Severity:**

- **Critical** when the conflated class is a system seam (≥ 3 callers) and
  conflation actively blocks testing or causes multi-team change collisions.
- **Major** when conflation is local and refactor is feasible but not yet
  painful.
- **Minor** when two trivial responsibilities share state and the cost of
  splitting exceeds the value.

**Before:**

```csharp
public class CustomerService
{
    public Customer GetById(Guid id) { ... }                    // read
    public void Save(Customer c) { ... }                        // write
    public string FormatForEmail(Customer c) { ... }            // presentation
    public byte[] ExportCsv(IEnumerable<Customer> all) { ... }  // export
}
```

**After:**

```csharp
public class CustomerRepository { Customer GetById(...); void Save(...); }
public class CustomerEmailFormatter { string FormatForEmail(...); }
public class CustomerCsvExporter   { byte[] Export(...); }
```

---

## OCP — Open/Closed Principle

**What it is:** Modules are open for extension and closed for modification.
Adding a new behavior should not require editing existing tested code paths.

**Detection heuristics:**

- `switch` / `if-else` ladders dispatching on a type discriminator (`enum`,
  `kind` string) that grow each time a new case is added.
- `typeof` / `is` / `instanceof` / `isinstance` chains in business logic.
- A "registry" function that must be edited for every new behavior.
- A god factory whose body must be modified for every new product type.

**False positives:**

- Switch over a **truly closed** algebraic type (e.g. `Result.Success | Result.Failure`)
  is clearer than polymorphism.
- A parser dispatching on a token kind is expected to be a long switch.
- Performance-critical hot paths may legitimately prefer switch over virtual
  dispatch.

**Severity:**

- **Critical** when the dispatch site is touched by every new feature and merge
  conflicts/regressions are observable in git history.
- **Major** when dispatch is occasionally edited and adding a case requires
  modifying tested code.
- **Minor** when the dispatched set is closed with fixed cardinality.

**Before:**

```csharp
public decimal CalculatePrice(Product p) =>
    p.Kind switch
    {
        ProductKind.Book      => p.BasePrice * 0.9m,
        ProductKind.Software  => p.BasePrice,
        ProductKind.Hardware  => p.BasePrice * 1.2m + ShippingFor(p),
        // every new kind = edit this switch + new method below
        _ => throw new NotSupportedException()
    };
```

**After:**

```csharp
public interface IPricingRule { decimal Apply(Product p); }
public class BookPricing     : IPricingRule { ... }
public class SoftwarePricing : IPricingRule { ... }
public class HardwarePricing : IPricingRule { ... }

// composition root maps ProductKind → IPricingRule
public decimal CalculatePrice(Product p) => _rules[p.Kind].Apply(p);
```

---

## LSP — Liskov Substitution Principle

**What it is:** A subtype is usable wherever its supertype is used without
violating contracts. Subtypes do not strengthen preconditions, weaken
postconditions, or break invariants.

**Detection heuristics:**

- A subclass overrides a method to throw `NotSupportedException` /
  `NotImplementedError`.
- A subclass returns `null` where the base guarantees a value (or vice versa).
- A type-check in a caller specializes behavior per subclass — the hierarchy is
  leaking.
- A subclass adds hidden state requirements (`Init` must be called first) not
  present in the base contract.

**False positives:**

- A sealed/final partial implementation with explicit "not supported" intent
  *and* a base type designed for it (e.g. `ReadOnlyCollection` over a base
  collection) is documented behavior — not LSP harm.
- Methods explicitly documented as optional in the base contract.

**Severity:**

- **Critical** when production code branches on subtype or experiences runtime
  exceptions from substitution.
- **Major** when substitution works in observed call sites but contract drift
  is real and a new caller could trigger failure.
- **Minor** when contract narrowing is documented and used only in test
  fixtures.

**Before:**

```csharp
public class Rectangle { public virtual void SetWidth(int w); public virtual void SetHeight(int h); }
public class Square : Rectangle
{
    public override void SetWidth(int w)  { base.SetWidth(w);  base.SetHeight(w); }
    public override void SetHeight(int h) { base.SetWidth(h);  base.SetHeight(h); }
}
// Callers expecting Rectangle.SetWidth(5) to leave Height unchanged break here.
```

**After:**

```csharp
public interface IShape { int Area(); }
public class Rectangle : IShape { ... }
public class Square    : IShape { ... }
// No subtype relationship between Rectangle and Square.
```

---

## ISP — Interface Segregation Principle

**What it is:** Clients are not forced to depend on methods they don't use.
Prefer many small, role-based interfaces over one fat interface.

**Detection heuristics:**

- A consumer uses < 30% of an interface's members.
- Multiple implementations throw `NotSupportedException` for a subset of
  methods.
- An interface mixing read and write contracts (`IUserRepo` with `GetById`
  *and* `Save`) when some callers only need half.
- A "service" interface with > 10 unrelated methods that has one production
  implementation and many test doubles each stubbing only a slice.

**False positives:**

- A role interface that intentionally aggregates related capabilities
  (`IDisposable`, `IAsyncDisposable`) is not over-broad.
- An interface used by a single consumer that doesn't call every member is
  fine.

**Severity:**

- **Critical** when the fat interface forces unrelated consumers to redeploy
  when one method changes (binary breaking changes).
- **Major** when test doubles stubbing the interface routinely have empty
  implementations for half the methods.
- **Minor** when an interface has a few unused methods per client but cohesion
  is otherwise high.

**Before:**

```csharp
public interface IOrderService
{
    Order GetById(Guid id);
    void Create(Order o);
    void Cancel(Guid id);
    byte[] ExportPdf(Guid id);          // only the reporting module uses this
    void RebuildSearchIndex();           // only the admin tool uses this
}
```

**After:**

```csharp
public interface IOrderReader   { Order GetById(Guid id); }
public interface IOrderWriter   { void Create(Order o); void Cancel(Guid id); }
public interface IOrderReporter { byte[] ExportPdf(Guid id); }
public interface IOrderAdmin    { void RebuildSearchIndex(); }
```

---

## DIP — Dependency Inversion Principle

**What it is:** High-level modules depend on abstractions; abstractions don't
depend on details. In practice: domain depends on interfaces; infrastructure
implements; composition wires.

**Detection heuristics:**

- Domain/business class instantiates an infrastructure type directly
  (`new SqlConnection(...)`, `new HttpClient(...)`, `File.ReadAllText(...)`).
- Domain takes a concrete infrastructure type as a constructor argument when
  an interface exists.
- Static helpers performing I/O called from business rules (`DateTime.Now`,
  `Environment.GetEnvironmentVariable`, `Guid.NewGuid`).
- The repository implementation is typed as the concrete EF Core/NHibernate
  context throughout consuming code.

**False positives:**

- Composition roots are *supposed* to know concrete types.
- Standard-library value types (`DateTime`, `Guid`, `string`) are not
  infrastructure for DIP purposes (but `DateTime.Now` is — it's I/O).
- A clock abstraction is only needed where business logic depends on time;
  pure formatters don't need one.

**Severity:**

- **Critical** when a domain rule cannot be unit-tested without infrastructure,
  or the project-reference graph is genuinely inverted
  (`Domain.csproj → Infrastructure.csproj`). The latter is also an Architecture
  finding — file it there per the analysis order.
- **Major** when a specific class hard-binds an infrastructure dependency; the
  rest of the module is clean.
- **Minor** when a non-business utility (logging) is taken concretely.

> **Cross-reference:** Hidden infrastructure dependencies that affect testability
> are also covered in `aspects/testability.md` under "Hidden Dependency". File
> the finding under DIP if the dependency direction is the root issue, or under
> Testability if the rule is observable only via tests. Do not file both.

**Before:**

```csharp
public class InvoiceService
{
    public void IssueInvoice(Order o)
    {
        var now = DateTime.UtcNow;                                        // hidden I/O
        using var conn = new SqlConnection(Config.GetConnString());       // hidden infra
        conn.Execute("INSERT INTO Invoices ...", new { ..., IssuedAt = now });
    }
}
```

**After:**

```csharp
public class InvoiceService
{
    private readonly IClock _clock;
    private readonly IInvoiceRepository _repo;
    public InvoiceService(IClock clock, IInvoiceRepository repo) { _clock = clock; _repo = repo; }

    public Task IssueInvoiceAsync(Order o) =>
        _repo.AddAsync(new Invoice(o.Id, _clock.UtcNow));
}
```

---

## Output Rules

- Use the per-finding structure from `output-format.md`.
- `Aspect: SOLID` and `Rule:` is exactly one of `SRP / OCP / LSP / ISP / DIP`.
- If the underlying issue is an architecture-style violation (e.g. DIP failure
  where domain imports infrastructure at the project level), file it as
  Architecture instead. The analysis order requires structural findings first;
  do not file the same issue twice.
- If a curated ADR accepts a deviation, record it under the module page's
  "Accepted Trade-offs" section with ADR citation and do not write a finding.
