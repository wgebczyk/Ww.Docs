---
name: sec-docs
description: >
  Use this skill when the user asks to generate or refresh security compliance docs,
  run security analysis, analyze ASVS, check security compliance, update security docs,
  or invokes /sec-docs. Multi-repository variant: the workspace contains the docs
  repo at its root and one or more sibling code repos checked out as first-level
  child directories (docs live OUTSIDE the documented repos). Use sec-docs-mini
  instead when scanning a single repository where docs live INSIDE the repo
  (docs/sec-docs/ alongside the code). Performs OWASP ASVS v5 security analysis
  category by category and maintains structured compliance documentation in
  docs/sec-docs/. Works for any number of repositories and any technology stack.
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

# SecDocs Skill

Generates and incrementally maintains OWASP ASVS v5 security compliance documentation
under `docs/sec-docs/`. One markdown file per ASVS category, each containing a
structured per-requirement assessment with status, findings, and evidence sourced
directly from the codebase. Curated docs declare intent and accepted risks; generated
docs surface observed compliance; source code is the only proof.

## Core Principle

**RULE:** Curated docs declare intent and accepted risks. Generated docs surface observed compliance per ASVS v5. Source code is the only proof — never assert a compliance status without verified code evidence.

**CONSTRAINT [HARD]:** Every requirement status must be supported by at least one source citation — file path and line range when localized. A requirement without code evidence must be marked `NOT-ASSESSED`, not inferred.

## Analysis Order

Process ASVS categories in the sequence V1 → V17, one at a time, to avoid context
overflow. Generate the OWASP Top 10 report **after** all 17 category files have been
written — it pulls evidence from them rather than re-analysing the codebase.

Do not batch multiple categories into a single analysis pass.

## ASVS Category Registry

Load the relevant reference file at the start of each category analysis — do not call
any external ASVS tool.

| Category ID | Reference File | Output File |
|---|---|---|
| V1 | `references/asvs_v1_encoding_sanitization.md` | `pages/asvs_v1_encoding_sanitization.md` |
| V2 | `references/asvs_v2_validation_business_logic.md` | `pages/asvs_v2_validation_business_logic.md` |
| V3 | `references/asvs_v3_web_frontend.md` | `pages/asvs_v3_web_frontend.md` |
| V4 | `references/asvs_v4_api_web_service.md` | `pages/asvs_v4_api_web_service.md` |
| V5 | `references/asvs_v5_file_handling.md` | `pages/asvs_v5_file_handling.md` |
| V6 | `references/asvs_v6_authentication.md` | `pages/asvs_v6_authentication.md` |
| V7 | `references/asvs_v7_session_management.md` | `pages/asvs_v7_session_management.md` |
| V8 | `references/asvs_v8_authorization.md` | `pages/asvs_v8_authorization.md` |
| V9 | `references/asvs_v9_self_contained_tokens.md` | `pages/asvs_v9_self_contained_tokens.md` |
| V10 | `references/asvs_v10_oauth_oidc.md` | `pages/asvs_v10_oauth_oidc.md` |
| V11 | `references/asvs_v11_cryptography.md` | `pages/asvs_v11_cryptography.md` |
| V12 | `references/asvs_v12_secure_communication.md` | `pages/asvs_v12_secure_communication.md` |
| V13 | `references/asvs_v13_configuration.md` | `pages/asvs_v13_configuration.md` |
| V14 | `references/asvs_v14_data_protection.md` | `pages/asvs_v14_data_protection.md` |
| V15 | `references/asvs_v15_secure_coding.md` | `pages/asvs_v15_secure_coding.md` |
| V16 | `references/asvs_v16_security_logging.md` | `pages/asvs_v16_security_logging.md` |
| V17 | `references/asvs_v17_webrtc.md` | `pages/asvs_v17_webrtc.md` |

## OWASP Top 10 2025 Registry

Generate one cross-cutting report mapping findings to the OWASP Top 10 2025 after all
17 ASVS category files are written.

| Source | Reference File | Output File |
|---|---|---|
| OWASP Top 10 2025 | `references/owasp_top10_2025.md` | `pages/asvs_top10_owasp.md` |

## Entra ID Audit Integration

Audits Entra ID (Azure AD) app registrations and tenant policies via Microsoft Graph.
Evidence feeds V6, V7, V8, V9, V10, V11, V13. Run the orchestrator step once per
invocation, before any of those categories.

**Load `references/entraid/audit-integration.md`** for full details: architecture,
unit discovery, orchestrator phases 1–4, manifest format, JSON schema, and ASVS
category mapping.

