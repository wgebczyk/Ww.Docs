---
name: sec-docs-mini
description: >
  Use this skill when the user asks to generate or refresh security compliance docs,
  run security analysis, analyze ASVS, check security compliance, update security docs,
  or invokes /sec-docs-mini. Single-repository variant of sec-docs: scans the current
  folder and below (repo root). Performs OWASP ASVS v5 security analysis category by
  category and maintains structured compliance documentation in docs/sec-docs/. Works
  for any technology stack.
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

# SecDocs-Mini Skill

Generates and incrementally maintains OWASP ASVS v5 security compliance documentation
under `docs/sec-docs/`. One markdown file per ASVS category, each containing a
structured per-requirement assessment with status, findings, and evidence sourced
directly from the codebase at the current working directory. Curated docs declare
intent and accepted risks; generated docs surface observed compliance; source code
is the only proof.

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

Entra ID (Azure AD) audit evidence is produced by a PowerShell orchestrator that
lives inside the project's docs folder and is **maintained by this skill** — not by
the user. The orchestrator delegates the actual Graph API work to immutable utility
scripts that ship with the skill. The skill does not call Microsoft Graph itself.

### Architecture

```
references/entraid/              ← skill-owned (IMMUTABLE)
├── EntraIDAudit.Utils.psm1                # Graph auth + finding helpers (null-safe)
├── Test-EntraIDAppRegistration.ps1        # audit ONE app registration  -> finding[]
├── Test-EntraIDTenantPolicies.ps1         # tenant-wide policies        -> finding[]
├── Write-EntraIDAuditReport.ps1           # write JSON + Markdown reports
└── Invoke-EntraIDAudit.template.ps1       # template for the orchestrator below

docs/sec-docs/reports/entraid/                           ← skill-managed (per project)
├── Invoke-EntraIDAudit.ps1                # orchestrator — generated + edited by skill
├── entraid-audit-latest.json              # audit output (skill reads this)
├── entraid-audit-latest.md                # audit output (cited from category pages)
├── entraid-audit-{ts}.json                # historical copy
└── entraid-audit-{ts}.md                  # historical copy
```

**Immutable contracts (never write to these from a project run):**
- All files under `references/entraid/`. These are part of
  the skill definition. The skill **reads** the orchestrator template and **calls**
  the utility scripts; it must not modify them.

**Skill-managed area (the skill creates and edits these):**
- `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` — orchestrator with a
  hardcoded manifest of the project's deployable units and their app registrations.

**Read-only output (script writes, skill reads):**
- `docs/sec-docs/reports/entraid/entraid-audit-latest.json` — consumed when
  assessing ASVS V6, V7, V8, V9, V10, V11, V13.

### Deployable Units Model

A "deployable unit" is an independently deployed component of the project
(e.g. `api`, `web`, `worker`, `integration`). A single repo may have one unit or
several. Each unit may have:

- **zero app registrations** — a public website with no Entra ID auth
- **one app registration** — typical API or web app
- **multiple app registrations** — e.g. an API plus a SPA, or one per environment
  (Dev / QA / Prod)

The manifest in the orchestrator captures this fully as a flat list:
`@{ Unit; Environment; ClientId; DisplayName }`.

### Orchestrator Step — What the Skill Must Do

Run this step **once per sec-docs-mini invocation**, before any ASVS category that
maps to Entra ID. The step has four phases.

#### Phase 1 — Discover deployable units + app registrations

Detect units within the current repository. The signals, in order of authority:

| Signal | Source |
|---|---|
| Explicit declaration | A `docs/sec-docs/curated/*.md` file with frontmatter `topic: entraid` and a top-level `deployable-units:` list. **Overrides everything else.** |
| Multi-unit repo | `src/<name>/`, `services/<name>/`, `apps/<name>/`, or services in `docker-compose.yml` inside the repo. |
| Helm chart packaging | One unit per top-level chart directory. |
| Fallback | The repo itself is the single deployable unit; use the repo directory name as the unit name. |

