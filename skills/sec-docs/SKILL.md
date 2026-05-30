---
name: sec-docs
description: >
  Use this skill when the user asks to generate or refresh security compliance docs,
  run security analysis, analyze ASVS, check OWASP compliance, update security docs,
  or invokes /sec-docs. Performs OWASP ASVS v5 security analysis category by category.
  Multi-repository variant: the workspace is a docs repo with one or more sibling code
  repos checked out as first-level child directories (docs live OUTSIDE the documented
  repos). Use sec-docs-mini instead when scanning a single repository where docs live
  INSIDE the repo (docs/sec-docs/ alongside the code).
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# SecDocs Skill

Generates and incrementally maintains OWASP ASVS v5 security compliance documentation
under `docs/sec-docs/`. One markdown file per ASVS category, each containing a
structured per-requirement assessment with status, findings, and evidence sourced
directly from the codebase. Curated docs declare intent and accepted risks; generated
docs surface observed compliance; source code is the only proof.

## Core Principle

**RULE:** Curated docs declare intent and accepted risks. Generated docs surface observed compliance per ASVS v5. Source code is the only proof — never assert a compliance status without verified code evidence.

Constraints in this skill are tagged by category:
- `[HARD-EVIDENCE]` — source-citation and verification rules; a violation produces an unfounded compliance verdict.
- `[HARD-WRITE]` — output and file-write policy; a violation corrupts or overwrites human-owned or append-only artefacts.

**CONSTRAINT [HARD-EVIDENCE]:** Every requirement status must be supported by at least one source citation — file path and line range when localized. A requirement without code evidence must be marked `NOT-ASSESSED`, not inferred.

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

## Audit Integrations

Five orchestrator-driven audits feed ASVS categories with external evidence. Run each
orchestrator once per invocation **before** any category it feeds.

| Integration | Feeds categories | Reference |
|---|---|---|
| Entra ID app registrations and tenant policies (Microsoft Graph) | V6, V7, V8, V9, V10, V11, V13 | `references/entraid/audit-integration.md` |
| HTTP security response headers | V3, V12 (redirect), V13 | `references/headers/audit-integration.md` |
| TLS handshake and certificate posture | V11 (cert key size), V12 | `references/tls/audit-integration.md` |
| Azure Key Vault and App Configuration (ARM + Azure CLI) | V11 (key sizes), V13 | `references/azure/audit-integration.md` |
| Dependency vulnerabilities (`dotnet list package --vulnerable`, `npm audit`) | V15 | `references/deps/audit-integration.md` |

Load `references/audit-integration-shared.md` once for the shared 4-phase pattern,
manifest format, JSON schema, and citation form. Then load each integration's
reference file when running that orchestrator step.

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
| `--all` | In Incremental mode, re-analyse all 17 categories regardless of what changed (bypass change-to-category mapping). Use when you suspect cross-cutting impact or want a full posture refresh. Unlike `--init`, `--all` preserves the existing run log and the index's repo list/baselines, and refreshes pages in place; use `--init` only when rebuilding the documentation set from scratch. |

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

**CONSTRAINT [HARD-EVIDENCE]:** Never assert PASS, FAIL, or PARTIAL without a source citation.
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

**CONSTRAINT [HARD-EVIDENCE]:** Source code verification is mandatory before any PASS, FAIL, or
PARTIAL verdict. Never propagate a status from curated or generated docs without
confirming against current code.

## Run Log

At the **end of every run** (after all pages are written, before the Verification
Checklist), append one entry to `docs/sec-docs/log.md`. Load
`references/run-log-format.md` for the file header, the Init template, and the
Incremental template.

**CONSTRAINT [HARD-WRITE]:** Never rewrite or truncate `log.md` — only append. Do not embed
this history in `index.md` or any category page.

## Verification Checklist

Before reporting completion, run every check in
`references/verification-checklist.md`. The checklist covers Structure and Metadata,
Evidence Quality, Write Safety, and Incremental-only checks.

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
| `references/run-log-format.md` | Writing the run log entry at end of run |
| `references/verification-checklist.md` | Verifying completion at end of run |
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
