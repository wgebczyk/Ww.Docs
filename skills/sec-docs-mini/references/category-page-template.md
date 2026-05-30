# Category Page Template

Output structure for files written under `docs/sec-docs/`. Do not omit sections;
mark them `N/A — not applicable` if genuinely empty rather than leaving them out.

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

## Evidence Rules

- Every `PASS` verdict must have at least one ✅ Evidence bullet with a source citation.
- Every `FAIL` verdict must have at least one ❌ Evidence bullet with a source citation.
- Every `PARTIAL` verdict must have at least one ✅ and at least one ❌ or ⚠️ bullet.
- `N/A` verdicts must include a one-sentence justification (no source citation required).
- `NOT-ASSESSED` verdicts must list what would need to be examined.
- Source citations are repo-relative: `(source: path/to/file.ext)` or
  `(source: path/to/file.ext:Lstart-Lend)` for localized findings.
- Contradictions: `[CONFLICT: path/file-a.cs says X; path/file-b.ts says Y]`.
- **CONSTRAINT [HARD-EVIDENCE]:** Never make unsourced PASS or FAIL claims.

---

## Category Page (`docs/sec-docs/pages/{asvs_vN_short_title}.md`)

```markdown
---
category-id: {V1|V2|...|V17}
category-title: "{Full ASVS Category Title}"
asvs-version: "5.0"
last-updated: "{ISO-8601-date}"
status-summary:
  pass: {N}
  fail: {N}
  partial: {N}
  na: {N}
  not-assessed: {N}
---

# {Category ID}: {Category Title} — ASVS v5 Assessment

## Summary

{One paragraph: purpose of this ASVS category, aspects of the codebase it
covers, overall compliance posture, accepted risks or compensating controls
from curated docs.}

(source: docs/sec-docs/curated/filename.md)   <!-- if applicable -->

## Technology Context

- {technology, framework, runtime version} (source: path/to/config)
- {relevant security libraries or middleware} (source: path/to/manifest)

<!-- Curated content takes precedence over inferred content. -->

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
{Specific analysis: classes, methods, middleware, or configuration relevant to
this requirement. If N/A, explain why. If evidence is ambiguous, say so.}

(source: path/to/file.ext)

**Evidence:**

- ✅ {Observation supporting PASS} (source: path/to/file.ext)
- ❌ {Observation supporting FAIL} (source: path/to/file.ext)
- ⚠️ {Observation for PARTIAL or ambiguous} (source: path/to/file.ext)

---

<!-- Repeat the section above for every requirement in this category. -->
```

---

## Index Page (`docs/sec-docs/index.md`)

```markdown
---
last-scan: "{ISO-8601-datetime-UTC}"
asvs-version: "5.0"
last-commit-hash: {40-char-git-hash}
---

# SecDocs — ASVS v5 Compliance Assessment

Generated and maintained by the `sec-docs-mini` skill.
Last scan: {last-scan}.

## Categories

| Category | Title | Requirements | PASS | FAIL | PARTIAL | N/A | NOT-ASSESSED | Page |
|---|---|---|---|---|---|---|---|---|
| V1 | Encoding and Sanitization | {N} | {N} | {N} | {N} | {N} | {N} | [asvs_v1_encoding_sanitization.md](pages/asvs_v1_encoding_sanitization.md) |
| V2 | Validation and Business Logic | ... | | | | | | [asvs_v2_validation_business_logic.md](pages/asvs_v2_validation_business_logic.md) |
| ... | ... | ... | | | | | | ... |
| V17 | WebRTC | ... | | | | | | [asvs_v17_webrtc.md](pages/asvs_v17_webrtc.md) |

<!-- Emit one row per category V1..V17 using the filenames from the Category Registry in SKILL.md. -->

## OWASP Top 10 2025

| Report | Items | PASS | FAIL | PARTIAL | N/A | NOT-ASSESSED | Page |
|---|---|---|---|---|---|---|---|
| OWASP Top 10 2025 | 10 | {N} | {N} | {N} | {N} | {N} | [asvs_top10_owasp.md](pages/asvs_top10_owasp.md) |

## Audit Status

| Audit | Last Run | PASS | FAIL | WARN | UNABLE | Report |
|---|---|---|---|---|---|---|
| Entra ID | {ISO date or "not run"} | {N} | {N} | {N} | {N} | [entraid-audit-latest.md](reports/entraid/entraid-audit-latest.md) |
| HTTP Headers | ... | | | | | [headers-audit-latest.md](reports/headers/headers-audit-latest.md) |
| TLS | ... | | | | | [tls-audit-latest.md](reports/tls/tls-audit-latest.md) |
| Azure Resources | ... | | | | | [azure-audit-latest.md](reports/azure/azure-audit-latest.md) |
| Dependencies | ... | | | | | [deps-audit-latest.md](reports/deps/deps-audit-latest.md) |

## Overall Posture

| Status | Count |
|---|---|
| PASS | {total} |
| FAIL | {total} |
| PARTIAL | {total} |
| N/A | {total} |
| NOT-ASSESSED | {total} |

## About

Structured OWASP ASVS v5 compliance review with an OWASP Top 10 2025 cross-reference.
Every PASS or FAIL references its source file.
Curated context files may be placed in `docs/sec-docs/curated/` — read-only inputs,
never modified by this skill.
```