For each unit, scan its subtree for app registrations:

| Source | Keys to read |
|---|---|
| `appsettings*.json`, `*.settings.json`, `local.settings.json` | `AzureAd:ClientId`, `AzureAD:ClientId`, `EntraId:ClientId`, `MicrosoftIdentity:ClientId`, `Authentication:ClientId` (and matching `:TenantId`) |
| `.env`, `*.env`, `.env.*` | `AZURE_CLIENT_ID` / `CLIENT_ID`, `AZURE_TENANT_ID` / `TENANT_ID` |
| `helm/values*.yaml`, `values-*.yaml` | `clientId:`, `tenantId:` |
| `docker-compose*.yml`, `*.compose.yml` | `CLIENT_ID` / `AZURE_CLIENT_ID` in `environment:` sections |

Exclude `node_modules/`, `.git/`, `bin/`, `obj/`.

A single unit may have **multiple** distinct app registrations — e.g. an API
and a SPA, or one per environment. Record each one separately. When a unit
has multiple, set `DisplayName` so the role is identifiable (e.g. `"web Dev (API)"`,
`"web Dev (SPA)"`).

Derive `Environment` from path/filename hints (`Dev`, `QA`, `Stage`, `Prod`) or
from explicit metadata in curated docs. Use `"Unknown"` if no label is derivable.

Derive `TenantId` from the same sources or from a curated doc. If multiple
tenant IDs appear, prefer the one from a curated doc; otherwise pick the most
common and surface the conflict in the run log.

#### Phase 2 — Read the existing orchestrator manifest

Read `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` if it exists. Locate
the block bounded by these exact lines:

```
# === MANIFEST BEGIN === (skill-managed; do not hand-edit between these markers)
...
# === MANIFEST END ===
```

Parse `$TenantId` and the `$Applications` array (entries: `Unit`, `Environment`,
`ClientId`, `DisplayName`). This is the "previous" manifest.

#### Phase 3 — Generate or edit the orchestrator

| State | Action |
|---|---|
| Orchestrator file does not exist | Copy `references/entraid/Invoke-EntraIDAudit.template.ps1` to `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1`, then replace the manifest block with the discovered manifest. |
| Orchestrator exists; discovered manifest matches the previous manifest | Do nothing. |
| Orchestrator exists; manifests differ (new unit / new env / new ClientId / removed entry / TenantId change) | Use the `Edit` tool to replace **only the lines between** `# === MANIFEST BEGIN ===` and `# === MANIFEST END ===`. Do not touch anything else. |
| Orchestrator exists but the part outside the markers has been hand-modified (e.g. extra `Write-Host`, custom orchestration) | Stop. Report exactly what diverged and let the user decide. Do not silently overwrite. |

**Manifest formatting rules** (must be followed exactly so Edit operations are
predictable):

- The `$Applications` array contains one hashtable per line.
- Order entries by `Unit`, then `Environment`, then `ClientId`.
- Each hashtable uses this key order: `Unit`, `Environment`, `ClientId`, `DisplayName`.
- Two-space indentation inside the array. No trailing comma after the last entry.
- Always emit `Unit` (use `""` if not applicable), `Environment` (use `"Unknown"`
  if not derivable), and `DisplayName` (use the unit/env combo if no better
  name is available).

**Canonical example** of a written manifest block (whitespace-sensitive):

```powershell
# === MANIFEST BEGIN === (skill-managed; do not hand-edit between these markers)

# Tenant GUID. Replaced by the sec-docs skill on first generation.
$TenantId = "11111111-0000-0000-0000-111111111111"

# Deployable units and their app registrations.
# A project may have several units (api, web, worker, ...).
# A unit may have one or more app registrations across environments.
# Each entry: @{ Unit; Environment; ClientId; DisplayName }
$Applications = @(
    @{ Unit = "api1"; Environment = "Dev";  ClientId = "22222222-0000-0000-0000-222222222222"; DisplayName = "api1 Dev"  }
    @{ Unit = "api1"; Environment = "Prod"; ClientId = "33333333-0000-0000-0000-333333333333"; DisplayName = "api1 Prod" }
    @{ Unit = "web";  Environment = "Dev";  ClientId = "44444444-0000-0000-0000-444444444444"; DisplayName = "web Dev"   }
)

# === MANIFEST END ===
```

