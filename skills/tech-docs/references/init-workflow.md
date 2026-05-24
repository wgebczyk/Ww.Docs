# TechDocs — Init Workflow

## Depth Standard

Init mode is a one-time investment. Its output becomes the foundation for all future
Update runs, mismatch detection, and analysis prompts. Shallow output here compounds
into persistent low-quality context.

For each module and design topic, the expected depth is:

- **Read beyond entry points.** Do not stop at controllers or service interfaces. Trace
  actual data flow through all layers: middleware, validators, services, repositories,
  background jobs, event handlers, scheduled tasks, and configuration.
- **Identify invariants, not just structure.** Note what must always or never be true —
  not just which classes exist.
- **Verify curated claims in code.** Every curated assumption must be confirmed or flagged
  as unverified. Do not propagate intent as fact.
- **Call out hidden paths explicitly.** Feature flags, admin tools, legacy endpoints,
  migration scripts, and operational scripts must be searched for and noted — even if
  they only appear in the known-gaps section.
- **Assign Confidence honestly.** A module with incomplete trace coverage must be marked
  `Confidence: Low`, not `Medium`.

**NOTE:** For Init runs on large or complex codebases, manually switch to the strongest
available model before invoking the skill. Alternatively, create a companion `.agent.md`
wrapper with `model: <preferred model>` that invokes this skill.

## Steps

Load `references/workflow-guide.md` for full procedural detail.

1. Create `docs/tech-docs/{pages,pages/modules,pages/design,reports}/` if absent.
2. Read all `docs/tech-docs/curated/**/*.md` and index by module/topic.
3. Discover all git repositories at workspace root (`.git/` directories); record name,
   path, and HEAD commit hash.
4. Per repo: detect technology stack and module boundaries
   (`references/module-heuristics.md`); build module slugs using Module Naming Rules.
5. Per module: read key source files, run expansion checks, merge curated intent, write
   page to `docs/tech-docs/pages/modules/{repo-module-kebab}.md` using
   `references/wiki-page-template.md`.
6. Write design topic pages to `docs/tech-docs/pages/design/` using
   `references/wiki-page-template.md`, write `index.md`, and write all report files to
   `docs/tech-docs/reports/`. Generate pipeline YAML if applicable (see Pipeline
   Generation in SKILL.md).
7. Append Init entry to `docs/tech-docs/log.md`.
8. Run Verification Checklist.
9. Report: repos found, modules created, design topics created, curated files incorporated,
   mismatches found, pipeline: generated | skipped.
