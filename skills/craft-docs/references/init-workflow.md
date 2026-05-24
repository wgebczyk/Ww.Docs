# CraftDocs — Init Workflow

## Depth Standard

Init mode is a one-time investment. Its output becomes the baseline for future Update
runs, drift detection, and refactoring analysis. Shallow output here compounds into
persistent low-quality context.

For each module and design topic, the expected depth is:

- **Recover observed design, not assumed design.** Identify actual abstractions, layering,
  dependency direction, composition vs inheritance, ownership of state, and seams.
- **Detect the architecture style honestly.** If signals are weak, use `Unclear` — do not
  force a style.
- **File each finding under the earliest aspect that captures its root cause.** A class
  that violates SRP because of a layering problem is filed under Architecture, not SOLID.
- **Cite specifically.** File path and line range when useful. No directory-only citations.
- **Justify priority.** Pick the lowest priority that still satisfies the rubric in the
  matching aspect/architecture file.
- **Make refactor suggestions concrete.** Name the destination pattern. No "consider
  refactoring" wording.
- **Assign Confidence honestly.** A module with incomplete trace coverage must be marked
  `Confidence: Low`, not `Medium`.

## Steps

Load `references/workflow-guide.md` for full procedural detail.

1. Create `docs/craft-docs/{pages,pages/modules,pages/design,reports,curated/{adrs,design-notes}}/`
   if absent.
2. Read all `docs/craft-docs/curated/**/*.md` and index by module / topic /
   ADR / style declaration.
3. Discover all git repositories at workspace root.
4. **Detect architecture style per repo or module** using
   `references/aspects/architecture.md`. Load only the matching
   `references/architectures/{style}.md`.
5. Detect technology stack and module boundaries
   (`references/module-heuristics.md`); build module slugs.
6. Per module: recover design, then run the four passes in order
   (Architecture → SOLID → CleanCode → Testability), then expansion checks.
7. Write module pages with prioritized Findings section using
   `references/wiki-page-template.md` (per-finding layout from
   `references/output-format.md`).
8. Write design topic pages, `index.md`, and all consolidated reports
   (`{aspect}-findings.md`, `design-drift.md`, `refactor-candidates.md`,
   `latest-refresh-summary.md`). Append Init entry to `docs/craft-docs/log.md`.
9. Generate pipeline YAML if applicable (see Pipeline Generation in SKILL.md).
10. Run Verification Checklist.
11. Report outcome.
