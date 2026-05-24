# Category Page Template

Every file written to `docs/sec-docs/` (except `index.md` and `log.md`) must
follow this structure exactly. Do not omit sections; mark them
"N/A — not applicable" if genuinely empty rather than leaving them out.

---

## Status Values

| Status | Meaning |
|---|---|
| `PASS` | All applicable evidence confirms the requirement is met |
| `FAIL` | Evidence confirms the requirement is not met |
| `PARTIAL` | Requirement is partially met — some controls present, others missing |
| `N/A` | Requirement does not apply to this application or technology stack |
| `NOT-ASSESSED` | Insufficient evidence to make a determination; code review needed |

Choose `NOT-ASSESSED` over guessing. Document what information would resolve it.
Choose `N/A` only when the feature or technology the requirement guards against
is demonstrably absent from the entire codebase.

---

## Evidence Rules

- Every `PASS` verdict must have at least one ✅ Evidence bullet with a source citation.
- Every `FAIL` verdict must have at least one ❌ Evidence bullet with a source citation.
- Every `PARTIAL` verdict must have at least one ✅ and at least one ❌ or ⚠️ bullet.
- `N/A` verdicts must include a one-sentence justification (no source citation required).
- `NOT-ASSESSED` verdicts must list what would need to be examined.
- Source citations are always relative to the workspace root: `(source: repo-name/path/file.ext)`
- If two sources contradict each other, write both and flag:
  `[CONFLICT: repo-a/file.cs says X; repo-b/file.ts says Y]`
- **CONSTRAINT [HARD]:** Never make unsourced PASS or FAIL claims.

---

## Category Page (`docs/sec-docs/pages/{asvs_vN_short_title}.md`)

```markdown
---
category-id: {V1|V2|...|V17}
category-title: "{Full ASVS Category Title}"
asvs-version: "5.0"
last-updated: "{ISO-8601-date}"
source-repos:
  - {repo-name}
status-summary:
  pass: {N}
  fail: {N}
  partial: {N}
  na: {N}
  not-assessed: {N}
---

# {Category ID}: {Category Title} — ASVS v5 Assessment

## Summary

One paragraph describing the purpose of this ASVS category, which aspects of
the codebase it covers, and the overall compliance posture (e.g. "6 of 10
requirements PASS; 2 FAIL due to missing CSRF protection in the API layer").

Include any accepted risks or compensating controls noted in curated docs.
If a `docs/sec-docs/curated/` file covers this category, reference it here:
(source: docs/sec-docs/curated/filename.md)

## Technology Context

Describe the technology stack relevant to this category as found in the
repositories. One bullet per repo or stack component:

- **{repo-name}** — {technology, framework, runtime version}
  (source: {repo}/path/to/relevant-config-or-file)
- **{repo-name}** — {relevant security libraries or middleware in use}
  (source: {repo}/path/to/dependency-manifest)

If curated docs provide architectural context, quote or paraphrase here
with a source citation. Curated content takes precedence over inferred content.

---

## Requirements

<!-- One section per requirement, ordered by control ID. -->

### {V#.#.#} — {Short Requirement Title}

| Field | Value |
|---|---|
| **Level** | {L1} / {L1 / L2} / {L1 / L2 / L3} |
| **Status** | {PASS \| FAIL \| PARTIAL \| N/A \| NOT-ASSESSED} |

**Requirement:**
> {Verbatim or faithfully paraphrased requirement text from ASVS.}

**Findings:**
Analysis of how the codebase handles this requirement. Be specific: name the
classes, methods, middleware, or configuration that are relevant. If the
requirement is not applicable, explain why (e.g. "application does not expose
XML parsing endpoints"). If evidence is ambiguous, say so explicitly.

(source: {repo}/path/to/file.ext)

**Evidence:**
Specific observations that directly support the Status verdict. Reference exact
file paths, line ranges, configuration keys, or test cases.

- ✅ {Observation confirming compliance} (source: {repo}/path/to/file.ext)
- ❌ {Observation indicating non-compliance} (source: {repo}/path/to/file.ext)
- ⚠️ {Observation indicating partial or unclear compliance} (source: {repo}/path/to/file.ext)

Use ✅ for evidence supporting PASS, ❌ for evidence supporting FAIL, ⚠️ for PARTIAL or ambiguous.
If Status is NOT-ASSESSED, explain what information would be needed to assess it.
If Status is N/A, state the reason clearly (e.g. "Feature not present in this application").

---

<!-- Repeat the section above for every requirement in this category. -->
```

---

## Index Page (`docs/sec-docs/index.md`)

