# Workflow Guide

Full procedural detail for both operating modes. Load this file at the start
of every run before doing any analysis.

---

## Part A — Init Mode

Run when `docs/sec-docs/index.md` does not exist, or when `--init` is passed.

### Step 1 — Create directory structure

Create `docs/sec-docs/`, `docs/sec-docs/pages/`, and `docs/sec-docs/curated/` if absent.
Do not write content into `docs/sec-docs/curated/` — that directory is human-owned and read-only.
The `docs/sec-docs/reports/entraid/` directory is created by the Entra ID audit script, not by the skill.

```powershell
New-Item -ItemType Directory -Force -Path "docs/sec-docs"
New-Item -ItemType Directory -Force -Path "docs/sec-docs/pages"
New-Item -ItemType Directory -Force -Path "docs/sec-docs/curated"
```

### Step 2 — Load ASVS category list

Read the Category Registry table from `SKILL.md` to get the full list of 17
categories, their reference files, and their output filenames. All ASVS
requirement data is stored in `references/asvs_v{N}_{short_title}.md` files —
do not call any external ASVS tool.

### Step 3 — Discover repositories

Scan the workspace root for directories that contain a `.git/` subdirectory.
Each such directory is a repository.

```powershell
Get-ChildItem -Path . -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }
```

Record for each repo:
- `name` — the directory name (e.g. `crackling-api`)
- `path` — same as name (relative to workspace root)

Exclude `docs/`, `.github/`, and any non-repo directories.

### Step 4 — Capture HEAD commit hashes

For each discovered repository:

```bash
cd {repo-path} && git log -1 --format=%H
```

Store the 40-character hash. Used as the baseline for incremental runs.

### Step 5 — Detect technology stack per repo

For each repository, identify:
- Primary language (inspect `*.csproj`, `package.json`, `go.mod`, `pom.xml`, `*.py`, etc.)
- Runtime and framework (ASP.NET Core, Express, Spring Boot, Django, Angular, React, etc.)
- Key security-relevant dependencies (auth middleware, crypto libraries, ORM, HTTP clients)
- Configuration files (`appsettings.json`, `web.config`, `.env`, `dockerfile`, `helm/`, etc.)

Record findings per repo. This context is used when writing the Technology
Context section of each category page and when searching for evidence.

### Step 6 — Discover deployable units + app registrations; sync orchestrator manifest

The Entra ID audit is run by a project-level orchestrator at
`docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1`. The orchestrator's
**manifest** (the block between `# === MANIFEST BEGIN ===` and `# === MANIFEST END ===`)
encodes the project's tenant, deployable units, and app registrations. This step's
job is to keep that manifest in sync with what the repo says today.

See SKILL.md → *Entra ID Audit Integration* for the full rule set. Procedure:

**6a — Discover deployable units.**
A unit is an independently deployed component (`api1`, `api2`, `web`, `app`,
`integration`, ...). Sources, in priority order:

| Signal | Source |
|---|---|
| Explicit | `docs/sec-docs/curated/*.md` with `topic: entraid` + `deployable-units:` |
| One repo per unit | `.git/`-containing directories at workspace root |
| Multi-unit repo | `src/<name>/`, `services/<name>/`, `apps/<name>/`, `docker-compose.yml` services |
| Helm | Top-level chart directories |

**6b — Discover app registrations per unit.**
For each unit, scan its subtree (skipping `node_modules/`, `.git/`, `bin/`,
`obj/`) for ClientId / TenantId values in:

| File pattern | Keys |
|---|---|
| `appsettings*.json`, `*.settings.json` | `AzureAd:*`, `AzureAD:*`, `EntraId:*`, `MicrosoftIdentity:*`, `Authentication:*` (`:ClientId`, `:TenantId`) |
| `.env`, `*.env`, `.env.*` | `AZURE_CLIENT_ID` / `CLIENT_ID`; `AZURE_TENANT_ID` / `TENANT_ID` |
| `helm/values*.yaml`, `values-*.yaml` | `clientId:`, `tenantId:` |
| `docker-compose*.yml` | `CLIENT_ID`, `AZURE_CLIENT_ID` in `environment:` blocks |

A unit may have **multiple** app registrations (API + SPA, or one per environment).
Derive `Environment` from filename/path hints (`Dev`, `QA`, `Stage`, `Prod`) or
from curated metadata; default to `"Unknown"` if no signal.

If no app registrations are found anywhere, the orchestrator is not needed —
note "Entra ID audit: not applicable" in the run log and skip Step 7.