---

## HTTP Security Headers Audit Integration

Probes each deployable unit's base URL for HTTP security response headers.
Evidence feeds V3, V12 (redirect), V13. Run the orchestrator step once per
invocation before those categories.

**Load `references/headers/audit-integration.md`** for full details: architecture,
URL discovery, orchestrator phases 1–4, manifest format, JSON schema, and ASVS
category mapping.

---

## TLS Audit Integration

Performs TLS handshakes against each deployable endpoint to assess protocol and
certificate posture. Evidence feeds V11 (cert key size), V12.
Run the orchestrator step once per invocation before those categories.

**Load `references/tls/audit-integration.md`** for full details: architecture,
hostname discovery, orchestrator phases 1–4, manifest format, JSON schema, ASVS
category mapping, and the downgrade-testing limitation note.

---

## Azure Resource Audit Integration

Audits Azure Key Vault and App Configuration stores via ARM REST API and Azure CLI.
Evidence feeds V11 (key sizes), V13. Run the orchestrator step once per invocation
before those categories.

**Load `references/azure/audit-integration.md`** for full details: architecture,
Key Vault and App Config discovery, orchestrator phases 1–4, dual-manifest format,
JSON schema, and ASVS category mapping.

---

## Dependency Vulnerability Audit Integration

Runs `dotnet list package --vulnerable` and `npm audit` across all solution and
workspace roots. Evidence feeds V15. Run the orchestrator step once per invocation
before that category.

**Load `references/deps/audit-integration.md`** for full details: architecture,
.NET solution and npm workspace discovery, orchestrator phases 1–4, manifest format,
JSON schema, and ASVS category mapping.

---

## Mode Detection

Determine mode before any other work. Flags take precedence over file-state detection.

| Condition | Mode |
|---|---|
| `--init` flag passed | **Init** — if `index.md` already exists, report which pages will be overwritten before proceeding |
| `--update` flag passed | **Incremental** |
| No flag; `docs/sec-docs/index.md` does not exist | **Init** |
| No flag; `docs/sec-docs/index.md` exists | **Incremental** — read YAML frontmatter, extract `last-scan` and `repositories[].last-commit-hash` |

## Flags

| Flag | Effect |
|---|---|
| `--init` | Force Init mode. If `index.md` already exists, report which pages will be overwritten before proceeding. |
| `--update` | Force Incremental mode. |
| `--category V6,V11` | Restrict analysis to the specified comma-separated category IDs, regardless of mode. |
| `--all` | In Incremental mode, re-analyse all 17 categories regardless of what changed (bypass change-to-category mapping). Use when you suspect cross-cutting impact or want a full posture refresh without re-running Init. |

## Write Constraint

Only these paths are writable:

- `docs/sec-docs/index.md` — hub index, updated each run
- `docs/sec-docs/log.md` — append-only run log; never rewrite or truncate
- `docs/sec-docs/pages/` — agent-written ASVS category pages and OWASP Top 10 report

`docs/sec-docs/curated/` is human-owned and read-only for the agent (security context,
accepted risks, compensating controls). All other paths are read-only. If a write would
target any other path, stop and report the violation.

Within `docs/sec-docs/reports/{integration}/`: the skill may write **only** the
orchestrator file `Invoke-*.ps1` (creates it on first run; updates only the manifest
block on subsequent runs). All other files in that directory — JSON and Markdown
audit output — are written by the audit script, not by the skill.

## Citation Rules

Every compliance status claim must be followed by a source reference:

```
(source: repo-name/path/to/file.ext)
```

Paths are relative to the workspace root. For localized findings, include line range:
`repo-name/path/to/file.ext:Lstart-Lend`.

If two sources contradict each other, write both citations and flag the conflict:

```
[CONFLICT: repo-a/file.cs says X; repo-b/other.ts says Y]
```

**CONSTRAINT [HARD]:** Never assert PASS, FAIL, or PARTIAL without a source citation.
Requirements with no verifiable code evidence must be `NOT-ASSESSED`.

## Curated Docs Integration

Before any codebase analysis, read all files matching `docs/sec-docs/curated/**/*.md`.
If the directory does not exist, skip silently.

For each curated file:

1. Note its filename stem and check for `topic:`, `category:`, or `entraid` YAML frontmatter.
2. If frontmatter maps to a category (e.g. `category: V6`), treat it as authoritative context
   for that category's Technology Context section.
