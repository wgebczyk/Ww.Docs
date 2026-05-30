# Aspect — Testability

Testability is the **fourth** analysis pass. Apply after Architecture, SOLID, and Clean Code. File only findings whose root cause is not already covered by an earlier pass.

**CONSTRAINT [HARD-FORMAT]:** Every finding uses the per-finding structure from `output-format.md` with `Aspect: Testability` and `Rule:` verbatim from the rule headings below.

**Routing rules (do not double-file):**

| Situation | File under |
|---|---|
| Hidden infrastructure dependency where the root cause is a dependency-direction violation | `SOLID — DIP` or `Architecture — Dependency Direction` |
| Hidden infrastructure dependency observable only via test difficulty | `Testability — Hidden Dependency` |
| Composition-Root Bleed (service locator in business logic) that also blocks testing | `Architecture — Composition-Root Bleed` (mention testability impact in Evidence, not a separate finding) |

---

## Hidden Dependency

**What it is:** A unit under test reaches out to a dependency that isn't
visible in its signature — typically time, randomness, environment, the file
system, or a singleton — making the unit non-deterministic or impossible to
exercise in isolation.

**Detection heuristics:**

- `DateTime.Now` / `Time.now()` / `Date.now()` / `time.time()` called inside
  business logic.
- `Guid.NewGuid()` / `uuid.uuid4()` called in a place where the ID is part of
  the observable behavior.
- `new Random()` inside a method body, not injected.
- `File.ReadAllText` / `open(...)` / `Path.Read` in code outside an adapter.
- `Environment.GetEnvironmentVariable` / `process.env.X` accessed in business
  logic.
- Singletons (`X.Instance`) accessed from inside a method body rather than
  injected.

**False positives:**

- Adapter implementations are *meant* to call these primitives — that is their
  responsibility.
- Logging libraries accessed via static loggers are typically fine; tests
  rarely need to assert on log output.
- A pure `Guid.NewGuid()` used only for cache keys or internal correlation
  IDs (not exposed) doesn't materially hurt testability.

**Severity:**

- **Critical** when a domain rule cannot be unit-tested at all because of the
  hidden dependency.
- **Major** when the test is possible but requires global setup
  (freezing time globally, monkeypatching, environment manipulation).
- **Minor** when the hidden dependency is in a non-business utility and tests
  pass reliably anyway.

**Before:**

```csharp
public class Subscription
{
    public bool IsExpired() => DateTime.UtcNow > ExpiresAt;
}
```

**After:**

```csharp
public class Subscription
{
    public bool IsExpiredAt(DateTimeOffset now) => now > ExpiresAt;
}
// Caller (composition or application service) supplies clock-based "now".
```

---

## Hard-to-Substitute Collaborator

**What it is:** A collaborator cannot be replaced in tests without elaborate
machinery — because it is a `sealed`/`final` concrete type, has no
extractable interface, or is constructed in-place rather than injected.

**Detection heuristics:**

- A class under test news up its collaborators in its constructor or methods
  (`var x = new ConcreteX(...)`) instead of taking them as parameters.
- A collaborator is `sealed`/`final`/non-virtual and has no extracted
  interface; tests resort to subclassing/monkeypatching the language to fake
  it.
- The test project depends on a heavyweight mock framework specifically
  because the production type is impossible to fake directly (e.g. mocking
  `HttpClient` instead of an abstraction over it).
- A static method or extension method is the only entry point to a behavior
  that varies between environments.

**False positives:**

- Value objects, DTOs, and immutable records are intentionally newed up
  in-place — they don't need an interface.
- Standard-library primitives (`StringBuilder`, `Stopwatch`) are fine as
  concrete types.

**Severity:**

- **Critical** when a system seam (used by ≥ 3 callers) has no replaceable
  abstraction and tests have to spin up the real dependency.
- **Major** when one or two places require awkward test setup and a small
  refactor would extract a clean seam.
- **Minor** when a single test has slight discomfort but the production
  design is otherwise clean.

**Before:**

```python
class OrderProcessor:
    def process(self, order):
        client = StripeClient(api_key=os.environ["STRIPE_KEY"])  # newed up here
        client.charge(order.total, order.customer.token)
```

**After:**

```python
class OrderProcessor:
    def __init__(self, payments: PaymentGateway):
        self._payments = payments

    def process(self, order):
        self._payments.charge(order.total, order.customer.token)
```

---

## Constructor Over-Injection

**What it is:** A class takes too many dependencies in its constructor,
signaling that the class itself has too many responsibilities — and making
tests verbose with long mock setup lists.

**Detection heuristics:**

- Constructor takes > 5 dependencies (excluding plain config/value objects).
- Test setup for the class has > 5 mock instantiations.
- The constructor signature has changed > 3 times in the last 12 months (when
  history is available) — usually because every new feature adds a dependency.

**False positives:**

- Composition-root types and facades legitimately wire many things.
- Aggregate roots in DDD may take several collaborating value objects.

**Severity:**

- **Major** in most cases — it's a code-smell pointing at SRP.
- **Critical** if the same class has > 10 dependencies and tests are routinely
  skipped or marked flaky because of setup complexity.
- **Minor** rarely — only if the dependencies are all small, related, and the
  class has clear cohesion.

> When constructor over-injection is the surface symptom of an SRP violation,
> file the SOLID — SRP finding instead, and only mention testability impact in
> its Evidence. The analysis order applies.

**Before:**

