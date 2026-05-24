# Module Heuristics

Rules for detecting technology stacks and deriving module boundaries from them.
Apply these in order during both Init and Update modes.

These heuristics optimize search scope. They do not replace source verification.

---

## Step 0 — Hypothesis and Craft Risk Framing

Before stack/module detection, derive a hypothesis set from curated and
generated docs.

For each requested question or topic:

1. Extract intended design, ADR decisions, and known trade-offs from:
   - `docs/craft-docs/curated/**/*.md` (design notes, ADRs, glossary)
   - `docs/craft-docs/pages/**/*.md` (if present)
2. Convert them into explicit hypotheses (for example: "the billing module
   depends only on abstractions in `IBillingPolicy`, never on concrete EF
   types").
3. Mark high-risk craft categories that always require deeper expansion checks:
   - layering boundaries (domain ↔ infrastructure)
   - public API surface of cross-team modules
   - shared utilities and base classes with wide blast radius
   - error-handling discipline at process boundaries
   - test seams that drive production design
   - cross-cutting concerns wired via DI / reflection
4. Use Steps 1-3 below to narrow where to inspect code first.
5. After narrowed inspection, run expansion checks (DI wiring, partial classes,
   extension methods, reflection, source generators, tests).

---

## Step 1 — Detect Repository Technology Stack

For each repository root, check for the following indicator files using Glob.
Apply the **first matching rule** (most specific first).

| Priority | Indicator file(s) | Stack |
|---|---|---|
| 1 | `*.sln` or `*.slnx` at root | **.NET multi-project solution** |
| 2 | `*.csproj` at root (no solution) | **.NET single project** |
| 3 | `angular.json` at root | **Angular** |
| 4 | `package.json` with `"workspaces"` key | **Node.js monorepo** |
| 5 | `package.json` without `"workspaces"` | **Node.js single package** |
| 6 | `pyproject.toml` or `setup.py` at root | **Python** |
| 7 | `go.mod` at root | **Go** |
| 8 | `Cargo.toml` at root | **Rust** |
| 9 | `pom.xml` at root | **Java (Maven)** |
| 10 | `build.gradle` or `build.gradle.kts` at root | **Java/Kotlin (Gradle)** |
| 11 | *(none of the above)* | **Fallback** |

A repository may contain secondary stacks in subdirectories (e.g. a .NET API
with an Angular client in `client/`). Detect the primary stack from the root.
If a subdirectory has its own `angular.json` or `package.json`, treat it as a
nested repo and analyze it separately under the same parent repo name.

---

## Step 2 — Derive Module Boundaries

Apply the rule for the detected stack.

After detecting module boundaries, generate a module page slug with this required format:

- `{repo-name}-{module-name}`
- lowercase kebab-case only

De-duplication rule:

- If repo slug ends with token `X` and module slug starts with token `X`, remove the repeated leading module token.
- Example: `cold-wave-api` + `api-host` => `cold-wave-api-host`.

When mapping changes in Update mode:

- map changed files to modules using the same boundary rules,
- then re-read the full module before rewriting docs,
- rebuild slug using the naming rule,
- and verify whether any shared design topic evidence changed.

### .NET Multi-Project Solution (vertical slice architecture)

**Module = top-level domain folder** as listed in the `.sln` / `.slnx` file.

Detection:
1. Read the solution file to extract all project references.
2. Group projects by their top-level parent directory.
3. Each group = one module. Name the module after the folder.

Key files to read within each domain folder (for craft recovery, not just structure):

| File pattern | What it reveals |
|---|---|
| `**/DependencyInjection.cs` | Module's public contracts, seams, DIP discipline |
| `**/*DbContext.cs` or `**/I*DbContext.cs` | Data boundary and persistence leakage |
| `**/Commands/**/*.cs`, `**/Queries/**/*.cs` | SRP per handler, function size, error handling |
| `**/Events/**/*.cs` or `**/Handlers/**/*.cs` | Event-driven seams, OCP behavior |
| `**/*Controller.cs` or `**/*Endpoint.cs` | Boundary leak surface |
| `**/Abstractions/`, `**/Interfaces/` | ISP discipline, role-based vs fat interfaces |
| `**/Extensions/*.cs` | Cross-boundary extension methods, hidden coupling |
| Top-level model/entity files | Domain concepts, naming consistency |

Test projects (`*.Tests`, `*.UnitTests`, `*.IntegrationTests`): read for craft
signals — they reveal test smells (excessive mocking, shared mutable fixtures,
test-driven design pressure that points back to production violations). Do not
create separate module pages for test projects.

**Split threshold**: if a domain folder has > 30 non-test source files, create:
- `modules/{repo-module-slug}.md` — overview with table of contents
- `modules/{repo-module-slug}-commands.md` — command handlers
- `modules/{repo-module-slug}-queries.md` — query handlers
- `modules/{repo-module-slug}-infrastructure.md` — persistence / external integrations

### .NET Single Project

**Module = each logical namespace** that contains more than 3 public types.

Read: `Program.cs`, all public classes and interfaces grouped by namespace.

### Angular

**Module = each folder under `src/app/features/`**. Also treat `src/app/shared/`
as one additional module named "Shared".

Key files to read per feature folder:

| File pattern | What it reveals |
|---|---|
| `routes.ts` or `*-routing.module.ts` | Navigation surface |
| `*api*.service.ts` or `*http*.service.ts` | Backend boundary, DIP discipline |
| `*.model.ts` or `*.types.ts` | Naming, type coupling |
| `screens/**/*.component.ts` | Component cohesion (SRP), size |
| `store/**/*.ts` or `*facade*.ts` | State ownership, DIP |

### Node.js Monorepo

**Module = each workspace package** listed in the root `package.json` `"workspaces"` array.

Read per package: `package.json` (name, description, exports — public surface),
`src/index.ts` or `index.ts`, top-level `src/` subdirectories.

### Node.js Single Package

**Module = each top-level subdirectory under `src/`** that contains more than 3 files.

Read: `src/index.ts`, route files, service files, model files.

### Python

**Module = each top-level directory containing `__init__.py`**.

Read per module: `__init__.py` (re-exports = public surface), all `.py` files
in the directory. Note: do not descend into `tests/` or `test_*` directories
for module pages (use for craft insights only).

### Go

**Module = each package directory** (directory containing `.go` files).

Exclude `vendor/` and `_test` files from the module page; read tests for craft
insights.

### Rust

**Module = each crate** listed in `[workspace.members]` in the root `Cargo.toml`.
For non-workspace repos, treat the single crate as one module.

Read: `src/lib.rs` or `src/main.rs`, public items in `src/`.

### Java (Maven)

**Module = each Maven submodule** (directory containing its own `pom.xml`).

Read: `pom.xml` (artifactId, dependencies), main entry class, public service /
repository interfaces.

### Java/Kotlin (Gradle)

**Module = each Gradle subproject** listed in `settings.gradle` / `settings.gradle.kts`.

Read: `build.gradle[.kts]`, main entry class, public service interfaces.

### Fallback

**Module = each top-level directory containing ≥ 3 source files** (any extension).

Read all source files found within each directory.

---

## Step 3 — Identify Cross-Cutting Design Topics (Craft Edition)

After all module pages are drafted, scan them for recurring craft patterns.

**Qualification threshold**: a topic qualifies for its own design page if it
appears in **≥ 2 repositories** OR **≥ 3 modules within one repository**.

**Evidence requirement**: only create a design page if the code actually
demonstrates the pattern. Do not create pages based on assumed conventions.

**Value filter**: prefer high-value, durable topics with measurable craft
impact. Avoid pages that only restate obvious class-level structure.

### Common craft topic candidates

| Candidate topic | Evidence to look for |
|---|---|
| Layering and Dependency Direction | Repeated project-reference graph; consistent or inconsistent layering across modules |
| Abstraction Strategy | Repeated choice of interface-with-single-impl, abstract base class, composition pattern across ≥3 modules |
| Error Handling Discipline | Shared exception types, `Result<T>`, or pattern of swallow-and-log; consistency across boundaries |
| Logging and Observability | Shared logger wiring, structured logging discipline, trace context propagation |
| DI / IoC Composition | DI registration style: convention-based, manual, decorators, named bindings |
| Testing Seams and Test Smells | Shared test base classes, fixture sharing, mock-heavy testing pointing to DIP issues in production |
| Cross-cutting Clean-code Violations | Shared utility used by ≥3 modules whose own internal craft is poor (wide-blast-radius dead code, leaky `Helper` classes) |
| Public API Surface Discipline | What modules export vs keep internal; ISP discipline on public interfaces |
| Boundary Leakage | ORM, HTTP, framework types appearing in unintended layers |

### Topic page naming

Use a descriptive, lowercase kebab slug:
- `layering-and-dependency-direction`
- `error-handling-discipline`
- `di-composition-style`
- `testing-seams-and-smells`
- `boundary-leakage`

If a topic has subtopics (e.g. "Abstraction Strategy" covers both
interface-with-single-impl and abstract-base-class patterns), create one parent
design page and link to sub-pages if the content warrants it.

---

## Expansion Checks (Mandatory Before Conclusions)

After inspecting narrowed module scope, check for hidden coupling and craft
impact that may invalidate initial conclusions:

- dependency injection registrations and overrides
- factories and abstract factories
- partial classes / partial methods (.NET)
- extension methods crossing module boundaries
- reflection-based wiring
- source generators / compile-time code generation
- runtime configuration switching behavior
- tests revealing hidden invariants or pointing back to design pressure
- environment-dependent branches and feature flags
- legacy or compatibility code paths kept "just in case"

If expansion checks find craft impact not reflected in docs, record:

- new SOLID/clean-code findings in the appropriate module page and report
- new drift items in `reports/design-drift.md`

---

## Output Focus

Generated craft documentation should prioritize:

- recovered design: abstractions, layering, seams, state ownership
- principle-by-principle SOLID grading with citations
- rule-by-rule clean-code grading with citations
- accepted trade-offs (ADRs honored)
- cross-cutting craft topics worth team attention
- prioritized refactor candidates rooted in evidence

Avoid generating low-value content such as:

- exhaustive method-by-method summaries of trivial utilities
- "looks fine" findings without principle/rule and severity
- restatement of structure already obvious from the code
