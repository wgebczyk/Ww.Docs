# SecDocs-Mini — Incremental (Update) Workflow

Full procedural detail for Incremental mode. Run when `docs/sec-docs/index.md`
exists and `--init` was not passed.

This is the **single-repository** variant: there is no multi-repo discovery —
the workspace is the repo root.

The workflow is **change-driven**: it begins from the git delta, maps changes
to affected ASVS categories using heuristics, and re-assesses only impacted
requirements within those categories. Scope extends automatically when evidence
cascades, but never defaults to full regeneration.

## Step 1 — Read existing metadata

Read `docs/sec-docs/index.md`. Parse YAML frontmatter:
- `last-scan` → timestamp of previous run
- `asvs-version` → ASVS version of previous run
- `last-commit-hash` → git baseline

## Step 2 — Re-read curated docs

Read all `docs/sec-docs/curated/**/*.md` regardless of changes. Re-index by
category ID and topic name (same as Init Step 6).

## Step 3 — Detect codebase changes

Collect changes since the last scan with two targeted git queries (both run
against the repo root):

- **Code changes:**
  `git log {last-commit-hash}..HEAD --name-only --format= -- ':!docs/sec-docs/'`
  (excludes all skill-generated output under `docs/sec-docs/`)
- **Curated changes:**
  `git log {last-commit-hash}..HEAD --name-only --format= -- 'docs/sec-docs/curated/'`
  (curated files live inside `docs/sec-docs/` so the first query excludes them;
  this one captures them explicitly)

If `{last-commit-hash}` is no longer in history (after rebase/force-push), fall
back to full re-analysis.

## Step 4 — Check audit JSON freshness

For each integration (`entraid`, `headers`, `tls`, `azure`, `deps`), check
whether `docs/sec-docs/reports/{integration}/{integration}-audit-latest.json`
is newer than `last-scan`.

If the code change list is empty **and** no curated docs changed **and** no new
audit results: update `last-scan` and `last-commit-hash` only, and report
"No changes detected."

## Step 5 — Map changes to ASVS categories

Use these **Category Relevance Heuristics** to determine which categories are
affected by changed files:

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

## Step 6 — Per-category incremental re-assessment

For each category in the working set:

### 6a — Read existing category page

Read `docs/sec-docs/pages/{filename}` (the previously written page). Parse all
requirement sections to understand current status and evidence.

### 6b — Identify impacted requirements

Within the category, determine which specific requirements are impacted:
1. Check which requirements cite evidence from the changed files (by checking
   existing `(source: ...)` citations).
2. Check which requirements would naturally be evidenced by the type of change
   (e.g., a change to password hashing affects V6.2.x requirements).
3. Requirements with no connection to the changed files are **not** re-assessed
   — their existing status and evidence are preserved verbatim.

### 6c — Re-assess impacted requirements

For each impacted requirement, repeat the Init Step 7c assessment:
1. Load the ASVS requirement text from the reference file.
2. Search the codebase for current evidence (focusing on changed areas first,
   then expanding to related code).
3. Incorporate audit evidence where applicable (per the integration's ASVS Category
   Mapping).
4. Assign an updated Status verdict with fresh citations.

### 6d — Scope extension within category

After re-assessing the initially impacted requirements:
- If a changed file is shared infrastructure (middleware, base class, config)
  that other requirements in the same category depend on, extend to those
  requirements.
- If a requirement's status changed (e.g., PASS → FAIL), check whether
  adjacent requirements in the same subcategory are affected.

### 6e — Update category page in-place

Rewrite the page with these rules:
- **Changed requirements:** Replace their section entirely with fresh assessment.
- **Unchanged requirements:** Preserve their section verbatim (same status,
  evidence, citations).
- **Frontmatter:** Update `last-updated` and recalculate `status-summary`.
- **Technology Context:** Update only if the stack detection reveals changes
  (new dependencies, removed frameworks).

## Step 7 — Cross-category extension

After processing all categories in the initial working set, check for
cross-category cascades:

| Trigger | Extension |
|---|---|
| A requirement in V11 (crypto) changed status | Re-check V12 (secure comms) requirements that depend on the same crypto config |
| Auth middleware change affected V6 | Re-check V8 (authorization) and V10 (OAuth) |
| Session config change in V7 | Re-check V9 (tokens) |
| New audit results from any integration | Re-check all categories in that integration's ASVS Category Mapping |

If extensions are triggered, add the new categories to the working set and
process them through Step 6. Track extensions to prevent infinite loops (each
category can only be processed once per run).

## Step 8 — Regenerate OWASP Top 10 report

If any ASVS category page was updated in Step 6 or Step 7, regenerate the Top 10 report:
1. Read `references/owasp_top10_2025.md` for the Top 10 item definitions and mappings.
2. For each Top 10 item: read the (now updated) ASVS category files from
   `docs/sec-docs/pages/` and aggregate findings as in Init Step 8.
3. Overwrite `docs/sec-docs/pages/asvs_top10_owasp.md` completely.

If no category pages were updated, skip this step.

## Step 9 — Update index.md metadata

Edit `docs/sec-docs/index.md` YAML frontmatter:
- Set `last-scan` to now (UTC ISO-8601).
- Update `last-commit-hash` to current HEAD: `git log -1 --format=%H`.
- Update the per-category status counts in the index table from the updated
  category pages' `status-summary` frontmatter.
- Update the OWASP Top 10 row counts if the Top 10 report was regenerated.
- Update the Audit Status row(s) if any audit JSON was refreshed.

## Step 10 — Write run log entry

Append an Incremental entry to `docs/sec-docs/log.md` per the format in `SKILL.md`.

## Step 11 — Verify

Run the Verification Checklist from `SKILL.md`.

## Step 12 — Report

Output a summary:
- Changed file count (code) and curated file count
- Categories in initial scope: count and list (with mapping reason)
- Categories added by extension: count and list (with trigger)
- Requirements re-assessed: count (out of total)
- Requirements unchanged (preserved): count
- Status changes from previous run: list any requirement that changed status
  (e.g. "V6.2.1: FAIL → PASS after commit abc1234")
- OWASP Top 10 report: regenerated (yes/no); any Top 10 items that changed status
- Audit refresh: which integrations produced new JSON since last scan
- Top FAIL items: list up to 5 most critical remaining failures
- Curated files incorporated: count