```markdown
---
last-scan: "{ISO-8601-datetime-UTC}"
asvs-version: "5.0"
repositories:
  - name: {repo-directory-name}
    path: {repo-directory-name}
    last-commit-hash: {40-char-git-hash}
---

# SecDocs — ASVS v5 Compliance Assessment

Generated and maintained by the `sec-docs` skill.
Last scan: {last-scan}.

## Categories

| Category | Title | Requirements | PASS | FAIL | PARTIAL | N/A | NOT-ASSESSED | Page |
|---|---|---|---|---|---|---|---|---|
| V1 | Encoding and Sanitization | {N} | {N} | {N} | {N} | {N} | {N} | [asvs_v1_encoding_sanitization.md](pages/asvs_v1_encoding_sanitization.md) |
| V2 | Validation and Business Logic | ... | | | | | | [asvs_v2_validation_business_logic.md](pages/asvs_v2_validation_business_logic.md) |
| V3 | Web Frontend Security | ... | | | | | | [asvs_v3_web_frontend.md](pages/asvs_v3_web_frontend.md) |
| V4 | API and Web Service | ... | | | | | | [asvs_v4_api_web_service.md](pages/asvs_v4_api_web_service.md) |
| V5 | File Handling | ... | | | | | | [asvs_v5_file_handling.md](pages/asvs_v5_file_handling.md) |
| V6 | Authentication | ... | | | | | | [asvs_v6_authentication.md](pages/asvs_v6_authentication.md) |
| V7 | Session Management | ... | | | | | | [asvs_v7_session_management.md](pages/asvs_v7_session_management.md) |
| V8 | Authorization | ... | | | | | | [asvs_v8_authorization.md](pages/asvs_v8_authorization.md) |
| V9 | Self-contained Tokens | ... | | | | | | [asvs_v9_self_contained_tokens.md](pages/asvs_v9_self_contained_tokens.md) |
| V10 | OAuth and OIDC | ... | | | | | | [asvs_v10_oauth_oidc.md](pages/asvs_v10_oauth_oidc.md) |
| V11 | Cryptography | ... | | | | | | [asvs_v11_cryptography.md](pages/asvs_v11_cryptography.md) |
| V12 | Secure Communication | ... | | | | | | [asvs_v12_secure_communication.md](pages/asvs_v12_secure_communication.md) |
| V13 | Configuration | ... | | | | | | [asvs_v13_configuration.md](pages/asvs_v13_configuration.md) |
| V14 | Data Protection | ... | | | | | | [asvs_v14_data_protection.md](pages/asvs_v14_data_protection.md) |
| V15 | Secure Coding and Architecture | ... | | | | | | [asvs_v15_secure_coding.md](pages/asvs_v15_secure_coding.md) |
| V16 | Security Logging and Error Handling | ... | | | | | | [asvs_v16_security_logging.md](pages/asvs_v16_security_logging.md) |
| V17 | WebRTC | ... | | | | | | [asvs_v17_webrtc.md](pages/asvs_v17_webrtc.md) |

## OWASP Top 10 2025

| Report | Items | PASS | FAIL | PARTIAL | N/A | NOT-ASSESSED | Page |
|---|---|---|---|---|---|---|---|
| OWASP Top 10 2025 | 10 | {N} | {N} | {N} | {N} | {N} | [asvs_top10_owasp.md](pages/asvs_top10_owasp.md) |

## Entra ID Audit

| Audit | Last Run | PASS | FAIL | WARN | UNABLE | Report |
|---|---|---|---|---|---|---|
| Entra ID ASVS Audit | {ISO-8601-date or "not run"} | {N} | {N} | {N} | {N} | [entraid-audit-latest.md](reports/entraid/entraid-audit-latest.md) |

## Overall Posture

| Status | Count |
|---|---|
| PASS | {total} |
| FAIL | {total} |
| PARTIAL | {total} |
| N/A | {total} |
| NOT-ASSESSED | {total} |

## About

This assessment is a structured OWASP ASVS v5 compliance review with an
OWASP Top 10 2025 cross-reference report.
Every PASS or FAIL verdict references its source file.
To update the analysis, invoke the `sec-docs` skill from GitHub Copilot CLI.
Curated context files may be placed in `docs/sec-docs/curated/` — they are
read-only inputs and will never be modified by this skill.
```

---

## OWASP Top 10 Page Template (`docs/sec-docs/pages/asvs_top10_owasp.md`)

