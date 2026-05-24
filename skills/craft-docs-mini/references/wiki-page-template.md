# Craft Page Template

Every generated page under `docs/craft-docs/pages/` must follow these
templates. Pages are orientation artifacts and must include verifiability
metadata. All findings inside pages follow the **prioritized report** format
defined in `references/output-format.md` — never a per-aspect flat list.

---

## Required Metadata (all generated pages)

Use this exact frontmatter shape on every generated page:

```yaml
---
generated-on: 2026-05-12T00:00:00Z
generated-from-commit: abc1234
generated-from-branch: main
architecture-style: Hexagonal       # one of: Layered, Hexagonal, CleanArchitecture, VerticalSlice, EventDriven, Unclear
source-paths-analyzed:
  - src/PathA
  - tests/PathA
related-curated-docs:
  - docs/craft-docs/curated/design-notes/billing-module.md
related-adrs:
  - docs/craft-docs/curated/adrs/ADR-001-allow-large-dtos.md
known-gaps:
  - generated code under obj/ not analyzed
confidence: Medium
source-repos:
  - repo-name
---
```

Rules:

1. `confidence` must be one of: `High`, `Medium`, `Low`.
2. `known-gaps` must be explicit. If none are known, write `- none identified`.
3. `source-paths-analyzed` must list concrete paths used for analysis.
4. `architecture-style` must match the style file loaded for analysis.
5. `related-adrs` lists ADR files in `docs/craft-docs/curated/adrs/` that
   affected findings on this page. If none, write `- none`.
6. Claims in body content still require `(source: ...)` citations.

---

## Module Page (`docs/craft-docs/pages/modules/{module-kebab}.md`)

```markdown
---
generated-on: {ISO-8601-UTC}
generated-from-commit: {40-char-git-hash}
generated-from-branch: {branch-name}
architecture-style: {Layered|Hexagonal|CleanArchitecture|VerticalSlice|EventDriven|Unclear}
source-paths-analyzed:
  - src/{module-path}
related-curated-docs:
  - docs/craft-docs/curated/{file}.md
related-adrs:
  - docs/craft-docs/curated/adrs/{ADR-file}.md
known-gaps:
  - {gap or "none identified"}
confidence: {High|Medium|Low}
source-repos:
  - {repo-name}
---

# {Module Name}

## Overview

One paragraph describing the module's responsibility and system role.
If curated docs declare intended design for this module, include it with citation:
(source: docs/craft-docs/curated/{file}.md)

## Design (Recovered)

Describe what the code actually looks like — independent of any judgement.

### Key Abstractions

- `TypeOrInterface` — role and shape (source: repo/path/file.ext)

### Layering and Dependency Direction

State the layering observed and how dependencies flow. Call out any back-edges.
For the detected architecture style, note whether the dependency rule holds.
(source: repo/path/file.ext)

### Seams

Places where behavior can be substituted at composition time: interfaces,
factories, DI registrations, strategy points, virtual methods.

- `ISeamName` — what gets swapped here (source: repo/path/file.ext)

### Composition vs Inheritance

State which is preferred and where the boundary sits. (source: repo/path/file.ext)

### State and Side-Effects

Who owns mutable state. Where I/O, persistence, time, randomness, or external
calls happen. (source: repo/path/file.ext)

### Intent Alignment

For each curated intent or ADR decision relevant to this module:

- **Intent:** … (source: docs/craft-docs/curated/{file}.md)
- **Code:** … (source: repo/path/file.ext)
- **Status:** Aligned | Drift | Accepted trade-off (per ADR)

Drift items must also be recorded in `reports/design-drift.md`.

## Findings

Findings are grouped by **priority**, ordered within each priority by aspect:
Architecture → SOLID → CleanCode → Testability.
Use the per-finding structure from `references/output-format.md`.
Empty priority sections must still be shown — use `_No {priority} findings at current depth._`

### Critical

_No critical findings at current depth._

— or —

### [Critical] {Short imperative title}

- **Aspect:** Architecture
- **Rule:** {rule name from the relevant aspect/architecture file}
- **Where:** `repo/path/file.ext:Lstart-Lend`
- **Evidence:** one-paragraph description.
- **Suggested refactor:** concrete change naming the target shape.
- **Effort:** S | M | L
- **First detected:** {ISO date}

### Major

…

### Minor

…

## Accepted Trade-offs

ADR-backed deviations applicable to this module. Each entry must cite both the
ADR and the code location.

- **{What is accepted}** — (ADR: docs/craft-docs/curated/adrs/{ADR-file}.md;
  code: repo/path/file.ext)
- or `- none`

## Verification Notes

- Verified paths: … (source: repo/path/file.ext)
- Expansion checks run: DI wiring, factories, partial classes, extension
  methods, reflection, source generators, tests.
- Mismatches with curated or prior generated docs.

## Design Insights

At least one non-obvious craft observation specific to this module.

> **Observation:** …
> **Why it matters:** …
> **Suggested direction:** …
> (source: repo/path/file.ext)

## Related Pages

- [{Another Module}](../modules/{module-kebab}.md)
- [{Design Topic}](../design/{kebab-topic}.md)
```

