---
name: craft-docs-mini
description: >
  Use this skill when the user asks to generate or refresh code craftsmanship docs,
  recover design information, audit architecture adherence, audit SOLID alignment,
  audit clean-code adherence, audit testability, or invokes /craft-docs-mini. Single-
  repository variant of craft-docs: scans the current folder and below (repo root).
  Follows a hybrid strategy: curated docs declare intended design and rationale
  (including ADRs and architecture-style declarations); generated docs recover observed
  design and produce a prioritized Critical/Major/Minor findings report across
  Architecture → SOLID → Clean Code → Testability; source code proves actual
  behavior and structure.
allowed-tools:
  - readFile
  - createFile
  - writeFile
  - search
  - fileSearch
  - 'shell:git'
  - 'shell:Get-ChildItem'
  - 'shell:New-Item'
---

# CraftDocs-Mini Skill

Recovers design information and grades code craftsmanship across four aspects —
Architecture, SOLID, Clean Code, Testability — for the single git repository at
the current working directory. Output is a prioritized
**Critical / Major / Minor** findings report with file/line references and
concrete suggested refactors. Curated docs declare intent; generated docs
recover observed design and findings; source code is the only proof.

## Core Principle

**RULE:** Curated docs declare intent. Generated docs recover observed design and grade craft alignment in fixed order: Architecture → SOLID → Clean Code → Testability. Source code is the only proof.

**CONSTRAINT [HARD]:** Every finding requires a source citation — file path plus line range when the finding is localized. Never assert a violation without one.

## Analysis Order (fixed)

Every module is graded in this exact order. A finding produced by an earlier
pass shadows a candidate finding for the same code location in a later pass —
do not double-file.

1. **Architecture adherence** — style-agnostic invariants plus the one
   matching architecture-style file.
2. **SOLID** — SRP, OCP, LSP, ISP, DIP residue not already filed as
   Architecture.
3. **Clean Code** — naming, function size, comments, duplication, complexity,
   magic numbers, error handling, dead code. Not already filed above.
4. **Testability** — hidden dependencies, hard-to-substitute collaborators,
   constructor over-injection, side-effects in constructors, test-only public
   surface, brittle test smells caused by production design.

The order is non-negotiable: structural issues are reported first, surface
issues last. Aspect files cross-reference each other to keep findings in one
place.

## Aspect and Architecture Reference Files

Aspect rule sets — load all four during analysis:

| File | Loaded for |
|---|---|
| `references/aspects/architecture.md` | Architecture pass (style-agnostic rules + style detection) |
| `references/aspects/solid.md` | SOLID pass |
| `references/aspects/clean-code.md` | Clean Code pass |
| `references/aspects/testability.md` | Testability pass |

Architecture-style files — load **exactly one** per module after detection:

| File | Loaded for |
|---|---|
| `references/architectures/layered.md` | Layered / N-tier |
| `references/architectures/hexagonal.md` | Hexagonal / Ports and Adapters |
| `references/architectures/clean-architecture.md` | Clean Architecture (concentric rings) |
| `references/architectures/vertical-slice.md` | Vertical Slice / Feature Folders |
| `references/architectures/event-driven.md` | Event-Driven / CQRS |

If detection yields `Unclear`, skip style-specific rules and file a Major
architecture finding (see `aspects/architecture.md`).

## Output Format

All findings — across every aspect — are reported as a **prioritized list**
grouped Critical → Major → Minor, with findings inside each priority ordered
by aspect (Architecture → SOLID → CleanCode → Testability). Per-finding
structure (Aspect, Rule, Where, Evidence, Suggested refactor, Effort, First
detected) and report layout are defined in
`references/output-format.md`.

No flat lists. No "high/medium/low" — only Critical/Major/Minor. No
unsourced findings.

## Mode Detection

Determine mode before any other work. Flags take precedence over file-state detection.

