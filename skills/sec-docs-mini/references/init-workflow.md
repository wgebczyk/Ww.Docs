# SecDocs-Mini — Init Workflow

Full procedural detail for Init mode. Run when `docs/sec-docs/index.md` does
not exist, or when `--init` is passed.

This is the **single-repository** variant: the skill scans the current working
directory (the repo root) and its subtree only. There is no multi-repo discovery.

## Depth Standard

Init mode establishes the compliance baseline that all future Incremental runs
delta against. Shallow output here persists as stale verdicts across every
subsequent run.

- **Verify in code, not in docs.** Every requirement status must be established
  by reading actual source files — not inferred from documentation or project type.
- **Search beyond entry points.** Trace security controls through middleware
  stacks, DI registration, config transforms, environment-specific overrides,
  and generated code.
- **Identify compensating controls explicitly.** If a control is implemented
  differently than ASVS prescribes but achieves the same outcome, document it —
  do not mark as FAIL without investigating.
- **Mark gaps honestly.** Use `NOT-ASSESSED` for requirements where code evidence
  was not found; use `PARTIAL` where coverage is incomplete. Never substitute
  `PASS` for lack of evidence.
- **Assign Confidence honestly.** A category with incomplete trace coverage must
  be marked `Confidence: Low`, not `Medium`.

---

## Step 1 — Create directory structure

Create `docs/sec-docs/`, `docs/sec-docs/pages/`, and `docs/sec-docs/curated/`
if absent. Do not write content into `docs/sec-docs/curated/` — that directory
is human-owned and read-only. The `docs/sec-docs/reports/{integration}/`
directories are created by their audit scripts, not by the skill.

```powershell
New-Item -ItemType Directory -Force -Path "docs/sec-docs"
New-Item -ItemType Directory -Force -Path "docs/sec-docs/pages"
New-Item -ItemType Directory -Force -Path "docs/sec-docs/curated"
```

## Step 2 — Load ASVS category list

Read the Category Registry table from `SKILL.md` for the full list of 17
categories, their reference files, and their output filenames. All ASVS
requirement data is stored in `references/asvs_v{N}_{short_title}.md` files —
do not call any external ASVS tool.

## Step 3 — Capture HEAD commit hash

The workspace **is** the repository. Capture the current commit hash:

```powershell
git log -1 --format=%H
```

Store the 40-character hash. Used as the baseline for incremental runs.

## Step 4 — Detect technology stack

Identify, by inspecting the repository:
- Primary language (`*.csproj`, `package.json`, `go.mod`, `pom.xml`, `*.py`, etc.)
- Runtime and framework (ASP.NET Core, Express, Spring Boot, Django, Angular, React, etc.)
- Key security-relevant dependencies (auth middleware, crypto libraries, ORM, HTTP clients)
- Configuration files (`appsettings.json`, `web.config`, `.env`, `dockerfile`, `helm/`, etc.)

Record findings. This context is used when writing the Technology Context
section of each category page and when searching for evidence.

## Step 5 — Run the audit orchestrators

Load `references/audit-integration-shared.md` once, then for each integration
that applies to the project, load `references/{integration}/audit-integration.md`
and execute its Phase 1–4 procedure. Integrations:

- `entraid` — feeds V6, V7, V8, V9, V10, V11, V13
- `headers` — feeds V3, V12 (redirect), V13
- `tls` — feeds V11 (cert key size), V12
- `azure` — feeds V11, V13 (Key Vault + App Config)
- `deps` — feeds V15

In a **pipeline run** the orchestrators have already run; the audit JSON files
exist. In an **interactive run**, follow the freshness logic in
`audit-integration-shared.md` (Phase 4) and instruct the user accordingly. If
the user declines, mark affected requirements `NOT-ASSESSED`.

If an integration finds no targets to audit (no app registrations / no base
URLs / no Key Vaults / no solutions), note it as "not applicable" in the run
log and skip its ASVS mapping.

## Step 6 — Read curated docs

Read all files matching `docs/sec-docs/curated/**/*.md`. If absent, skip.

For each file:
1. Parse YAML frontmatter. If a `category:` field matches a category ID (e.g. `V6`),
   that file is the authoritative context for that category.
2. If no frontmatter, treat the filename stem as a probable topic hint.
3. Store content indexed by category ID and topic name for use in Step 7.

## Step 7 — Analyse each category (one at a time)

Process categories in order V1 → V17. For each category:

### 7a — Load ASVS requirements

