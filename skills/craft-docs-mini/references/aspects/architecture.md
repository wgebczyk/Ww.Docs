# Aspect — Architecture

Architecture is the **first** analysis pass. Structural violations subsume SOLID and clean-code findings — grade architecture first, then descend to later passes.

**Actions for this file:**
1. Detect the architectural style for each module/repo (see Style Detection below).
2. Load **only** the matching `architectures/{style}.md` — do not mix rules from multiple style files.
3. Apply style-agnostic rules (below) to every module regardless of style.

---

## Style Detection

For each repo (or module, if the repo mixes styles), pick **exactly one**
primary style using the strongest matching signal. If signals are weak or
contradictory, set the style to `Unclear` and grade only the style-agnostic
rules below.

| Style | Strongest signal | Detection file |
|---|---|---|
| **Layered** | Folders named `Presentation/`, `Application/`, `Domain/`, `Data/` (or n-tier equivalents like `Controllers/`, `Services/`, `Repositories/`, `Models/`). Project references form a top-down chain. | `architectures/layered.md` |
| **Hexagonal (Ports and Adapters)** | Domain depends only on abstractions; adapters live in separate projects/folders (`adapters/in/`, `adapters/out/`, or `*.Driving.*`, `*.Driven.*`); ports are interfaces in the domain. | `architectures/hexagonal.md` |
| **Clean Architecture** | Concentric ring layout: `Entities`, `UseCases`/`Application`, `InterfaceAdapters`, `Frameworks`. The dependency rule points inward. Often combined with hexagonal naming. | `architectures/clean-architecture.md` |
| **Vertical Slice / Feature Folders** | Top-level folders named after features (`Features/Billing/`, `Features/Onboarding/`), each containing its own commands, queries, validators, and DTOs. | `architectures/vertical-slice.md` |
| **Event-Driven / CQRS** | Explicit `Events/`, `Handlers/`, message bus wiring (`IMediator`, `IPublishEndpoint`, NServiceBus, MassTransit). Separation between command and query stacks. | `architectures/event-driven.md` |

Style detection rules:

- A repository may declare its style in `docs/craft-docs/curated/` — that takes
  precedence over signal-based detection. Cite the curated file.
- If two styles are signaled equally (e.g. layered project layout with vertical
  slice folders inside), pick the **inner** style for module analysis and note
  the outer style in `Design (Recovered)`.
- If detection yields `Unclear`, file a Major architecture finding with:
  - **Rule:** `Unclear Architecture Style`
  - **Evidence:** "Module organization mixes {observed signals}. No coherent primary style detected."
  - **Suggested refactor:** "Declare an intended architecture style in an ADR under `docs/craft-docs/curated/adrs/`."

---

## Style-Agnostic Rules

These rules apply regardless of style. They live here (not in clean-code or
SOLID) because they are architectural in nature.

---

### Boundary Leak

**What it is:** Types belonging to one architectural region (infrastructure,
framework, persistence, external SDK) appear in the public surface of another
region (domain, application, public API).

**Detection heuristics:**

- ORM entity types appear in API response shapes or service interfaces.
- `IQueryable<T>` returned from a service interface that crosses a layer
  boundary.
- Framework attributes (`[HttpPost]`, `@RestController`, `@Entity`) on classes
  in a region that should not know about that framework.
- External SDK types (`AWS.S3.Object`, `Stripe.Charge`, `HttpResponseMessage`)
  appearing in business signatures.
- Database column attributes (`[Column]`, `[Index]`) on DTOs returned to UI.

**False positives:**

- Repository implementations are *expected* to know ORM types internally — only
  flag when types leak out of the repository's public surface.
- A `Program.cs`/`Startup.cs`/composition root is expected to know concrete
  framework types.
- Generated API client types appearing in their consumer's adapter layer are
  fine.

**Severity:**

- **Critical** when an outward layer (controller, API contract, public
  package) takes a transitive dependency on infrastructure through the leak.
- **Major** when the leak is contained to one module's public surface.
- **Minor** when internal types use framework features that don't escape.

**Before:**

```csharp
// In a domain service interface
public interface IBillingService
{
    IQueryable<InvoiceEntity> GetUnpaid(Guid customerId); // leaks EF + entity
}
```

**After:**

```csharp
public interface IBillingService
{
    Task<IReadOnlyList<Invoice>> GetUnpaidAsync(Guid customerId, CancellationToken ct);
}
```

---

### Dependency Direction Violation

