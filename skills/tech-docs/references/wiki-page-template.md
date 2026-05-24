# Knowledge Page Template

Every generated page under `docs/tech-docs/pages/` must follow these templates.
Pages are orientation artifacts and must include verifiability metadata.

---

## Required Metadata (all generated pages)

Use this exact frontmatter shape on every generated page:

```yaml
---
generated-on: 2026-05-11T00:00:00Z
generated-from-commit: abc1234
generated-from-branch: main
source-paths-analyzed:
  - src/PathA
  - tests/PathA
related-curated-docs:
  - docs/tech-docs/curated/security-assumptions.md
known-gaps:
  - production-only configuration not analyzed
confidence: Medium
source-repos:
  - repo-name
---
```

Rules:

1. `confidence` must be one of: `High`, `Medium`, `Low`.
2. `known-gaps` must be explicit. If none are known, write `- none identified`.
3. `source-paths-analyzed` must list concrete paths used for analysis.
4. Claims in body content still require `(source: ...)` citations.

---

## Module Page (`docs/tech-docs/pages/modules/{repo-module-kebab}.md`)

```markdown
---
generated-on: {ISO-8601-UTC}
generated-from-commit: {40-char-git-hash}
generated-from-branch: {branch-name}
source-paths-analyzed:
  - {repo}/src/{module-path}
related-curated-docs:
  - docs/tech-docs/curated/{file}.md
known-gaps:
  - {gap or "none identified"}
confidence: {High|Medium|Low}
source-repos:
  - {repo-name}
---

# {Module Name}

## Overview

One paragraph describing responsibility and system role.
If curated docs define intent for this module, include it with citation:
(source: docs/tech-docs/curated/{file}.md)

## Architecture

### Key Components

- `TypeOrFunction` — role in one sentence (source: repo/path/file.ext)

### Dependencies

- **{ModuleOrSystem}** — why dependency exists (source: repo/path/file.ext)

### Data Flow

List the main flow as ordered bullets. State the pattern explicitly (REST request,
CQRS command, event handler, batch job, etc.).

1. Entry point ... (source: repo/path/file.ext)
2. Transformation ... (source: repo/path/file.ext)
3. Output or side-effect ... (source: repo/path/file.ext)

## Verification Notes

Document code-verified behavior and coverage boundaries.

- Verified paths: ... (source: repo/path/file.ext)
- Expansion checks run: jobs/events/flags/config/tests/migrations/legacy scripts.
- Any mismatch with curated or prior generated docs.

If mismatch exists, include:
`[NOTE: curated/generated docs say X; code verification shows Y — verify with team]`

## Design Insights

At least one non-obvious implementation insight.

> **Decision:** ...
> **Why:** ...
> **Alternative considered:** ...
> (source: repo/path/file.ext)

## Related Pages

- [{Another Module}](../modules/{repo-module-kebab}.md)
- [{Design Topic}](../design/{kebab-topic}.md)
```

---

## Design Topic Page (`docs/tech-docs/pages/design/{kebab-topic}.md`)

```markdown
---
generated-on: {ISO-8601-UTC}
generated-from-commit: {40-char-git-hash}
generated-from-branch: {branch-name}
source-paths-analyzed:
  - {repo}/src/{path}
related-curated-docs:
  - docs/tech-docs/curated/{file}.md
known-gaps:
  - {gap or "none identified"}
confidence: {High|Medium|Low}
source-repos:
  - {repo-name-1}
  - {repo-name-2}
---

# {Topic Name}

## Overview

Describe the cross-cutting concern and why it merits a shared topic page.

## Context

- **{Repo}/{Module}** — how pattern appears here (source: repo/path/file.ext)
- **{Repo}/{Module}** — how pattern appears here (source: repo/path/file.ext)

## Pattern / Decision

Describe what is consistent, what varies, and what shared abstractions enforce behavior.
(source: repo/path/file.ext for each claim)

If conflicting implementations exist, include:
`[CONFLICT: source A says X; source B says Y]`

## Verification Notes

- Verified code paths and entry points
- Expansion checks and hidden-path outcomes
- Mismatches against curated/generated docs

## Design Insights

> **Decision:** ...
> **Why:** ...
> **Alternative considered:** ...
> (source: repo/path/file.ext)

## Related Pages

- [{Module}](../modules/{repo-module-kebab}.md)
- [{Other Topic}](../design/{kebab-topic}.md)
```

---

## Index Page (`docs/tech-docs/index.md`)

```markdown
---
last-scan: "{ISO-8601-UTC}"
generated-from-commit: "{workspace-summary-commit-or-multi-repo-tag}"
generated-from-branch: "{branch-or-multi-repo}"
repositories:
  - name: {repo-directory-name}
    path: {repo-directory-name}
    last-commit-hash: {40-char-git-hash}
source-paths-analyzed:
  - {repo-name}/src
related-curated-docs:
  - docs/tech-docs/curated/architecture-principles.md
known-gaps:
  - none identified
confidence: Medium
source-repos:
  - {repo-name}
---

# Knowledge Index

Generated knowledge pages are orientation maps. Validate behavior against source code.

## Modules

| Page | Repository | Description |
|---|---|---|
| [{Module Name}](pages/modules/{repo-module-kebab}.md) | {repo} | One-line description |

## Design Topics

| Page | Repositories | Description |
|---|---|---|
| [{Topic Name}](pages/design/{kebab}.md) | {repo-a}, {repo-b} | One-line description |

## Reports

- [Latest Refresh Summary](reports/latest-refresh-summary.md)
- [Doc-Code Mismatches](reports/doc-code-mismatches.md)
- [Stale Pages](reports/stale-pages.md)
- [High-Risk Changes](reports/high-risk-changes.md)
```

---

## Report Templates (`docs/tech-docs/reports/*.md`)

### `latest-refresh-summary.md`

```markdown
# Latest Refresh Summary

- Run timestamp: {ISO-8601-UTC}
- Repositories checked: {N}
- Repositories with changes: {N}
- Modules updated: {N}
- Design topics updated: {N}
- Curated files reviewed: {N}
- Mismatches detected: {N}
```

### `doc-code-mismatches.md`

```markdown
# Doc-Code Mismatches

## {Topic or Module}

- Documentation claim: ... (source: docs/tech-docs/curated/or/generated/file.md)
- Verified code behavior: ... (source: repo/path/file.ext)
- Impact: Low|Medium|High
- Suggested update: ...
```

### `stale-pages.md`

```markdown
# Stale Pages

- {page-path} — reason stale (for example: module changed since page generation)
```

### `high-risk-changes.md`

```markdown
# High-Risk Changes

- {repo/module}: summary of risk-relevant change
- Evidence: (source: repo/path/file.ext)
- Why high-risk: auth|tenant|financial|data-retention|external-callback|compliance
```

---

## Formatting Rules

1. Keep sections present even if short; use `N/A — not applicable` when truly empty.
2. Keep paragraphs concise (3-5 sentences max).
3. Include citations for all substantive technical claims.
4. Use relative links between generated pages.
5. Keep generated output deterministic to reduce churn between refresh runs.