| Condition | Mode |
|---|---|
| `--init` flag passed | **Init** — if `index.md` already exists, report which pages will be overwritten before proceeding |
| `--update` flag passed | **Update** |
| No flag; `docs/craft-docs/index.md` does not exist | **Init** |
| No flag; `docs/craft-docs/index.md` exists | **Update** — read YAML frontmatter, extract `last-scan` and `last-commit-hash` |

## Flags

| Flag | Effect |
|---|---|
| `--init` | Force Init mode. If `index.md` already exists, report which pages will be overwritten before proceeding. |
| `--update` | Force Update mode. |
| `--all` | In Update mode, re-run all four analysis passes on all modules regardless of what changed (bypass change-to-module mapping). Use when you suspect cross-cutting impact or want a full craftsmanship refresh without re-running Init. |

## Write Constraint

Only these paths are writable:

- `docs/craft-docs/index.md` — agent-owned hub index, updated each run
- `docs/craft-docs/log.md` — append-only run log; never rewrite or truncate
- `docs/craft-docs/pages/` — agent-owned, periodically refreshed craft pages
- `docs/craft-docs/reports/` — agent-owned run outputs (per-aspect findings,
  drift, refactor candidates, summary)

`docs/craft-docs/curated/` is human-owned and read-only for the agent
(intended design, rationale, ADRs, style declarations, refactoring constraints,
do-not-touch notes). All other paths are read-only. If a write would target
any other path, stop and report the violation.

## Module Naming Rules

Slug format: `{module-name}` in lowercase kebab. If the project name's last
segment equals the module name's first segment, remove the duplicate
(e.g. project `cold-wave-api` with module `api-host` → slug `api-host`).

## Citation Rules

Every factual claim about code must be followed by a source reference:

```
(source: path/to/file.ext)
```

Paths are relative to the repository root. For findings, the `Where` field
uses `path/to/file.ext:Lstart-Lend`. Priority claims must be supported by an
explicit reason rooted in code per the matching aspect or architecture file's
rubric.

If two sources contradict each other, write both citations and flag the conflict:

```
[CONFLICT: path/file-a.cs says X; path/file-b.ts says Y]
```

Never make unsourced claims about how the code is designed.

## Curated Docs Integration

Before any code analysis, read all files matching
`docs/craft-docs/curated/**/*.md`. If the directory does not exist, continue
with generated-only flow and report this gap.

Curated docs can include — but are not limited to:

- Project-specific intended design and purpose of components
- Architecture Decision Records (ADRs) — including superseded ones
- **Architecture-style declarations** (e.g. ADR-000-architecture-style.md)
- Module / component charters and responsibilities
- Refactoring constraints and "do not touch" notes
- Project-specific SOLID/clean-code interpretations or relaxations (e.g.
  "DTO records may exceed 7 fields")

For each curated file:

1. Note its filename stem and check for YAML frontmatter such as `module:`,
   `topic:`, `adr:`, `decision:`, `architecture-style:`, `status:`.
2. Treat it as intent-level context and authoritative rationale, not as
   runtime proof.
3. In corresponding generated pages, reference curated assumptions and ADRs
   with `(source: docs/craft-docs/curated/filename.md)`.
4. If source code disagrees with curated intent, add
   `[NOTE: curated says X; code shows Y — verify with team]` in the generated
   page and record the mismatch in `docs/craft-docs/reports/design-drift.md`.
5. When a curated ADR explicitly accepts a deviation, do not flag that
   deviation as a violation — instead cite the ADR and record under "Accepted
   Trade-offs" on the module page.
6. A curated style declaration takes precedence over signal-based style
   detection.

## Verification-First Answer Protocol

When answering analysis prompts with this skill:

1. Read relevant curated and generated pages.
2. Extract intended design, declared style, ADR decisions, and accepted
   trade-offs.
