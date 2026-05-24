# SecDocs — Init Workflow

## Depth Standard

Init mode establishes the compliance baseline that all future Incremental runs delta
against. Shallow output here persists as stale verdicts across every subsequent run.

For each ASVS category, the expected depth is:

- **Verify in code, not in docs.** Every requirement status must be established by reading
  actual source files — not inferred from documentation or project type.
- **Search beyond entry points.** Trace security controls through middleware stacks, DI
  registration, config transforms, environment-specific overrides, and generated code.
- **Identify compensating controls explicitly.** If a control is implemented differently
  than ASVS prescribes but achieves the same outcome, document it — do not mark as FAIL
  without investigating.
- **Mark gaps honestly.** Use `NOT-ASSESSED` for requirements where code evidence was not
  found; use `PARTIAL` where coverage is incomplete. Never substitute `PASS` for lack of
  evidence.
- **Assign Confidence honestly.** A category with incomplete trace coverage must be marked
  `Confidence: Low`, not `Medium`.

## Steps

Load `references/workflow-guide.md` for full procedural detail.

1. Create `docs/sec-docs/`, `docs/sec-docs/pages/`, and `docs/sec-docs/curated/` if absent.
2. Read all `docs/sec-docs/curated/**/*.md` and index by category/topic.
3. Discover all git repositories at workspace root (`.git/` directories); record name,
   path, and HEAD commit hash.
4. Per repo: detect technology stack (see `references/workflow-guide.md` Step 5).
5. Discover Entra ID deployable units and app registrations across all repos; create
   or update the orchestrator manifest at
   `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` (see Entra ID Audit
   Integration in SKILL.md, Phases 1–3).
6. Load Entra ID audit results from `docs/sec-docs/reports/entraid/entraid-audit-latest.json`
   if present; otherwise instruct the user to run the orchestrator, or mark
   Entra-ID-dependent requirements as `NOT-ASSESSED`.
7. Per ASVS category V1 → V17, one at a time: load reference file, analyse codebase,
   incorporate Entra ID findings where mapped, write `docs/sec-docs/pages/{filename}`
   using `references/category-page-template.md`.
8. Generate OWASP Top 10 2025 report: read `references/owasp_top10_2025.md`, pull
   findings from the 17 written category files, write
   `docs/sec-docs/pages/asvs_top10_owasp.md`.
9. Write `docs/sec-docs/index.md` with YAML metadata, category table, Top 10 row, and
   Entra ID audit status row.
10. Append Init entry to `docs/sec-docs/log.md`.
11. Run Verification Checklist.
12. Report: repos found, categories documented, requirements assessed, curated files
    incorporated, Entra ID audit status, FAIL/PARTIAL counts, Top 10 items covered.