3. In the corresponding category page, cite with `(source: docs/sec-docs/curated/filename.md)`.
4. If source code disagrees with curated content, add
   `[NOTE: curated says X; code analysis suggests Y — verify with team]` and record the
   mismatch in the category page.
5. When a curated doc explicitly accepts a risk or names a compensating control, do not mark
   the requirement as FAIL — cite the curated doc and record under "Accepted Risks".
6. Re-read `docs/sec-docs/curated/` on every run — the user may have updated curated docs
   between git commits.

## Verification-First Answer Protocol

When answering analysis prompts with this skill:

1. Read relevant curated and generated pages.
2. Extract declared intent, accepted risks, and compensating controls.
3. Translate intent into hypotheses about where security controls should appear in code.
4. Verify hypotheses in current source code from a narrowed scope.
5. Expand search to hidden paths: middleware, filters, config transforms, DI wiring,
   environment-specific overrides, feature flags, legacy endpoints, and generated code.
6. Determine requirement status from verified code evidence — never from docs alone.
7. Call out drift between curated intent and code, accepted risks, and suggested doc or
   code updates.

**CONSTRAINT [HARD]:** Source code verification is mandatory before any PASS, FAIL, or
PARTIAL verdict. Never propagate a status from curated or generated docs without
confirming against current code.

## Run Log

At the **end of every run** (after all pages are written, before the Verification
Checklist), append one entry to `docs/sec-docs/log.md`. Create the file with a header
if it does not yet exist:

```markdown
# SecDocs Run Log

<!-- append-only: one entry per run, newest last -->
```

For **Init** runs:
```markdown
## {ISO-8601 UTC timestamp} — Init
- Repos: {comma-separated repo names}
- Categories documented: {N}
- Requirements assessed: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Curated files incorporated: {N}
- Top 10 items covered: {N}/10
- Entra ID audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Headers audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- TLS audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Azure audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Deps audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
```

For **Incremental** runs:
```markdown
## {ISO-8601 UTC timestamp} — Incremental
- Repos checked: {N} ({N} with changes)
- Categories updated: {N} (by change mapping: {N}, by extension: {N})
- Requirements re-assessed: {N} (out of {total})
- Requirements preserved: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Status changes: {N} (list: V#.#.#: old → new, ...)
- Curated files incorporated: {N}
- Top 10 report regenerated: yes/no
- Entra ID audit: {incorporated new results/no new results}
- Headers audit: {incorporated new results/no new results}
- TLS audit: {incorporated new results/no new results}
- Azure audit: {incorporated new results/no new results}
- Deps audit: {incorporated new results/no new results}
```

**CONSTRAINT [HARD]:** Never rewrite or truncate `log.md` — only append. Do not embed
this history in `index.md` or any category page.

## Verification Checklist

Run these checks before reporting completion.

**Structure and Metadata**
- [ ] `docs/sec-docs/index.md` exists and has valid YAML frontmatter with `last-scan`,
      `asvs-version`, and `repositories`
- [ ] Every link in `index.md` body resolves to a file that exists on disk
- [ ] Every category page has valid YAML frontmatter with `category-id`, `last-updated`,
      `source-repos`, and `status-summary`
- [ ] Every category page has: Summary, Technology Context, and one section per requirement
- [ ] Every requirement section has: Level badge, Status badge, Requirement text,
      Findings, Evidence
- [ ] `docs/sec-docs/pages/asvs_top10_owasp.md` exists and contains a section for each
      of the 10 OWASP Top 10 2025 items
- [ ] Each Top 10 section has: Description, ASVS cross-references, Status, Findings,
      Evidence
- [ ] Repositories tracked in `index.md` match repos found on disk
- [ ] Each `last-commit-hash` in `index.md` matches `cd {path} && git log -1 --format=%H`

**Evidence Quality**
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

**Write Safety**
- [ ] No write targeted `docs/sec-docs/curated/`
- [ ] No write targeted `docs/sec-docs/reports/entraid/` except `Invoke-EntraIDAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/headers/` except `Invoke-HttpHeadersAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/tls/` except `Invoke-TlsAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/azure/` except `Invoke-AzureResourceAudit.ps1`
- [ ] No write targeted `docs/sec-docs/reports/deps/` except `Invoke-DependencyAudit.ps1`
- [ ] `docs/sec-docs/log.md` has a new entry for this run