---

## OWASP Top 10 Page (`docs/sec-docs/pages/asvs_top10_owasp.md`)

```markdown
---
report: "OWASP Top 10 2025"
owasp-top10-version: "2025"
asvs-version: "5.0"
last-updated: "{ISO-8601-date}"
status-summary:
  pass: {N}
  fail: {N}
  partial: {N}
  na: {N}
  not-assessed: {N}
---

# OWASP Top 10 2025 — Security Analysis

## Summary

{One paragraph: overall Top 10 posture across the codebase. This document
aggregates findings from the per-category reports; it does not repeat
per-requirement analysis.}

(source: docs/sec-docs/curated/filename.md)   <!-- if applicable -->

## ASVS Category Cross-Reference

<!-- Emit the 10-row table from owasp_top10_2025.md, adding a Status column. -->

| Top 10 Item | Primary ASVS Category Report(s) | Status |
|---|---|---|
| A01 Broken Access Control | [asvs_v8_authorization.md](pages/asvs_v8_authorization.md), ... | {STATUS} |
| ... | ... | ... |

---

## A01:2025 — {Title}

<!-- Repeat this block for A01..A10. Pull Description and Primary ASVS Categories from
     references/owasp_top10_2025.md. Aggregate Findings from the mapped category pages. -->

| Field | Value |
|---|---|
| **Rank** | #{N} |
| **Status** | {PASS \| FAIL \| PARTIAL \| N/A \| NOT-ASSESSED} |
| **Primary ASVS Categories** | {from owasp_top10_2025.md} |

**Description:**
{from owasp_top10_2025.md}

**Findings:**
{Aggregated from the mapped ASVS category reports. State which category file each
finding originates from.}

(source: docs/sec-docs/pages/asvs_vN_name.md#V#.#.#)

**Evidence:**

- ✅ / ❌ / ⚠️ {Observation} (source: docs/sec-docs/pages/asvs_vN_name.md#V#.#.#)
```

---

## Formatting Rules

1. **Headings:** H1 for page title, H2 for top-level sections, H3 for requirement IDs. No H4+.
2. **Requirement sections:** Always start with the `| Field | Value |` table before Findings.
3. **Status badges:** Must be exactly one of `PASS`, `FAIL`, `PARTIAL`, `N/A`, `NOT-ASSESSED`.
4. **Evidence bullets:** Use ✅ / ❌ / ⚠️ prefix. End every bullet with `(source: ...)`.
5. **Citations:** `(source: path/to/file.ext)` — repo-relative, at end of sentence.
6. **Conflict markers:** `[CONFLICT: source A says X; source B says Y]` — inline.
7. **Curated doc notes:** `[NOTE: curated says X; code analysis suggests Y — verify with team]`
8. **Dates:** ISO-8601 in frontmatter (`2026-05-09T14:32:00Z`).
9. **Requirement ordering:** ASVS control ID order within each sub-section group.