3. Translate intent into hypotheses about how the code should be shaped.
4. Verify hypotheses in current source code from a narrowed scope.
5. Expand search to hidden paths: dependency injection wiring, factories,
   inheritance trees, partial classes, extension methods, generated code,
   test doubles, and reflection-based wiring.
6. Run the four passes in order — Architecture → SOLID → CleanCode →
   Testability — and file each finding to the earliest aspect that captures
   its root cause.
7. Call out drift between intent and code, accepted trade-offs (via ADRs),
   and suggested doc or refactor updates.

## Run Log

At the **end of every run** (after all pages are written, before the
Verification Checklist), append one entry to
`docs/craft-docs/log.md`. See `references/workflow-guide.md`
for the exact entry format.

Never rewrite or truncate `log.md` — only append. Do not embed this
history in `index.md` or any wiki page.

## Verification Checklist

Run these checks before reporting completion.

**Structure and Metadata**
- [ ] `docs/craft-docs/index.md` exists and has valid metadata
- [ ] Every link in `index.md` resolves to an existing file
- [ ] Every generated page has required sections from the template
- [ ] Every generated page includes `generated-on`, `generated-from-commit`,
      `generated-from-branch`, `architecture-style`, `source-paths-analyzed`,
      `related-curated-docs`, `related-adrs`, `known-gaps`, `confidence`, `source-repos`
- [ ] `last-commit-hash` in `index.md` matches `git log -1 --format=%H`
- [ ] Each module's `architecture-style` corresponds to the architecture file
      that was loaded for analysis

**Findings Quality**
- [ ] Every finding uses the per-finding structure from
      `references/output-format.md`
- [ ] Every finding has Aspect, Rule, Where (with file/line), Evidence,
      Suggested refactor, Effort, First detected
- [ ] Findings are grouped Critical → Major → Minor; within each priority
      ordered by aspect (Architecture → SOLID → CleanCode → Testability)
- [ ] No "high/medium/low" or numeric scoring appears anywhere in output
- [ ] No finding is filed in two aspects — the earliest aspect in the
      analysis order owns each finding
- [ ] `docs/craft-docs/reports/architecture-findings.md`,
      `solid-findings.md`, `clean-code-findings.md`,
      `testability-findings.md` each exist and either list findings or state
      none found

**Other Reports**
- [ ] `docs/craft-docs/reports/design-drift.md` exists
- [ ] `docs/craft-docs/reports/refactor-candidates.md` exists and is
      prioritized (Critical first)
- [ ] `docs/craft-docs/reports/latest-refresh-summary.md` exists
- [ ] `docs/craft-docs/log.md` has a new entry for this run

**Naming**
- [ ] Every module page slug follows `{module-name}` lowercase kebab with
      de-duplication applied

For Update runs, also check:
- [ ] New `last-scan` timestamp is later than previous
- [ ] Only affected module/design pages have updated `generated-on`
- [ ] Resolved findings are removed from active reports (history stays in log)
- [ ] `First detected` is preserved on findings that persist

## Init Workflow

Load `references/init-workflow.md` — depth standard and step-by-step procedure.

## Update Workflow

Load `references/update-workflow.md` — step-by-step procedure.

## Reference Files

Load these as needed — they are not in context by default:

| File | Load when |
|---|---|
| `references/init-workflow.md` | Starting Init mode |
| `references/update-workflow.md` | Starting Update mode |
| `references/workflow-guide.md` | Full procedural detail for either mode |
| `references/module-heuristics.md` | Identifying modules or design topics |
| `references/output-format.md` | Writing any finding or finding-containing report |
| `references/aspects/architecture.md` | Architecture pass + style detection |
| `references/aspects/solid.md` | SOLID pass |
| `references/aspects/clean-code.md` | Clean Code pass |
| `references/aspects/testability.md` | Testability pass |
| `references/architectures/{style}.md` | Architecture pass — load only the one for the detected style |
| `references/wiki-page-template.md` | Writing or updating any generated page |
