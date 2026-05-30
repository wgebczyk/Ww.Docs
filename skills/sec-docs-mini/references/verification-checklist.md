# SecDocs-Mini — Verification Checklist

Run these checks before reporting completion.

## Structure and Metadata

- [ ] `docs/sec-docs/index.md` exists and has valid YAML frontmatter with `last-scan`,
      `asvs-version`, and `last-commit-hash`
- [ ] Every link in `index.md` body resolves to a file that exists on disk
- [ ] Every category page has valid YAML frontmatter with `category-id`, `last-updated`,
      and `status-summary`
- [ ] Every category page has: Summary, Technology Context, and one section per requirement
- [ ] Every requirement section has: Level badge, Status badge, Requirement text,
      Findings, Evidence
- [ ] `docs/sec-docs/pages/asvs_top10_owasp.md` exists and contains a section for each
      of the 10 OWASP Top 10 2025 items
- [ ] Each Top 10 section has: Description, ASVS cross-references, Status, Findings,
      Evidence
- [ ] `last-commit-hash` in `index.md` matches `git log -1 --format=%H`

## Evidence Quality

- [ ] Every PASS, FAIL, or PARTIAL verdict has at least one `(source: ...)` citation
- [ ] Every `docs/sec-docs/curated/` file is cited in at least one category page
- [ ] If `docs/sec-docs/reports/entraid/entraid-audit-latest.json` exists: at least one
      Entra ID finding is cited in V6, V7, V8, V9, V10, V11, or V13 category pages
- [ ] If `docs/sec-docs/reports/headers/headers-audit-latest.json` exists: at least one
      Headers finding is cited in V3 or V13 category pages
- [ ] If `docs/sec-docs/reports/tls/tls-audit-latest.json` exists: at least one TLS
      finding is cited in V11 or V12 category pages
- [ ] If `docs/sec-docs/reports/azure/azure-audit-latest.json` exists: at least one
      Azure finding is cited in V11 or V13 category pages
- [ ] If `docs/sec-docs/reports/deps/deps-audit-latest.json` exists: at least one
      Deps finding is cited in V15 category pages
- [ ] No requirement is marked PASS without a verifiable code reference

## Write Safety

- [ ] No write targeted `docs/sec-docs/curated/`
- [ ] No write targeted `docs/sec-docs/reports/entraid/` except `Invoke-EntraIDAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/headers/` except `Invoke-HttpHeadersAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/tls/` except `Invoke-TlsAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/azure/` except `Invoke-AzureResourceAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/deps/` except `Invoke-DependencyAudit.ps1`
- [ ] `docs/sec-docs/log.md` has a new entry for this run

## Incremental-only checks

- [ ] New `last-scan` timestamp is later than the previous one
- [ ] Only pages for re-analysed categories have an updated `last-updated` frontmatter field
- [ ] Within updated pages, only impacted requirements have refreshed evidence (unless
      scope extension was triggered — document the extension reason in the log)
- [ ] Unchanged requirements within updated pages preserve their previous status and evidence verbatim