**6c — Read the existing orchestrator manifest, if any.**
If `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` exists, read it and
parse the block between the `# === MANIFEST BEGIN ===` / `# === MANIFEST END ===`
markers. Extract:
- `$TenantId`
- `$Applications` entries (Unit, Environment, ClientId, DisplayName)

**6d — Decide write/edit/skip.**

| State | Action |
|---|---|
| Orchestrator missing | Copy `.claude/skills/sec-docs/references/entraid/Invoke-EntraIDAudit.template.ps1` to `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1`, then replace the manifest block with the discovered manifest. |
| Manifest matches discovery | Leave file untouched. |
| Manifest differs | Use `Edit` to replace ONLY the lines between the markers. Do not touch any other line. |
| Orchestrator hand-modified outside the markers | Stop and report — do not overwrite custom logic. |

Manifest formatting rules (whitespace-sensitive — required for predictable Edits):
- Entries sorted by `Unit`, then `Environment`, then `ClientId`.
- Hashtable key order: `Unit`, `Environment`, `ClientId`, `DisplayName`.
- One entry per line, two-space indent inside the array, no trailing comma.
- Always emit all four keys (`Unit = ""` if not applicable, `Environment = "Unknown"`,
  `DisplayName` = a fallback like `"$Unit $Environment"`).

**CONSTRAINT [HARD]:** Never write to any file under
`.claude/skills/sec-docs/references/entraid/` from a project run.

### Step 7 — Load or Request Entra ID Audit Results

Check whether `docs/sec-docs/reports/entraid/entraid-audit-latest.json` exists.

**File exists:**
- Read and parse the JSON.
- Check the `auditDate` field. If it predates the oldest git HEAD in Step 4 by
  more than 7 days, warn: "Entra ID audit may be stale — re-run the orchestrator."
- Proceed to Step 8 using the cached results.