**CONSTRAINT [HARD]:** Never modify files under
`references/entraid/` from a project run. If a check is
missing or wrong, add it to the skill definition in a separate change — not
inline in the orchestrator.

#### Phase 4 — Run or load the audit

In a **pipeline run**, the pipeline executes the orchestrator directly; the JSON
will exist when the skill starts.

In an **interactive run**:
- If `docs/sec-docs/reports/entraid/entraid-audit-latest.json` exists and is no
  more than 7 days older than the repo HEAD timestamp, read it directly.
- Otherwise, instruct the user to run:
  ```powershell
  .\docs\sec-docs\reports\entraid\Invoke-EntraIDAudit.ps1 -RepoRoot .
  ```
- If the user declines, mark every ASVS requirement that depends on Entra ID
  audit evidence as `NOT-ASSESSED` (see ASVS Category Mapping below) and note
  the reason on each affected category page.

### Reading Audit Results

Read `docs/sec-docs/reports/entraid/entraid-audit-latest.json`:

| Field | Meaning |
|---|---|
| `auditDate` | ISO-8601 UTC of script execution |
| `tenantId` | tenant GUID audited |
| `applications` | `[{ Unit, Environment, ClientId, DisplayName }]` — what was audited |
| `findings` | each finding has `Id`, `Asvs`, `Owasp`, `Status`, `Title`, `Detail`, `Evidence`, `AppId`, `AppEnv`, `AppUnit` |
| `summary` | counts: `pass`, `fail`, `warn`, `unable`, `total` |
| `asvsMapping` | `[{ asvs, overallStatus, findingIds }]` rollup per ASVS requirement |

When citing audit evidence in a category page, use this exact form:
```
(source: docs/sec-docs/reports/entraid/entraid-audit-latest.md — finding {Id})
```
Include the `AppUnit` and `AppEnv` of the finding when reporting status so the
reader sees which deployable unit / environment was the source of evidence.

### ASVS Category Mapping

Incorporate Entra ID audit findings into these category pages as additional evidence:

| ASVS Category | Finding `asvs` values to pull |
|---|---|
| V6 Authentication | `V6.1.1`, `V6.3.3` |
| V7 Session Management | `V7.2.2`, `V9.2.1` (token lifetime) |
| V8 Authorization | `V8.2.1`, `V8.3.1`, `V8.4.1` |
| V9 Self-contained Tokens | `V9.1.2`, `V9.1.3`, `V9.2.1`, `V9.2.3` |
| V10 OAuth and OIDC | `V10.4.1`, `V10.4.4`, `V10.4.11` |
| V11 Cryptography | `V11.2.3` |
| V13 Configuration | `V13.3.1` |

If the audit JSON does not exist, mark these requirements as `NOT-ASSESSED` and
add this note to each affected category page:
> Entra ID audit not yet run. Orchestrator at
> `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` exists; run it to
> produce evidence.

### Entraid Output in Index

Add a row to `docs/sec-docs/index.md` indicating whether the Entra ID audit has
been run and the date of the last audit. Include the per-unit / per-environment
app count from the manifest. See `references/category-page-template.md`.

## Mode Detection

Determine mode before any other work. Flags take precedence over file-state detection.

| Condition | Mode |
|---|---|
| `--init` flag passed | **Init** — if `index.md` already exists, report which pages will be overwritten before proceeding |
| `--update` flag passed | **Incremental** |
| No flag; `docs/sec-docs/index.md` does not exist | **Init** |
| No flag; `docs/sec-docs/index.md` exists | **Incremental** — read YAML frontmatter, extract `last-scan` and `last-commit-hash` |

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