---

## Design Topic Page (`docs/craft-docs/pages/design/{kebab-topic}.md`)

```markdown
---
generated-on: {ISO-8601-UTC}
generated-from-commit: {40-char-git-hash}
generated-from-branch: {branch-name}
architecture-style: {Layered|Hexagonal|CleanArchitecture|VerticalSlice|EventDriven|Unclear|Mixed}
source-paths-analyzed:
  - src/{path}
related-curated-docs:
  - docs/craft-docs/curated/{file}.md
related-adrs:
  - docs/craft-docs/curated/adrs/{ADR-file}.md
known-gaps:
  - {gap or "none identified"}
confidence: {High|Medium|Low}
source-repos:
  - {repo-name-1}
  - {repo-name-2}
---

# {Topic Name}

## Overview

Describe the cross-cutting craft concern and why it merits a shared topic page.

## Where the Pattern Appears

- **{Repo}/{Module}** — how the pattern appears here (source: repo/path/file.ext)
- **{Repo}/{Module}** — how the pattern appears here (source: repo/path/file.ext)

## Recovered Pattern

Describe what is consistent across implementations, what varies, and what
shared abstractions enforce or fail to enforce behavior. (source: …)

If conflicting implementations exist, include:
`[CONFLICT: source A says X; source B says Y]`

## Findings

Same prioritized structure as module pages. Use `references/output-format.md`.

### Critical
### Major
### Minor

## Accepted Trade-offs

- **{What is accepted}** — (ADR: docs/craft-docs/curated/adrs/{ADR-file}.md;
  code: repo/path/file.ext)
- or `- none`

## Verification Notes

- Verified code paths and entry points
- Expansion checks and hidden-path outcomes
- Mismatches against curated docs or ADRs

## Design Insights

> **Observation:** …
> **Why it matters:** …
> **Suggested direction:** …
> (source: repo/path/file.ext)

## Related Pages

- [{Module}](../modules/{module-kebab}.md)
- [{Other Topic}](../design/{kebab-topic}.md)
```

---

## Index Page (`docs/craft-docs/index.md`)