```markdown
---
report: "OWASP Top 10 2025"
owasp-top10-version: "2025"
asvs-version: "5.0"
last-updated: "{ISO-8601-date}"
source-repos:
  - {repo-name}
status-summary:
  pass: {N}
  fail: {N}
  partial: {N}
  na: {N}
  not-assessed: {N}
---

# OWASP Top 10 2025 — Security Analysis

## Summary

One paragraph describing the overall Top 10 posture across the codebase.
Cross-references findings from individual ASVS category reports — this document
aggregates; it does not repeat detailed per-requirement analysis.

If any curated docs in `docs/sec-docs/curated/` apply cross-cutting context,
reference them here: (source: docs/sec-docs/curated/filename.md)

## ASVS Category Cross-Reference

| Top 10 Item | Primary ASVS Category Report(s) | Status |
|---|---|---|
| A01 Broken Access Control | [asvs_v8_authorization.md](pages/asvs_v8_authorization.md), [asvs_v3_web_frontend.md](pages/asvs_v3_web_frontend.md) | {PASS\|FAIL\|PARTIAL\|N/A\|NOT-ASSESSED} |
| A02 Security Misconfiguration | [asvs_v13_configuration.md](pages/asvs_v13_configuration.md), [asvs_v3_web_frontend.md](pages/asvs_v3_web_frontend.md) | {STATUS} |
| A03 Software Supply Chain Failures | [asvs_v15_secure_coding.md](pages/asvs_v15_secure_coding.md) | {STATUS} |
| A04 Cryptographic Failures | [asvs_v11_cryptography.md](pages/asvs_v11_cryptography.md), [asvs_v12_secure_communication.md](pages/asvs_v12_secure_communication.md) | {STATUS} |
| A05 Injection | [asvs_v1_encoding_sanitization.md](pages/asvs_v1_encoding_sanitization.md), [asvs_v2_validation_business_logic.md](pages/asvs_v2_validation_business_logic.md) | {STATUS} |
| A06 Insecure Design | [asvs_v2_validation_business_logic.md](pages/asvs_v2_validation_business_logic.md), [asvs_v15_secure_coding.md](pages/asvs_v15_secure_coding.md) | {STATUS} |
| A07 Authentication Failures | [asvs_v6_authentication.md](pages/asvs_v6_authentication.md), [asvs_v7_session_management.md](pages/asvs_v7_session_management.md) | {STATUS} |
| A08 Software or Data Integrity Failures | [asvs_v15_secure_coding.md](pages/asvs_v15_secure_coding.md), [asvs_v9_self_contained_tokens.md](pages/asvs_v9_self_contained_tokens.md) | {STATUS} |
| A09 Security Logging and Alerting Failures | [asvs_v16_security_logging.md](pages/asvs_v16_security_logging.md) | {STATUS} |
| A10 Mishandling of Exceptional Conditions | [asvs_v16_security_logging.md](pages/asvs_v16_security_logging.md), [asvs_v2_validation_business_logic.md](pages/asvs_v2_validation_business_logic.md) | {STATUS} |

---

## A01:2025 — Broken Access Control

| Field | Value |
|---|---|
| **Rank** | #1 |
| **Status** | {PASS \| FAIL \| PARTIAL \| N/A \| NOT-ASSESSED} |
| **Primary ASVS Categories** | V8 (Authorization), V3 (Web Frontend), V7 (Session Management) |

**Description:**
Access control enforces policy such that users cannot act outside their intended permissions.
Failures lead to unauthorized disclosure, modification, or destruction of data.

**Findings:**
Summary of findings aggregated from the mapped ASVS category reports.
State which ASVS category file each finding originates from.

(source: docs/sec-docs/pages/asvs_v8_authorization.md)

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md#{requirement-id})

---

## A02:2025 — Security Misconfiguration

| Field | Value |
|---|---|
| **Rank** | #2 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V13 (Configuration), V3 (Web Frontend — Headers), V12 (Secure Communication) |

**Description:**
Security misconfiguration occurs when systems are set up incorrectly, creating vulnerabilities.
Found in 100% of tested applications.

**Findings:**
{aggregated from asvs_v13_configuration.md, asvs_v3_web_frontend.md, asvs_v12_secure_communication.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A03:2025 — Software Supply Chain Failures

| Field | Value |
|---|---|
| **Rank** | #3 (NEW in 2025) |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V15 (Secure Coding and Architecture) |

**Description:**
Supply chain failures cover breakdowns in building, distributing, or updating software —
including vulnerable or malicious third-party code, tools, or dependencies.

**Findings:**
{aggregated from asvs_v15_secure_coding.md — dependency management, SBOM, CI/CD hardening}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/pages/asvs_v15_secure_coding.md)

---

## A04:2025 — Cryptographic Failures

| Field | Value |
|---|---|
| **Rank** | #4 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V11 (Cryptography), V12 (Secure Communication), V14 (Data Protection) |

**Description:**
Cryptographic failures occur when sensitive data is not adequately protected,
or when weak/deprecated cryptographic algorithms are used.

**Findings:**
{aggregated from asvs_v11_cryptography.md, asvs_v12_secure_communication.md, asvs_v14_data_protection.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A05:2025 — Injection

| Field | Value |
|---|---|
| **Rank** | #5 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V1 (Encoding and Sanitization), V2 (Validation and Business Logic) |

**Description:**
Injection flaws occur when untrusted data is sent to an interpreter as part of a command
or query. Includes SQL, LDAP, XPath, OS injection, and Cross-Site Scripting (XSS).

**Findings:**
{aggregated from asvs_v1_encoding_sanitization.md, asvs_v2_validation_business_logic.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A06:2025 — Insecure Design

| Field | Value |
|---|---|
| **Rank** | #6 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V2 (Validation and Business Logic), V15 (Secure Coding), V8 (Authorization) |

**Description:**
Insecure design covers missing or ineffective control design — distinct from insecure
implementation. A secure design can still have implementation defects, but an insecure
design cannot be fixed by perfect implementation.

**Findings:**
{aggregated from asvs_v2_validation_business_logic.md, asvs_v15_secure_coding.md, asvs_v8_authorization.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A07:2025 — Authentication Failures

| Field | Value |
|---|---|
| **Rank** | #7 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V6 (Authentication), V7 (Session Management), V9 (Self-contained Tokens), V10 (OAuth and OIDC) |

**Description:**
Authentication failures allow attackers to compromise passwords, keys, or session tokens,
or exploit implementation flaws to assume another user's identity.

**Findings:**
{aggregated from asvs_v6_authentication.md, asvs_v7_session_management.md,
asvs_v9_self_contained_tokens.md, asvs_v10_oauth_oidc.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A08:2025 — Software or Data Integrity Failures

| Field | Value |
|---|---|
| **Rank** | #8 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V15 (Secure Coding), V9 (Self-contained Tokens), V3 (Web Frontend — SRI) |

**Description:**
Software and data integrity failures relate to code and infrastructure that does not
protect against integrity violations — including insecure deserialization, auto-updates
without integrity verification, and CI/CD pipeline attacks.

**Findings:**
{aggregated from asvs_v15_secure_coding.md, asvs_v9_self_contained_tokens.md, asvs_v3_web_frontend.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)

---

## A09:2025 — Security Logging and Alerting Failures

| Field | Value |
|---|---|
| **Rank** | #9 |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V16 (Security Logging and Error Handling) |

**Description:**
Insufficient logging, detection, monitoring, and active response allows attackers
to further attack systems, maintain persistence, and operate undetected.

**Findings:**
{aggregated from asvs_v16_security_logging.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/pages/asvs_v16_security_logging.md)

---

## A10:2025 — Mishandling of Exceptional Conditions

| Field | Value |
|---|---|
| **Rank** | #10 (NEW in 2025) |
| **Status** | {STATUS} |
| **Primary ASVS Categories** | V16 (Security Logging and Error Handling), V2 (Validation and Business Logic), V15 (Secure Coding) |

**Description:**
Mishandling exceptional conditions occurs when programs fail to prevent, detect, and
respond to unusual situations — leading to crashes, unexpected behaviour, fail-open
vulnerabilities, and information leakage through error messages.

**Findings:**
{aggregated from asvs_v16_security_logging.md, asvs_v2_validation_business_logic.md,
asvs_v15_secure_coding.md}

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/{asvs-category-file}.md)
```

---

## Formatting Rules

1. **Headings**: H1 for page title, H2 for top-level sections, H3 for requirement IDs. No H4+.
2. **Requirement sections**: Always start with the `| Field | Value |` table before Findings.
3. **Status badges**: Must be exactly one of: `PASS`, `FAIL`, `PARTIAL`, `N/A`, `NOT-ASSESSED`.
4. **Evidence bullets**: Use ✅ / ❌ / ⚠️ prefix. End every bullet with `(source: ...)`.
5. **Citations**: `(source: repo/path/to/file.ext)` — relative to workspace root, at end of sentence.
6. **Conflict markers**: `[CONFLICT: source A says X; source B says Y]` — inline.
7. **Curated doc notes**: `[NOTE: curated says X; code analysis suggests Y — verify with team]`
8. **Dates**: ISO-8601 in frontmatter (`2026-05-09T14:32:00Z`). Human-readable in prose if needed.
9. **Requirement ordering**: Follow the ASVS control ID order within each sub-section group.