Within `docs/sec-docs/reports/entraid/`: the skill may write **only** the orchestrator
file `Invoke-EntraIDAudit.ps1` (creates it on first run; updates only the manifest
block on subsequent runs). All other files in that directory — JSON and Markdown audit
output — are written by the script, not by the skill.

## Citation Rules

Every compliance status claim must be followed by a source reference:

```
(source: path/to/file.ext)
```

Paths are relative to the repository root. For localized findings, include line range:
`path/to/file.ext:Lstart-Lend`.

If two sources contradict each other, write both citations and flag the conflict:

```
[CONFLICT: path/file-a.cs says X; path/file-b.ts says Y]
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
- Categories documented: {N}
- Requirements assessed: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Curated files incorporated: {N}
- Top 10 items covered: {N}/10
- Entra ID audit: {run/not-run} | PASS: {N} FAIL: {N} WARN: {N}
```

For **Incremental** runs:
```markdown
## {ISO-8601 UTC timestamp} — Incremental
- Categories updated: {N} (by change mapping: {N}, by extension: {N})
- Requirements re-assessed: {N} (out of {total})
- Requirements preserved: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Status changes: {N} (list: V#.#.#: old → new, ...)
- Curated files incorporated: {N}
- Top 10 report regenerated: yes/no
- Entra ID audit: {incorporated new results/no new results}
```

**CONSTRAINT [HARD]:** Never rewrite or truncate `log.md` — only append. Do not embed
this history in `index.md` or any category page.

## Verification Checklist

Run these checks before reporting completion.

**Structure and Metadata**
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

**Evidence Quality**
- [ ] Every PASS, FAIL, or PARTIAL verdict has at least one `(source: ...)` citation
- [ ] Every `docs/sec-docs/curated/` file is cited in at least one category page
- [ ] If `docs/sec-docs/reports/entraid/entraid-audit-latest.json` exists: at least one
      Entra ID finding is cited in V6, V7, V8, V9, V10, V11, or V13 category pages
- [ ] No requirement is marked PASS without a verifiable code reference

**Write Safety**
- [ ] No write targeted `docs/sec-docs/curated/`
- [ ] No write targeted `docs/sec-docs/reports/entraid/` except `Invoke-EntraIDAudit.ps1`
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
| `references/init-workflow.md` | Starting Init mode |
| `references/update-workflow.md` | Starting Incremental (Update) mode |
| `references/workflow-guide.md` | Full procedural detail for either mode |
| `references/category-page-template.md` | Writing or updating any category page or the Top 10 report |
| `references/owasp_top10_2025.md` | Generating `docs/sec-docs/pages/asvs_top10_owasp.md` |
| `docs/sec-docs/reports/entraid/entraid-audit-latest.json` | Assessing V6, V7, V8, V9, V10, V11, V13 categories |

## Scripts

| Script | Purpose | Owner |
|---|---|---|
| `references/entraid/EntraIDAudit.Utils.psm1` | Shared helpers: Graph auth, finding builder, null-safe accessors, role discovery | Skill (immutable) |
| `references/entraid/Test-EntraIDAppRegistration.ps1` | Audits one app registration via Graph; returns findings | Skill (immutable) |
| `references/entraid/Test-EntraIDTenantPolicies.ps1` | Audits tenant policies (OIDC, JWKS, CA, security defaults, token lifetime); returns findings | Skill (immutable) |
| `references/entraid/Write-EntraIDAuditReport.ps1` | Writes `entraid-audit-latest.json` + `.md` consumed by sec-docs | Skill (immutable) |
| `references/entraid/Invoke-EntraIDAudit.template.ps1` | Template for the project-level orchestrator | Skill (immutable) |
| `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` | Project orchestrator: holds manifest, calls utilities | Skill (generated + edited per project) |