For Incremental runs, also check:
- [ ] New `last-scan` timestamp is later than the previous one
- [ ] Only pages for re-analysed categories have an updated `last-updated` frontmatter field
- [ ] Within updated pages, only impacted requirements have refreshed evidence (unless
      scope extension was triggered — document the extension reason in the log)
- [ ] Unchanged requirements within updated pages preserve their previous status and evidence verbatim

## Init Workflow

Load `references/init-workflow.md` — depth standard and step-by-step procedure.

## Incremental Workflow

Load `references/update-workflow.md` — step-by-step procedure.

## Reference Files

Load these as needed — they are not in context by default:

| File | Load when |
|---|---|
| `references/init-workflow.md` | Starting Init mode (full procedural detail) |
| `references/update-workflow.md` | Starting Incremental (Update) mode (full procedural detail) |
| `references/category-page-template.md` | Writing or updating any category page or the Top 10 report |
| `references/owasp_top10_2025.md` | Generating `docs/sec-docs/pages/asvs_top10_owasp.md` |
| `references/azure-pipeline-template.yml` | Reviewing or generating the scheduled pipeline |
| `references/audit-integration-shared.md` | Before running any orchestrator step (shared 4-phase pattern, manifest rules, JSON schema, citation form) |
| `references/entraid/audit-integration.md` | Running the Entra ID orchestrator step |
| `references/headers/audit-integration.md` | Running the HTTP headers orchestrator step |
| `references/tls/audit-integration.md` | Running the TLS orchestrator step |
| `references/azure/audit-integration.md` | Running the Azure resource orchestrator step |
| `references/deps/audit-integration.md` | Running the dependency vulnerability orchestrator step |
| `docs/sec-docs/reports/entraid/entraid-audit-latest.json` | Assessing V6, V7, V8, V9, V10, V11, V13 categories |
| `docs/sec-docs/reports/headers/headers-audit-latest.json` | Assessing V3, V12 (HTTP→HTTPS), V13 header findings |
| `docs/sec-docs/reports/tls/tls-audit-latest.json` | Assessing V11 (cert key size), V12 TLS findings |
| `docs/sec-docs/reports/azure/azure-audit-latest.json` | Assessing V11, V13 Key Vault and App Config findings |
| `docs/sec-docs/reports/deps/deps-audit-latest.json` | Assessing V15 vulnerable component findings |

## Scripts

Each audit integration ships with the same five-script shape: a utility module
(`*.Utils.psm1`), one or two `Test-*.ps1` audit drivers, a `Write-*Report.ps1`
emitter, and an `Invoke-*.template.ps1` orchestrator template. The project-level
orchestrator under `docs/sec-docs/reports/{X}/Invoke-*.ps1` is generated and
edited by the skill (manifest block only); the rest are immutable skill assets.

| Integration | Skill assets (immutable) | Project orchestrator (generated) |
|---|---|---|
| Entra ID | `references/entraid/{EntraIDAudit.Utils.psm1, Test-EntraIDAppRegistration.ps1, Test-EntraIDTenantPolicies.ps1, Write-EntraIDAuditReport.ps1, Invoke-EntraIDAudit.template.ps1}` | `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` |
| HTTP Headers | `references/headers/{HttpHeadersAudit.Utils.psm1, Test-HttpSecurityHeaders.ps1, Write-HttpHeadersAuditReport.ps1, Invoke-HttpHeadersAudit.template.ps1}` | `docs/sec-docs/reports/headers/Invoke-HttpHeadersAudit.ps1` |
| TLS | `references/tls/{TlsAudit.Utils.psm1, Test-TlsEndpoint.ps1, Write-TlsAuditReport.ps1, Invoke-TlsAudit.template.ps1}` | `docs/sec-docs/reports/tls/Invoke-TlsAudit.ps1` |
| Azure Resources | `references/azure/{AzureResourceAudit.Utils.psm1, Test-AzureKeyVault.ps1, Test-AzureAppConfig.ps1, Write-AzureResourceAuditReport.ps1, Invoke-AzureResourceAudit.template.ps1}` | `docs/sec-docs/reports/azure/Invoke-AzureResourceAudit.ps1` |
| Dependencies | `references/deps/{DependencyAudit.Utils.psm1, Test-DotnetVulnerabilities.ps1, Test-NpmAudit.ps1, Write-DependencyAuditReport.ps1, Invoke-DependencyAudit.template.ps1}` | `docs/sec-docs/reports/deps/Invoke-DependencyAudit.ps1` |

The pipeline in `references/azure-pipeline-template.yml` runs all five project
orchestrators before the sec-docs skill on every scheduled execution.
