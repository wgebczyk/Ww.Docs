# Module Heuristics

Rules for detecting technology stacks and deriving module boundaries from them.
Apply these in order during both Init and Update modes.

These heuristics optimize search scope. They do not replace source verification.

---

## Step 0 — Hypothesis and Risk Framing

Before stack/module detection, derive a hypothesis set from curated and generated docs.

For each requested question or topic:

1. Extract expected behavior, invariants, and assumptions from:
	- `docs/tech-docs/curated/**/*.md`
	- `docs/tech-docs/pages/**/*.md` (if present)
2. Convert them into explicit hypotheses (for example: "tenant ID comes from claims only").
3. Mark high-risk categories that always require deeper expansion checks:
	- authentication and authorization
	- tenant isolation and access boundaries
	- external callbacks and signature validation
	- financial state transitions
	- personal data handling, retention, and deletion
4. Use Steps 1-3 below to narrow where to inspect code first.
5. After narrowed inspection, run expansion checks (alternate entry points, jobs,
	handlers, flags, config, tests, migrations, legacy scripts).

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

A repository may contain secondary stacks in subdirectories (e.g. a .NET API with
an Angular client in `client/`). Detect the primary stack from the root. If a
subdirectory has its own `angular.json` or `package.json`, treat it as a nested
repo and analyse it separately under the same parent repo name.

---

## Step 2 — Derive Module Boundaries

Apply the rule for the detected stack.

After detecting module boundaries, generate a module page slug with this required format:

- `{module-name}`
- lowercase kebab-case only

De-duplication rule:

- If repo slug ends with token `X` and module slug starts with token `X`, remove the repeated leading module token.
- Example: `crackling-api` + `api-host` => `crackling-api-host`.

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

Key files to read within each domain folder:

| File pattern | What it reveals |
|---|---|
| `**/DependencyInjection.cs` | Module's public contracts and wiring |
| `**/*DbContext.cs` or `**/I*DbContext.cs` | Data model boundary |
| `**/Commands/**/*.cs` | Write operations (CQRS) |
| `**/Queries/**/*.cs` | Read operations (CQRS) |
| `**/Events/**/*.cs` or `**/Handlers/**/*.cs` | Event-driven behaviour |
| `**/*Controller.cs` or `**/*Endpoint.cs` | HTTP API surface |
| Top-level model/entity files | Domain concepts |

Test projects (`*.Tests` or `*.UnitTests`): read for Design Insights only — they
reveal edge cases, constraints, and invariants. Do not create separate module pages
for test projects.

**Split threshold**: if a domain folder has > 30 non-test source files, create:
- `modules/{module-slug}.md` — overview with table of contents
- `modules/{module-slug}-commands.md` — command handlers
- `modules/{module-slug}-queries.md` — query handlers
- `modules/{module-slug}-infrastructure.md` — persistence / external integrations

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
| `*api*.service.ts` or `*http*.service.ts` | Backend API calls |
| `*.model.ts` or `*.types.ts` | Frontend data model |
| `screens/**/*.component.ts` | User-facing screens |
| `store/**/*.ts` or `*facade*.ts` | State management |

### Node.js Monorepo

**Module = each workspace package** listed in the root `package.json` `"workspaces"` array.

Read per package: `package.json` (name, description, exports), `src/index.ts` or
`index.ts`, top-level `src/` subdirectories.

### Node.js Single Package

**Module = each top-level subdirectory under `src/`** that contains more than 3 files.

Read: `src/index.ts`, route files, service files, model files.

### Python

**Module = each top-level directory containing `__init__.py`**.

Read per module: `__init__.py`, all `.py` files in the directory. Note: do not
descend into `tests/` or `test_*` directories for module pages (use for insights only).

### Go

**Module = each package directory** (directory containing `.go` files).

Exclude `vendor/` and `_test` files from the module page; read tests for insights.

### Rust

**Module = each crate** listed in `[workspace.members]` in the root `Cargo.toml`.
For non-workspace repos, treat the single crate as one module.

Read: `src/lib.rs` or `src/main.rs`, public items in `src/`.

### Java (Maven)

**Module = each Maven submodule** (directory containing its own `pom.xml`).

Read: `pom.xml` (artifactId, dependencies), main entry class, public service/repository interfaces.

### Java/Kotlin (Gradle)

**Module = each Gradle subproject** listed in `settings.gradle` / `settings.gradle.kts`.

Read: `build.gradle[.kts]`, main entry class, public service interfaces.

### Fallback

**Module = each top-level directory containing ≥ 3 source files** (any extension).

Read all source files found within each directory.

---

## Step 3 — Identify Cross-Cutting Design Topics

After all module pages are drafted, scan them for recurring patterns.

**Qualification threshold**: a topic qualifies for its own design page if it
appears in **≥ 2 repositories** OR **≥ 3 modules within one repository**.

**Evidence requirement**: only create a design page if the code actually
demonstrates the pattern. Do not create pages based on assumed conventions.

**Value filter**: prefer high-value, durable topics and avoid low-value page churn.
Do not create design pages that only restate obvious class-level structure.

### Common topic candidates

Check each of the following. If confirmed, create a design page.

| Candidate topic | Evidence to look for |
|---|---|
| Authentication / Authorization | Shared auth middleware, JWT/token validation, claims transformation, role checks repeated across modules |
| CQRS Pattern | `Commands/` and `Queries/` folders in ≥3 modules, shared `ICommand`/`IQuery` base types |
| Data Persistence / ORM | Shared `DbContext` base, repository pattern, EF Core conventions used across domains |
| Event-Driven Messaging | Shared event bus registration, message handler base classes, recurring publish/subscribe patterns |
| API Contract / Integration | OpenAPI spec files, shared DTO conventions, versioning patterns |
| Error Handling Strategy | Shared exception types, result pattern (`Result<T>`), global error middleware |
| External Service Integration | Recurring patterns for calling the same external system (e.g. Azure Service Bus, IBM APIC, SendGrid) |
| Testing Conventions | Shared test base classes, fixture patterns, mock setups repeated across test projects |
| Build / CI Patterns | Shared pipeline templates, common build targets, consistent versioning strategies |
| Shared Utilities / Base Classes | Common helpers used by ≥3 modules (string extensions, date utilities, mapping conventions) |

### Topic page naming

Use a descriptive, lowercase kebab slug:
- `cqrs-pattern`
- `authentication-authorization`
- `external-service-integration`
- `error-handling`

If a topic has subtopics (e.g. "External Service Integration" covers both Azure
Service Bus and IBM APIC), create one parent design page and link to sub-pages if
the content warrants it.

---

## Expansion Checks (Mandatory Before Conclusions)

After inspecting narrowed module scope, check for hidden paths that may invalidate
initial assumptions:

- route and endpoint registrations
- dependency injection registrations and overrides
- background jobs and scheduled tasks
- event handlers and asynchronous consumers
- feature flags and environment-dependent branches
- production configuration files and toggles
- migrations and schema constraints
- admin and maintenance scripts
- legacy or compatibility endpoints
- tests covering failure, replay, and edge cases

If expansion checks find behavior not reflected in docs, record a mismatch in
`docs/tech-docs/reports/doc-code-mismatches.md`.

---

## Output Focus

Generated documentation should prioritize:

- system overview and major module responsibilities
- critical flows (request, command, event, integration)
- trust boundaries and security assumptions observed in code
- data ownership and key transformations
- non-obvious constraints from tests, comments, and DI composition

Avoid generating low-value content such as exhaustive method-by-method summaries
for trivial utilities.