**File does not exist (interactive run):**
- Confirm the orchestrator was created/updated in Step 6.
- Instruct the user:
  ```powershell
  .\docs\sec-docs\reports\entraid\Invoke-EntraIDAudit.ps1 `
      -RepoRoots .\<repo1>,.\<repo2>
  ```
- Optional flags: `-SkipPublicChecks` (air-gapped), `-SkipConditionalAccess`
  (when Policy.Read.All is unavailable).
- Offer to continue without the audit — Entra-ID-dependent requirements will be
  partially `NOT-ASSESSED`.
- In a **pipeline run**, the audit step runs before the skill and the file is
  always present.

**Reading the JSON (consumed schema):**
```json
{
  "auditDate": "...",
  "tenantId": "...",
  "applications": [
    { "Unit": "api1", "Environment": "Dev", "ClientId": "...", "DisplayName": "..." }
  ],
  "findings": [
    { "Id": "...", "Asvs": "V10.4.4", "Owasp": "A07",
      "Status": "PASS|FAIL|WARN|UNABLE|INFO",
      "Title": "...", "Detail": "...", "Evidence": "...",
      "AppId": "...", "AppEnv": "...", "AppUnit": "..." }
  ],
  "summary":  { "pass": 0, "fail": 0, "warn": 0, "unable": 0, "total": 0 },
  "asvsMapping": [
    { "asvs": "V10.4.4", "overallStatus": "PASS", "findingIds": ["..."] }
  ]
}
```

Index `findings` by `Asvs` for fast lookup in Step 9c.

### Step 8 — Read curated docs

Read all files matching `docs/sec-docs/curated/**/*.md`. If absent, skip.

For each file:
1. Parse YAML frontmatter. If a `category:` field matches a category ID (e.g. `V6`),
   that file is the authoritative context for that category.
2. If no frontmatter, treat the filename stem as a probable topic hint.
3. Store content indexed by category ID and topic name for use in Step 9.

### Step 9 — Analyse each category (one at a time)

Process categories in order V1 → V17. For each category:

#### 9a — Load ASVS requirements

Read the category's reference file from `references/asvs_v{N}_{short_title}.md`
(see the Category Registry in `SKILL.md` for the exact filename per category).
Do not proceed to 9b until the file has been fully read.

#### 9b — Build technology context

Using the stack information from Step 5 and curated docs from Step 8:
- Identify which repos and components are relevant to this category.
- Identify security-relevant files to search (middleware, config, auth handlers,
  database access layers, serializers, HTTP clients, etc.).
- Note any curated docs that apply to this category.

#### 9c — Assess each requirement

For each requirement in the reference file:

1. Read the requirement text carefully. Identify the control being verified.
2. **Check for Entra ID audit evidence** (Steps 6–7): if this category is V6, V7, V8, V9,
   V10, V11, or V13, look up matching findings from the audit JSON by `asvs` field.
   - If a finding exists: use its `status`, `title`, and `evidence` as primary evidence.
     Cite as: `(source: docs/sec-docs/reports/entraid/entraid-audit-latest.md — {finding.Id})`
   - If the audit was not run: mark the requirement `NOT-ASSESSED` with the note:
     "Entra ID audit not run — execute Invoke-EntraIDAudit.ps1 to obtain Graph API evidence."
3. Determine the codebase search strategy: what code patterns, config keys, or library
   usage would confirm or deny the control?
4. Search the relevant repositories for evidence (complements Entra ID audit evidence):
   - Use `search` or `fileSearch` to locate relevant files.
   - Read key files to extract specific evidence.
5. Assign a Status verdict (PASS / FAIL / PARTIAL / N/A / NOT-ASSESSED).
   When Entra ID audit evidence conflicts with codebase evidence, prefer the Graph API
   result (it is authoritative) and note the discrepancy.
6. Record all evidence with source citations.

**Assessment heuristics by requirement type:**

| Control Type | What to look for |
|---|---|
| Input validation | Validation middleware, model annotations, sanitizer libraries |
| Output encoding | Template engine escaping, response encoding config, CSP headers |
| SQL injection | ORM usage, parameterized queries, raw query calls |
| Authentication | Auth middleware, password hashing libraries, MFA setup |
| Session management | Session config, cookie flags (Secure, HttpOnly, SameSite), expiry |
| Authorization | Permission checks, role middleware, policy definitions |
| Cryptography | Cipher names, key sizes, IV handling, PRNG usage |
| TLS/HTTPS | Server config, cert pinning, protocol version constraints |
| Logging | Audit log calls, PII scrubbing, log level config |
| Error handling | Global error handlers, stack trace exposure in responses |
| Dependencies | Package manifests, known-vulnerability scanning config |
| Entra ID / OAuth | Entra ID audit JSON (`docs/sec-docs/reports/entraid/entraid-audit-latest.json`) |

#### 9d — Write category page

Write `docs/sec-docs/pages/{filename}` using the template in
`references/category-page-template.md`. Requirements:
- YAML frontmatter must include `status-summary` counts.
- Every requirement in the ASVS category must have a section (no omissions).
- Requirements are ordered by control ID (V#.#.# ascending).
- Every PASS or FAIL must have at least one sourced evidence bullet.

### Step 10 — Generate OWASP Top 10 2025 report

After all 17 category pages are written, generate the OWASP Top 10 2025 report.

1. Read `references/owasp_top10_2025.md`. This file contains each Top 10 item with
   its description, prevention guidance, and ASVS category mappings.
2. For each of the 10 items (A01–A10):
   a. Read the mapped ASVS category pages from `docs/sec-docs/` to extract relevant findings.
      Pull `status-summary` from frontmatter and specific requirement sections from the body.
   b. Aggregate the findings: summarise which requirements PASS, FAIL, or are PARTIAL.
   c. Set the item-level Status:
      - `PASS` — all mapped requirements PASS (or N/A)
      - `FAIL` — any mapped requirement FAILs
      - `PARTIAL` — mix of PASS and FAIL, or any PARTIAL requirements
      - `N/A` — the entire item is not applicable to this stack
      - `NOT-ASSESSED` — insufficient evidence across mapped categories
3. Write `docs/sec-docs/pages/asvs_top10_owasp.md` using the OWASP Top 10 Page Template
   from `references/category-page-template.md`.
4. Do **not** re-search the codebase — all evidence comes from the already-written
   category pages. Cite them as sources: `(source: docs/sec-docs/pages/asvs_vN_name.md#V#.#.#)`.

### Step 11 — Write index.md

Write `docs/sec-docs/index.md` with:

**YAML frontmatter:**
```yaml
---
last-scan: "{current-UTC-datetime-ISO-8601}"
asvs-version: "5.0"
repositories:
  - name: {repo-name}
    path: {repo-name}
    last-commit-hash: {hash-from-step-4}
---
```

**Body:** Full category table, OWASP Top 10 row, and overall posture summary as shown in the
index template in `references/category-page-template.md`. Pull per-category
counts from the `status-summary` frontmatter of each written category page.

### Step 12 — Write run log entry

Append an Init entry to `docs/sec-docs/log.md` per the format in SKILL.md.
Create the file with its header if it does not exist.

### Step 13 — Verify

Run the Verification Checklist from `SKILL.md`. Fix any failures before reporting.

### Step 14 — Report

Output a summary:
- Repositories discovered: list
- Categories documented: count and list
- Total requirements assessed: count
- Status breakdown: PASS / FAIL / PARTIAL / N/A / NOT-ASSESSED counts
- Curated files incorporated: count and list
- OWASP Top 10: item count and overall status (e.g. "3 PASS, 4 FAIL, 2 PARTIAL, 1 NOT-ASSESSED")
- Top FAIL items: list up to 5 most critical failures for immediate attention

---

## Part B — Incremental Mode

Run when `docs/sec-docs/index.md` exists and `--init` was not passed.

The Incremental workflow is **change-driven**: it begins from the git delta,
maps changes to affected ASVS categories using heuristics, and re-assesses
only impacted requirements within those categories. Scope extends
automatically when evidence cascades, but never defaults to full regeneration.

### Step 1 — Read existing metadata

Read `docs/sec-docs/index.md`. Parse YAML frontmatter:
- `last-scan` → timestamp of previous run
- `asvs-version` → ASVS version of previous run
- `repositories[].last-commit-hash` → git baseline per repo

If a repo listed in metadata no longer exists on disk, warn the user and skip it.
If a new repo exists that is not in the metadata, treat it as new: run full
stack detection (Part A Step 5) and include it in all category re-analyses.

### Step 2 — Re-read curated docs

Read all `docs/sec-docs/curated/**/*.md` regardless of changes.
Re-index by category ID and topic name (same as Part A Step 8).

### Step 3 — Detect codebase changes

For each repo in metadata:

```bash
cd {repo-path} && git log {last-commit-hash}..HEAD --name-only --format=
```

Record:
- List of changed file paths (relative to the repo root).
- Whether the output is empty (no new commits).

If `{last-commit-hash}` is no longer in history (after rebase/force-push),
fall back to full re-analysis for that repo.

### Step 4 — Map changes to ASVS categories

Use these **Category Relevance Heuristics** to determine which categories
are affected by the changed files:

| File change pattern | Affected categories |
|---|---|
| Input validation, model annotations, request DTOs, sanitizer code | V1, V2 |
| Frontend templates, CSP headers, response rendering, JS output | V3 |
| API controllers, route definitions, middleware pipeline, serializers | V4 |
| File upload/download handlers, storage config, MIME handling | V5 |
| Auth handlers, login/logout, password hashing, MFA setup, identity config | V6 |
| Session config, cookie settings, token refresh, session store | V7 |
| Authorization middleware, policies, role checks, permission models | V8 |
| JWT/token generation, token validation, claims processing | V9 |
| OAuth/OIDC config, redirect URIs, client credentials, PKCE | V10 |
| Crypto libraries, key management, hashing, encryption/decryption | V11 |
| TLS config, certificate handling, HTTPS enforcement, HSTS | V12 |
| App config files, environment variables, secrets management, deploy config | V13 |
| Data models, PII handling, data retention, anonymization | V14 |
| Error handling, exception filters, dependency manifests, build config | V15 |
| Logging config, audit trail code, log sanitization | V16 |
| WebRTC signaling, SRTP, DTLS, ICE config | V17 |

**Broad-impact changes** (affect multiple categories — extend scope):
- Middleware pipeline changes → all categories that flow through that pipeline
- DI/IoC container registration → categories for services being rewired
- Package manifest changes (new/removed security dependencies) → categories the dependency serves
- Infrastructure/deployment config → V12, V13

**Scope determination rules:**
1. If `--all` flag is passed, add all 17 categories to the working set (full re-analysis without re-running Init).
2. Apply the heuristics table to each changed file.
3. Union all affected categories into the working set.
4. If `--category` flag is passed, intersect with the user-specified set.
5. If no files map to any category (e.g., only README changes), report
   "No security-relevant changes detected" and stop (still update `last-scan`).

### Step 5 — Per-category incremental re-assessment

For each category in the working set:

#### 5a — Read existing category page

Read `docs/sec-docs/pages/{filename}` (the previously written page).
Parse all requirement sections to understand current status and evidence.

#### 5b — Identify impacted requirements

Within the category, determine which specific requirements are impacted:
1. Check which requirements cite evidence from the changed files (by checking
   existing `(source: ...)` citations).
2. Check which requirements would naturally be evidenced by the type of
   change (e.g., a change to password hashing affects V6.2.x requirements).
3. Requirements with no connection to the changed files are **not** re-assessed
   — their existing status and evidence are preserved verbatim.

#### 5c — Re-assess impacted requirements

For each impacted requirement, repeat the Init step 9c assessment:
1. Load the ASVS requirement text from the reference file.
2. Search the codebase for current evidence (focusing on changed areas first,
   then expanding to related code).
3. Incorporate Entra ID audit evidence where applicable.
4. Assign an updated Status verdict with fresh citations.

#### 5d — Scope extension within category

After re-assessing the initially impacted requirements:
- If a changed file is shared infrastructure (middleware, base class, config)
  that other requirements in the same category depend on, extend to those
  requirements.
- If a requirement's status changed (e.g., PASS → FAIL), check whether
  adjacent requirements in the same subcategory are affected.

#### 5e — Update category page in-place

Rewrite the page with these rules:
- **Changed requirements:** Replace their section entirely with fresh
  assessment.
- **Unchanged requirements:** Preserve their section verbatim (same status,
  evidence, citations).
- **Frontmatter:** Update `last-updated` and recalculate `status-summary`.
- **Technology Context:** Update only if the stack detection reveals changes
  (new dependencies, removed frameworks).

### Step 6 — Cross-category extension

After processing all categories in the initial working set, check for
cross-category cascades:

| Trigger | Extension |
|---|---|
| A requirement in V11 (crypto) changed status | Re-check V12 (secure comms) requirements that depend on the same crypto config |
| Auth middleware change affected V6 | Re-check V8 (authorization) and V10 (OAuth) |
| Session config change in V7 | Re-check V9 (tokens) |
| New Entra ID audit results | Re-check all categories in the ASVS Category Mapping table |

If extensions are triggered, add the new categories to the working set and
process them through Step 5. Track extensions to prevent infinite loops
(each category can only be processed once per run).

### Step 7 — Regenerate OWASP Top 10 report

If any ASVS category page was updated in Step 5 or Step 6, regenerate the Top 10 report:
1. Read `references/owasp_top10_2025.md` for the Top 10 item definitions and mappings.
2. For each Top 10 item: read the (now updated) ASVS category files from `docs/sec-docs/`
   and aggregate findings as in Part A Step 10.
3. Overwrite `docs/sec-docs/pages/asvs_top10_owasp.md` completely.

If no category pages were updated, skip this step.

### Step 8 — Update index.md metadata

Edit `docs/sec-docs/index.md` YAML frontmatter:
- Set `last-scan` to now (UTC ISO-8601).
- For each repo, update `last-commit-hash` to current HEAD:
  ```bash
  cd {repo-path} && git log -1 --format=%H
  ```
- Update the per-category status counts in the index table from the
  updated category pages' `status-summary` frontmatter.
- Update the OWASP Top 10 row counts if the Top 10 report was regenerated.

### Step 9 — Write run log entry

Append an Incremental entry to `docs/sec-docs/log.md` per the format in SKILL.md.

### Step 10 — Verify

Run the Verification Checklist from `SKILL.md`.

### Step 11 — Report

Output a summary:
- Repositories checked: count
- Repos with changes: list (include changed file count per repo)
- Repos with no changes (skipped): list
- Categories in initial scope: count and list (with mapping reason)
- Categories added by extension: count and list (with trigger)
- Requirements re-assessed: count (out of total)
- Requirements unchanged (preserved): count
- Status changes from previous run: list any requirement that changed status
  (e.g. "V6.2.1: FAIL → PASS after commit abc1234")
- OWASP Top 10 report: regenerated (yes/no); any Top 10 items that changed status
- Top FAIL items: list up to 5 most critical remaining failures
- Curated files incorporated: count

---

## Searching the Codebase Effectively

Use targeted searches rather than reading entire repositories. Prefer:

1. **Config-first**: Start with package manifests, server config, and middleware
   setup files — they reveal the security posture of the whole application quickly.

2. **Entry points**: HTTP route handlers, API controllers, authentication middleware,
   and deserializers are the highest-value files for most ASVS categories.

3. **Pattern search**: Use `search` with regex patterns to find specific calls
   (e.g. `SqlCommand\(`, `eval\(`, `Random\(`, `MD5`, `HttpOnly`).

4. **Test files**: Integration and security tests often confirm controls are in
   place and can provide strong PASS evidence.

5. **Negative search**: Absence of a dangerous pattern (e.g. no `eval(` in JS
   output code) can contribute to a PASS verdict when combined with positive
   evidence of safe alternatives.

**CONSTRAINT [HARD]:** Record the specific file path and relevant line range in every Evidence bullet. Do not assert PASS or FAIL without a concrete source reference.
