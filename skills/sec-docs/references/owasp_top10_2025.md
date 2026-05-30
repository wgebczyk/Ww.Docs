---
source: "https://owasp.org/Top10/2025/"
version: "2025"
item-count: 10
output-file: "docs/sec-docs/pages/asvs_top10_owasp.md"
---

# OWASP Top 10 2025

Static reference. Load when generating `docs/sec-docs/pages/asvs_top10_owasp.md`.
Source: https://owasp.org/Top10/2025/

## ASVS Category Mapping

Each Top 10 item maps to one or more ASVS v5 categories. Use these mappings to
cross-reference findings from the per-category pages already generated in
`docs/sec-docs/pages/`. Do not re-analyse the codebase — pull evidence from the
category files and summarise.

| Top 10 Item | Primary ASVS Categories | Secondary ASVS Categories |
|---|---|---|
| A01 Broken Access Control | V8 (Authorization) | V3 (Web Frontend — CORS/CSRF), V7 (Session Management) |
| A02 Security Misconfiguration | V13 (Configuration) | V3 (Web Frontend — Headers), V12 (Secure Communication) |
| A03 Software Supply Chain Failures | V15 (Secure Coding and Architecture) | — |
| A04 Cryptographic Failures | V11 (Cryptography) | V12 (Secure Communication), V14 (Data Protection) |
| A05 Injection | V1 (Encoding and Sanitization) | V2 (Validation and Business Logic) |
| A06 Insecure Design | V2 (Validation and Business Logic) | V15 (Secure Coding), V8 (Authorization) |
| A07 Authentication Failures | V6 (Authentication) | V7 (Session Management), V9 (Self-contained Tokens), V10 (OAuth and OIDC) |
| A08 Software or Data Integrity Failures | V15 (Secure Coding) | V9 (Self-contained Tokens), V3 (Web Frontend — SRI) |
| A09 Security Logging and Alerting Failures | V16 (Security Logging and Error Handling) | — |
| A10 Mishandling of Exceptional Conditions | V16 (Security Logging and Error Handling) | V2 (Validation and Business Logic), V15 (Secure Coding) |

---

## A01:2025 — Broken Access Control

**Rank:** #1 (maintained from 2021)

Access control enforces policy such that users cannot act outside their intended
permissions. Failures lead to unauthorized information disclosure, modification
or destruction of data, or performing business functions outside the user's limits.

---

## A02:2025 — Security Misconfiguration

**Rank:** #2 (moved up from #5 in 2021)

Security misconfiguration occurs when a system, application, or cloud service is
set up incorrectly from a security perspective. Found in 100% of tested applications.

---

## A03:2025 — Software Supply Chain Failures

**Rank:** #3 (NEW — expanded from A06:2021 Vulnerable and Outdated Components)

Software supply chain failures cover breakdowns or compromises in building,
distributing, or updating software — including vulnerabilities or malicious
changes in third-party code, tools, or dependencies.

---

## A04:2025 — Cryptographic Failures

**Rank:** #4 (was #2 in 2021)

Cryptographic failures occur when data in transit or at rest is not adequately
protected, or when weak/deprecated cryptographic algorithms are used.

---

## A05:2025 — Injection

**Rank:** #5 (was #3 in 2021)

Injection flaws occur when untrusted data is sent to an interpreter as part of
a command or query. SQL, NoSQL, OS, LDAP, XPath, XML, SMTP, and expression
language injection all fall into this category. Cross-site scripting (XSS) is
also included here in 2025.

---

## A06:2025 — Insecure Design

**Rank:** #6 (was #4 in 2021)

Insecure design covers missing or ineffective control design. It is distinct from
insecure implementation — a secure design can still have implementation defects,
but an insecure design cannot be fixed by perfect implementation.

---

## A07:2025 — Authentication Failures

**Rank:** #7 (maintained from 2021, renamed from "Identification and Authentication Failures")

Vulnerabilities in authentication and session management allow attackers to
compromise passwords, keys, or session tokens, or exploit implementation flaws
to assume another user's identity.

---

## A08:2025 — Software or Data Integrity Failures

**Rank:** #8 (maintained from 2021)

Software and data integrity failures relate to code and infrastructure that does
not protect against integrity violations. Includes insecure deserialization,
auto-update without integrity verification, and CI/CD pipeline attacks
(e.g., SolarWinds).

---

## A09:2025 — Security Logging and Alerting Failures

**Rank:** #9 (maintained from 2021, renamed from "Security Logging and Monitoring Failures")

Insufficient logging, detection, monitoring, and active response allows attackers
to further attack systems, maintain persistence, pivot to more systems, and tamper,
extract, or destroy data. Breaches often remain undetected for 200+ days.

---

## A10:2025 — Mishandling of Exceptional Conditions

**Rank:** #10 (NEW for 2025 — replaces A10:2021 Server-Side Request Forgery)

Mishandling exceptional conditions occurs when programs fail to prevent, detect,
and respond to unusual and unpredictable situations — leading to crashes,
unexpected behaviour, and vulnerabilities. Covers missing/poor input validation,
high-level error handling instead of at the point of occurrence, unexpected
environmental states, inconsistent exception handling, and unhandled exceptions
leaving the system in an unknown state.
