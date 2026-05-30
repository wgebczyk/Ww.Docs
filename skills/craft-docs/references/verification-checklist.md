# CraftDocs — Verification Checklist

Run these checks before reporting completion.

## Structure and Metadata

- [ ] `docs/craft-docs/index.md` exists and has valid metadata
- [ ] Every link in `index.md` resolves to an existing file
- [ ] Every generated page has required sections from the template
- [ ] Every generated page includes `generated-on`, `generated-from-commit`,
      `generated-from-branch`, `architecture-style`, `source-paths-analyzed`,
      `related-curated-docs`, `related-adrs`, `known-gaps`, `confidence`,
      `source-repos`
- [ ] Repositories tracked in `index.md` match repos found on disk
- [ ] Each `last-commit-hash` matches `cd {path} && git log -1 --format=%H`
- [ ] Each repo's `architecture-style` corresponds to the architecture file
      that was loaded for analysis

## Findings Quality

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

## Other Reports

- [ ] `docs/craft-docs/reports/design-drift.md` exists
- [ ] `docs/craft-docs/reports/refactor-candidates.md` exists and is
      prioritized (Critical first)
- [ ] `docs/craft-docs/reports/latest-refresh-summary.md` exists
- [ ] `docs/craft-docs/log.md` has a new entry for this run

## Naming

- [ ] Every module page slug follows `{repo-name}-{module-name}` lowercase
      kebab with de-duplication applied

## Update-only checks

- [ ] New `last-scan` timestamp is later than previous
- [ ] Only affected module/design pages have updated `generated-on`
- [ ] Resolved findings are removed from active reports (history stays in
      log)
- [ ] `First detected` is preserved on findings that persist

## Pipeline (only when pipeline was generated this run)

- [ ] `docs/craft-docs/azure-pipeline.yml` exists
- [ ] File contains no unsubstituted `{PLACEHOLDER}` tokens
- [ ] One `resources.repositories` entry and one `checkout` step exist per
      discovered repo