```csharp
public OrderService(
    IOrderRepo repo, IUserRepo users, IEmailSender email,
    ISmsSender sms, IPushSender push, IInvoiceRenderer invoices,
    IAuditLog audit, IMetrics metrics, IClock clock, IIdGenerator ids)
{ ... }
```

**After (split by responsibility):**

```csharp
public class OrderService(IOrderRepo repo, IUserRepo users, IClock clock, IIdGenerator ids) { ... }
public class OrderNotifier(IEmailSender email, ISmsSender sms, IPushSender push) { ... }
public class OrderAuditor(IAuditLog audit, IMetrics metrics) { ... }
public class OrderDocumentService(IInvoiceRenderer invoices) { ... }
```

---

## Side Effects in Constructor

**What it is:** A constructor performs I/O, network calls, mutation of global
state, or long-running initialization. Tests can't instantiate the type
without standing the side effect up.

**Detection heuristics:**

- A constructor calls a method on an injected dependency that performs I/O
  (`db.Open()`, `client.Connect()`, `file.Read()`).
- A constructor reads configuration, hits the network, or queries the DB.
- A constructor subscribes to events or starts a background timer.
- A constructor mutates a static field.

**False positives:**

- Trivial assignments and null-checks are fine.
- A factory method that performs initialization and returns a fully-built
  object is not a constructor side-effect (the side effect is explicit and
  testable separately).

**Severity:**

- **Critical** when the class cannot be `new`-ed in a unit test without
  pre-arranging external state.
- **Major** when the side effect is internal mutation that complicates ordering
  in tests.
- **Minor** when the side effect is logging-only and tests don't care.

**Before:**

```typescript
class CacheClient {
    private connection: Connection;
    constructor(url: string) {
        this.connection = openConnection(url);   // network in ctor
        this.connection.subscribe("evict", this.onEvict);
    }
}
```

**After:**

```typescript
class CacheClient {
    constructor(private connection: Connection) {}

    async start(): Promise<void> {
        await this.connection.subscribe("evict", this.onEvict);
    }
}
// Composition root: const c = new CacheClient(await openConnection(url)); await c.start();
```

---

## Test-Only Public Surface

**What it is:** Production code exposes members as `public` / `internal` /
`@VisibleForTesting` solely to enable tests, leaking internals to production
consumers.

**Detection heuristics:**

- A `public`/`internal` member is called only from tests (per find-references).
- `@VisibleForTesting` annotations on a non-trivial number of members
  (> 3 in one class).
- A test calls a setter to install state that the constructor should have
  taken.
- `internal` types in .NET exposed via `[InternalsVisibleTo("...Tests")]` for
  more than a thin slice of types.

**False positives:**

- `@VisibleForTesting` on a single seam where the production design would
  otherwise be worse is acceptable; record as Minor.
- Public factory methods used by both tests and production are fine.

**Severity:**

- **Major** when ≥ 3 members are public-for-tests in one class, signaling the
  class needs an extracted seam.
- **Minor** when isolated to one accessor on one class.

**Before:**

```csharp
public class CommandHandler
{
    internal Queue<DomainEvent> EventsForTesting => _events;     // test-only

    private readonly Queue<DomainEvent> _events = new();
    ...
}
```

**After:**

```csharp
public class CommandHandler
{
    private readonly IEventStore _events;
    public CommandHandler(IEventStore events) => _events = events;
    ...
}
// Tests inject an in-memory IEventStore and assert against it directly.
```

---

## Brittle Test Smell (production-driven)

**What it is:** Tests pass today but are brittle in a way that points at a
production-side design problem (not a test-quality problem). Examples: extreme
mock-heaviness, large shared fixtures, tests that fail on unrelated changes.

This rule fires only when the *production* refactor would remove the brittleness.
Pure test-quality issues are out of scope for craft-docs.

**Detection heuristics:**

- A test mocks > 5 collaborators to exercise a single method — usually
  Constructor Over-Injection or SRP.
- A shared mutable test fixture is the only way to set up the system under
  test (no constructor seam).
- A change to one feature breaks tests for unrelated features — usually a
  Boundary Leak or shared-state issue.
- Test files routinely reach into `private` via reflection.

**False positives:**

- Integration tests legitimately stand up real dependencies.
- End-to-end tests legitimately have long setup.

**Severity:**

- **Major** when the pattern repeats across ≥ 3 test files for the same
  module.
- **Minor** when it appears in one file and a small production tweak resolves
  it.

**Before:**

```python
# Single unit test sets up six mocks just to call one method.
def test_create_order(mocker):
    mocker.patch("OrderService.repo")
    mocker.patch("OrderService.users")
    mocker.patch("OrderService.email")
    mocker.patch("OrderService.sms")
    mocker.patch("OrderService.audit")
    mocker.patch("OrderService.clock")
    svc = OrderService()
    svc.create_order(...)
```

**After:**

```python
# OrderService now has 4 collaborators. Notification + audit moved out.
def test_create_order():
    repo, users, clock, ids = InMemoryOrderRepo(), FakeUsers(), FakeClock(t0), FakeIds(seed=1)
    svc = OrderService(repo, users, clock, ids)
    svc.create_order(...)
    assert repo.saved == [...]
```

---

## Output Rules

- Use the per-finding structure from `output-format.md`.
- `Aspect: Testability` and `Rule:` is exactly one of the headings above.
- If the underlying cause is structural (Architecture) or principle-level
  (SOLID), file the finding there per the analysis order and only mention
  testability impact in Evidence.
- Tests themselves are not the subject of this aspect — production code is.
  Bad tests are filed only when fixing them requires changing production.