```markdown
---
last-scan: "{ISO-8601-UTC}"
generated-from-commit: "{workspace-summary-commit-or-multi-repo-tag}"
generated-from-branch: "{branch-or-multi-repo}"
repositories:
  - name: {repo-directory-name}
    path: {repo-directory-name}
    architecture-style: {Layered|Hexagonal|CleanArchitecture|VerticalSlice|EventDriven|Unclear|Mixed}
    last-commit-hash: {40-char-git-hash}
source-paths-analyzed:
  - {repo-name}/src
related-curated-docs:
  - docs/craft-docs/curated/design-notes/architecture.md
related-adrs:
  - docs/craft-docs/curated/adrs/ADR-001-allow-large-dtos.md
known-gaps:
  - none identified
confidence: Medium
source-repos:
  - {repo-name}
---

# Craft Knowledge Index

Generated craft pages recover observed design and grade alignment with the
detected architectural style, SOLID principles, clean code, and testability.
They are orientation maps — validate against source code before acting.

## Modules

| Page | Repo | Style | Critical | Major | Minor | Confidence |
|---|---|---|---|---|---|---|
| [{Module Name}](pages/modules/{module-kebab}.md) | {style} | {N} | {N} | {N} | {Low|Medium|High} |

## Design Topics

| Page | Repositories | Description |
|---|---|---|
| [{Topic Name}](pages/design/{kebab}.md) | {repo-a}, {repo-b} | One-line description |

## Reports

- [Latest Refresh Summary](reports/latest-refresh-summary.md)
- [Architecture Findings](reports/architecture-findings.md)
- [SOLID Findings](reports/solid-findings.md)
- [Clean Code Findings](reports/clean-code-findings.md)
- [Testability Findings](reports/testability-findings.md)
- [Design Drift](reports/design-drift.md)
- [Refactor Candidates](reports/refactor-candidates.md)
```

---

## Report Templates (`docs/craft-docs/reports/*.md`)

### `latest-refresh-summary.md`

```markdown
# Latest Refresh Summary

- Run timestamp: {ISO-8601-UTC}
- Repositories checked: {N}
- Repositories with changes: {N}
- Modules updated: {N}
- Design topics updated: {N}
- ADRs incorporated: {N}
- Curated files reviewed: {N}
- Findings — new vs resolved (per aspect):
  - Architecture: new {N} / resolved {N}
  - SOLID: new {N} / resolved {N}
  - CleanCode: new {N} / resolved {N}
  - Testability: new {N} / resolved {N}
- Findings by priority (current totals):
  - Critical: {N} | Major: {N} | Minor: {N}
- Design-drift items: {N}
```

### `{aspect}-findings.md` — one per aspect (`architecture-findings.md`, `solid-findings.md`, `clean-code-findings.md`, `testability-findings.md`)

Each consolidated aspect report groups active findings by priority, then by
module. Each entry is a short link back to its full detail on the module
page (per `output-format.md`).

```markdown
# {Aspect} Findings

## Critical

### [Critical] {Short title}

- **Module:** [{module}](../pages/modules/{slug}.md#critical)
- **Rule:** {rule name}
- **Where:** `repo/path/file.ext:Lstart-Lend`
- **First detected:** {ISO date}

## Major

…

## Minor

…
```

Resolved findings disappear from these reports — their history lives in
`log.md`.

### `design-drift.md`

```markdown
# Design Drift

## {Topic or Module}

- Intent: ... (source: docs/craft-docs/curated/{file}.md or curated/adrs/{ADR}.md)
- Observed behavior in code: ... (source: repo/path/file.ext)
- Impact: Critical | Major | Minor
- Suggested action: update doc | refactor code | open new ADR
```

### `refactor-candidates.md`

Prioritized merged view across aspects. Critical cross-cutting items first.

```markdown
# Refactor Candidates

## Critical

### [Critical] {Short imperative title}

- **Aspect / Rule:** SOLID — SRP
- **Affects:** {repo/module list}
- **Where:**
  - `repo/path/file.ext:Lstart-Lend`
  - `repo/other/file.ext:Lstart-Lend`
- **Suggested refactor:** {1-3 sentences naming the target shape}
- **Effort:** S | M | L
- **Linked findings:** [cold-wave-api-billing#critical](../pages/modules/cold-wave-api-billing.md#critical)

## Major

…

## Minor

…
```

---

## Formatting Rules

1. Keep sections present even if short. For findings, use
   `_No {priority} findings at current depth._` rather than removing the
   priority heading.
2. Inside each priority section, order findings by aspect: Architecture →
   SOLID → CleanCode → Testability.
3. Every finding follows `output-format.md` — no flat-list summaries.
4. Keep paragraphs concise (3-5 sentences max).
5. Citations are required for every substantive claim.
6. Severity claims map to priority and must be justified by the matching rule
   in the appropriate aspect or architecture file.
7. Use relative links between generated pages.
8. Keep generated output deterministic to reduce churn between refresh runs.