**What it is:** A module that should not know about another module imports or
references it directly, contradicting the declared architectural style's
dependency rule (e.g. domain depends on infrastructure; an inner ring depends
on an outer ring).

**Detection heuristics:**

- Project reference graph (`*.csproj` `ProjectReference`, `build.gradle`
  `implementation project`, `package.json` workspace links) contains a back-edge
  against the style's intended direction.
- Imports/usings in a "lower" layer point at types in a "higher" layer.
- An interface defined in an outer ring is implemented in an inner ring (the
  interface is in the wrong place — defining it outward inverts the dependency
  rule).

**False positives:**

- **Composition root** is allowed to depend on everything.
- **Test projects** are allowed to depend on production projects regardless of
  layer.
- Cross-cutting **logging or telemetry abstractions** declared in a shared
  package are not a back-edge if the abstraction is genuinely shared.

**Severity:**

- **Critical** when the back-edge exists at the project-reference level (the
  build graph is wrong).
- **Major** when only individual `using`/`import` statements break the rule but
  the project graph is clean.
- **Minor** when a single static helper crosses the boundary and is contained.

**Before:**

```text
Domain.csproj
  └─ ProjectReference: Infrastructure.Persistence.csproj   ← back-edge
```

**After:**

```text
Domain.csproj                         (defines IInvoiceRepository)
Infrastructure.Persistence.csproj     (references Domain, implements interface)
Composition.csproj                    (references both, wires DI)
```

---

### Missing Public Boundary

**What it is:** A module has no clearly defined public surface. Every type in
the module is `public` (or default-public), so consumers can reach into
internals.

**Detection heuristics:**

- A module exposes > 80% of its types as public/exported.
- No `internal`/`package-private`/`pub(crate)` modifier appears in a module
  large enough to need encapsulation (> 10 types).
- A module's `index.ts` / `__init__.py` / `mod.rs` re-exports everything
  recursively rather than curating a public surface.
- Other modules import deep paths like `module/internal/details/X` instead of
  the module root.

**False positives:**

- A library whose entire purpose is to expose utilities (e.g. a string-utils
  package) is meant to be all-public.
- A single-file module is too small to warrant a public/internal split.

**Severity:**

- **Major** when the missing boundary causes consumers to reach into internals
  in 2+ places.
- **Minor** when it is a hygiene issue but no consumer takes advantage.

**Before:**

```typescript
// module/index.ts
export * from "./services/internal/cache-impl";   // internal leak
export * from "./services/billing-service";
```

**After:**

```typescript
// module/index.ts
export { BillingService } from "./services/billing-service";
// cache-impl stays internal — not re-exported
```

---

### Composition-Root Bleed

**What it is:** Composition concerns (DI registration, configuration parsing,
factory wiring) leak out of the composition root into business modules.

**Detection heuristics:**

- Domain or application classes call `container.Resolve<T>()`,
  `serviceProvider.GetService<T>()`, or the equivalent (service locator
  anti-pattern).
- A business module owns its own DI registration extension method *and* that
  method registers types from other modules.
- Configuration objects (`IConfiguration`, environment variables) are read
  inside business logic instead of at the composition root and passed in.

**False positives:**

- **Modular DI**: each module exposing an `AddXyz(IServiceCollection)` extension
  to register *its own* types is good practice, not a violation.
- **Lazy/scoped factories** legitimately use the container at runtime to create
  per-request instances.

**Severity:**

- **Major** when service-location appears in business logic.
- **Minor** when configuration is read from a static helper in a non-business
  utility.

**Before:**

```csharp
public class OrderProcessor
{
    public void Process(Order o)
    {
        var clock = ServiceLocator.Resolve<IClock>(); // service location
        ...
    }
}
```

**After:**

```csharp
public class OrderProcessor
{
    private readonly IClock _clock;
    public OrderProcessor(IClock clock) => _clock = clock;
    public void Process(Order o) { ... }
}
```

---

## Output Rules

When writing architecture findings to a module page or to
`reports/architecture-findings.md`:

- Use the per-finding structure in `output-format.md`.
- The `Rule` field must be one of: `Boundary Leak`, `Dependency Direction`,
  `Missing Public Boundary`, `Composition-Root Bleed`, or a style-specific rule
  from the matching `architectures/{style}.md`.
- If a finding could equally be filed as SOLID (e.g. DIP) or clean-code
  (e.g. Boundary Leak under clean code), **keep it here**. Architecture
  subsumes downstream aspects per the analysis order. Do not duplicate.