Read the category's reference file from `references/asvs_v{N}_{short_title}.md`
(see the Category Registry in `SKILL.md`). Do not proceed to 7b until the file
has been fully read.

### 7b — Build technology context

Using the stack info from Step 4 and curated docs from Step 6:
- Identify which components are relevant to this category.
- Identify security-relevant files to search (middleware, config, auth handlers,
  database access layers, serializers, HTTP clients, etc.).
- Note any curated docs that apply to this category.

### 7c — Assess each requirement

For each requirement in the reference file:

1. Read the requirement text carefully. Identify the control being verified.
2. **Check for audit evidence:** for each integration whose ASVS mapping
   includes this requirement, look up matching findings from the audit JSON by
   `asvs` field.
   - If a finding exists: use its `Status`, `Title`, and `Evidence` as primary
     evidence. Cite per the format in `audit-integration-shared.md`.
   - If the audit was not run: mark the requirement `NOT-ASSESSED` with the
     reason recorded.
3. Determine the codebase search strategy: what code patterns, config keys, or
   library usage would confirm or deny the control?
4. Search the repository for evidence (complements audit evidence).
5. Assign a Status verdict (PASS / FAIL / PARTIAL / N/A / NOT-ASSESSED).
   When audit evidence conflicts with codebase evidence, prefer the audit result
   and note the discrepancy.
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

### 7d — Write category page

Write `docs/sec-docs/pages/{asvs_vN_short_title}.md` (per the Category Registry
in `SKILL.md`) using the template in `references/category-page-template.md`.
Requirements:
- YAML frontmatter must include `status-summary` counts.
- Every requirement in the ASVS category must have a section (no omissions).
- Requirements are ordered by control ID (V#.#.# ascending).
- Every PASS or FAIL must have at least one sourced evidence bullet.

## Step 8 — Generate OWASP Top 10 2025 report

After all 17 category pages are written:

1. Read `references/owasp_top10_2025.md` for each Top 10 item's description and
   ASVS category mappings.
2. For each of the 10 items (A01–A10):
   a. Read the mapped ASVS category pages from `docs/sec-docs/pages/` to extract
      relevant findings. Pull `status-summary` from frontmatter and specific
      requirement sections from the body.
   b. Aggregate the findings: summarise which requirements PASS, FAIL, or are PARTIAL.
   c. Set the item-level Status:
      - `PASS` — all mapped requirements PASS (or N/A)
      - `FAIL` — any mapped requirement FAILs
      - `PARTIAL` — mix of PASS and FAIL, or any PARTIAL requirements
      - `N/A` — the entire item is not applicable to this stack
      - `NOT-ASSESSED` — insufficient evidence across mapped categories
3. Write `docs/sec-docs/pages/asvs_top10_owasp.md` using the OWASP Top 10 Page
   Template from `references/category-page-template.md`.
4. Do **not** re-search the codebase — all evidence comes from the already-written
   category pages. Cite them as sources:
   `(source: docs/sec-docs/pages/asvs_vN_name.md#V#.#.#)`.

## Step 9 — Write index.md

Write `docs/sec-docs/index.md` with:

**YAML frontmatter:**
```yaml
---
last-scan: "{current-UTC-datetime-ISO-8601}"
asvs-version: "5.0"
last-commit-hash: {hash-from-step-3}
---
```

**Body:** Full category table, OWASP Top 10 row, Audit Status table, and overall
posture summary as shown in the index template in
`references/category-page-template.md`. Pull per-category counts from the
`status-summary` frontmatter of each written category page.

## Step 10 — Write run log entry

Append an Init entry to `docs/sec-docs/log.md` per the format in `SKILL.md`.
Create the file with its header if it does not exist.

## Step 11 — Verify

Run the Verification Checklist from `SKILL.md`. Fix any failures before reporting.

## Step 12 — Report

Output a summary:
- Categories documented: count and list
- Total requirements assessed: count
- Status breakdown: PASS / FAIL / PARTIAL / N/A / NOT-ASSESSED counts
- Curated files incorporated: count and list
- OWASP Top 10: item count and overall status (e.g. "3 PASS, 4 FAIL, 2 PARTIAL, 1 NOT-ASSESSED")
- Audit status per integration: run / not-run / not-applicable
- Top FAIL items: list up to 5 most critical failures for immediate attention

---

## Searching the Codebase Effectively

Use targeted searches rather than reading entire directories. Prefer:

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

**CONSTRAINT [HARD]:** Record the specific file path and relevant line range in
every Evidence bullet. Do not assert PASS or FAIL without a concrete source reference.
