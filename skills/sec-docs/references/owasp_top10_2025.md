---
source: "https://owasp.org/Top10/2025/"
version: "2025"
item-count: 10
output-file: "pages/asvs_top10_owasp.md"
---

# OWASP Top 10 2025

Static reference — load this file when generating `docs/sec-docs/pages/asvs_top10_owasp.md`.
Source: https://owasp.org/Top10/2025/

## ASVS Category Mapping

Each Top 10 item maps to one or more ASVS v5 categories. Use these mappings to
cross-reference findings from the individual category files already generated in
`docs/sec-docs/`. Do not re-analyse the codebase from scratch — pull evidence
from the relevant category files and summarise here.

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
**CWEs Mapped:** 40
**Avg Incidence Rate:** 3.74% | **Max Incidence Rate:** 20.15%
**Total Occurrences:** 1,839,701 | **Total CVEs:** 32,654
**Notable CWEs:** CWE-200 (Exposure of Sensitive Information to Unauthorized Actor),
CWE-201 (Exposure Through Sent Data), CWE-918 (SSRF), CWE-352 (CSRF)

**Description:**
Access control enforces policy such that users cannot act outside their intended
permissions. Failures lead to unauthorized information disclosure, modification
or destruction of data, or performing business functions outside the user's limits.

Common vulnerabilities include:
- Violation of least privilege / deny-by-default — access granted to anyone instead of specific roles
- Bypassing access control by modifying the URL, internal state, or HTML (IDOR)
- Missing access controls for POST, PUT, DELETE API endpoints
- Elevation of privilege — acting as a user without being logged in, or gaining admin access
- Metadata manipulation (JWT tampering, cookie manipulation to elevate privileges)
- CORS misconfiguration allowing API access from unauthorized origins
- Force browsing to authenticated or privileged pages

**How to Prevent:**
- Enforce access control on trusted server-side code or serverless APIs only
- Deny by default for all non-public resources
- Implement access control once and reuse it throughout the application (minimize CORS)
- Enforce record ownership — users should only access their own records
- Log access control failures; alert on repeated failures
- Implement rate limiting on API and controller access
- Invalidate stateful session IDs server-side on logout; keep JWT tokens short-lived


---

## A02:2025 — Security Misconfiguration

**Rank:** #2 (moved up from #5 in 2021)
**CWEs Mapped:** 16
**Avg Incidence Rate:** 3.00% | **Max Incidence Rate:** 27.70%
**Total Occurrences:** 719,084 | **Total CVEs:** 1,375
**Notable CWEs:** CWE-16 (Configuration), CWE-611 (XXE)

**Description:**
Security misconfiguration occurs when a system, application, or cloud service is
set up incorrectly from a security perspective. Found in 100% of tested applications.

Vulnerable if:
- Missing security hardening across any part of the application stack
- Unnecessary features/services/ports/accounts enabled
- Default accounts and passwords unchanged
- Error messages expose stack traces or sensitive internals to users
- Latest security features disabled after upgrades
- Security headers missing or not set to secure values
- Framework/library/database security settings not configured to secure values

**How to Prevent:**
- Repeatable hardening process for all environments (dev, QA, prod) — identical config, different credentials
- Minimal platform — remove unused features, components, documentation, samples
- Review and update configurations as part of patch management
- Segmented application architecture
- Send security directives (CSP, HSTS, X-Content-Type-Options, etc.)
- Automated configuration scanning in CI/CD pipelines


---

## A03:2025 — Software Supply Chain Failures

**Rank:** #3 (NEW — expanded from A06:2021 Vulnerable and Outdated Components)
**CWEs Mapped:** 6
**Avg Incidence Rate:** 5.72% (highest avg incidence) | **Max Incidence Rate:** 9.56%
**Total Occurrences:** 215,248 | **Total CVEs:** 11
**Notable CWEs:** CWE-477 (Obsolete Function), CWE-1104 (Unmaintained Third-Party Components),
CWE-1329 (Reliance on Non-Updateable Component), CWE-1395 (Vulnerable Third-Party Component)

**Description:**
Software supply chain failures cover breakdowns or compromises in building,
distributing, or updating software — including vulnerabilities or malicious changes
in third-party code, tools, or dependencies.

Vulnerable if:
- Component versions (including transitive dependencies) not tracked
- Software, OS, frameworks, or libraries are vulnerable, unsupported, or out of date
- No regular vulnerability scanning or subscription to security bulletins
- No change management for supply chain components (IDEs, extensions, repos, image registries)
- Supply chain not hardened with access control and least privilege
- No separation of duty — single person can write and deploy to production
- Components from untrusted sources used in production
- Patching is periodic (monthly/quarterly) rather than risk-based and timely
- CI/CD pipeline security weaker than the systems it builds and deploys

**How to Prevent:**
- Generate and maintain a Software Bill of Materials (SBOM) centrally
- Track direct and transitive dependencies
- Remove unused dependencies, features, components, files
- Continuously inventory versions using OWASP Dependency Track, Dependency Check, retire.js
- Monitor CVE/NVD/OSV for vulnerabilities in components used; subscribe to alerts
- Obtain components from official, trusted sources over secure links; prefer signed packages
- Harden CI/CD pipeline; enforce separation of duty for code review and deployment

---

## A04:2025 — Cryptographic Failures

**Rank:** #4 (was #2 in 2021)
**CWEs Mapped:** (data in ASVS V11)
**Notable CWEs:** CWE-259 (Hard-coded Password), CWE-327 (Broken/Risky Crypto Algorithm),
CWE-331 (Insufficient Entropy)

**Description:**
Cryptographic failures occur when data in transit or at rest is not adequately
protected, or when weak/deprecated cryptographic algorithms are used.

Vulnerable if:
- Data transmitted in cleartext (HTTP, SMTP, FTP without TLS)
- Old or weak cryptographic algorithms (MD5, SHA1, RC4, DES) used
- Default crypto keys used, weak keys generated, or keys not rotated
- Encryption not enforced (e.g., missing Secure cookie attribute or HTTP security headers)
- Server certificate not validated
- Passwords stored using weak hashing (MD5, SHA1 unsalted, or without work factor)
- Deprecated cryptographic padding (PKCS#1 v1.5) used

**How to Prevent:**
- Classify data processed, stored, or transmitted; apply controls per data sensitivity
- Do not store sensitive data unnecessarily
- Encrypt all data in transit with TLS; enforce HSTS
- Encrypt all sensitive data at rest using strong, current algorithms
- Use strong adaptive password hashing (Argon2, scrypt, bcrypt, PBKDF2)
- Use authenticated encryption (AES-GCM); avoid ECB mode
- Generate keys using CSPRNG; enforce key rotation
- Avoid deprecated protocols (TLS < 1.2, SSLv3)


---

## A05:2025 — Injection

**Rank:** #5 (was #3 in 2021)
**CWEs Mapped:** (data in ASVS V1)
**Notable CWEs:** CWE-79 (XSS), CWE-89 (SQL Injection), CWE-73 (External Control of File Name/Path)

**Description:**
Injection flaws occur when untrusted data is sent to an interpreter as part of
a command or query. SQL, NoSQL, OS, LDAP, XPath, XML, SMTP, and expression
language injection all fall into this category. Cross-site scripting (XSS) is
also included here in 2025.

Vulnerable if:
- User-supplied data is not validated, filtered, or sanitised by the application
- Dynamic queries or non-parameterised calls with hostile input used in the interpreter
- Hostile data used in ORM search parameters to extract additional records
- Hostile data concatenated directly into SQL, OS, LDAP commands

**How to Prevent:**
- Use a safe API that avoids the interpreter entirely, or parameterised queries
- Use positive server-side input validation (allow-list)
- For residual dynamic queries: escape special characters using the specific interpreter's syntax
- Use LIMIT and other SQL controls to prevent mass disclosure on SQL injection
- Use context-aware output encoding for HTML, JS, CSS, URL contexts (XSS prevention)
- Apply Content Security Policy (CSP) as defence-in-depth against XSS


---

## A06:2025 — Insecure Design

**Rank:** #6 (was #4 in 2021)
**CWEs Mapped:** (data in ASVS V2, V15)
**Notable CWEs:** CWE-209 (Error Message with Sensitive Info), CWE-256 (Unprotected Storage of Credentials),
CWE-501 (Trust Boundary Violation), CWE-522 (Insufficiently Protected Credentials)

**Description:**
Insecure design covers missing or ineffective control design. It is distinct from
insecure implementation — a secure design can still have implementation defects,
but an insecure design cannot be fixed by perfect implementation.

Vulnerable if:
- Business logic flows lack threat modelling and security controls by design
- No security user stories or security requirements defined
- No secure design patterns, paved-road components, or reference architectures used
- No proof-of-concept or pentesting during design phase
- Credential recovery flows use knowledge-based answers ("secret questions")
- No rate limiting on high-value flows (checkout, ticket purchase)
- Multi-step business flows can be skipped or reordered

**How to Prevent:**
- Establish and use a secure development lifecycle with security professionals
- Use threat modelling for critical authentication, access control, and business logic
- Write security user stories; integrate security requirements into acceptance criteria
- Use secure design patterns and paved-road components
- Limit resource consumption per user or service (rate limiting, quotas)
- Segregate tiers on the system and network layers by their exposure and protection needs


---

## A07:2025 — Authentication Failures

**Rank:** #7 (maintained from 2021, renamed from "Identification and Authentication Failures")
**CWEs Mapped:** 36
**Avg Incidence Rate:** 2.92% | **Max Incidence Rate:** 15.80%
**Total Occurrences:** 1,120,673 | **Total CVEs:** 7,147
**Notable CWEs:** CWE-259 (Hard-coded Password), CWE-297 (Certificate Host Mismatch),
CWE-287 (Improper Authentication), CWE-384 (Session Fixation), CWE-798 (Hard-coded Credentials)

**Description:**
Vulnerabilities in authentication and session management allow attackers to
compromise passwords, keys, or session tokens, or exploit implementation flaws
to assume another user's identity.

Vulnerable if:
- Credential stuffing, brute force, or password spray attacks permitted
- Default, weak, or well-known passwords allowed
- New accounts can be created with already-breached credentials
- Weak or ineffective credential recovery (knowledge-based answers)
- Passwords stored in plain text, encrypted, or weakly hashed
- Missing or ineffective multi-factor authentication
- Session identifier exposed in the URL or insecure location
- Session identifier reused after successful login
- Sessions not invalidated on logout or inactivity timeout

**How to Prevent:**
- Implement MFA to prevent credential stuffing, brute force, and stolen-credential reuse
- Encourage use of password managers
- Do not ship or deploy with default credentials
- Implement weak-password checks against a list of breached passwords
- Align password length, complexity, and rotation policies with NIST 800-63b
- Harden account registration and credential recovery against enumeration attacks (constant-time responses)
- Limit or delay failed login attempts; alert admins on attacks (log credential stuffing)
- Use a server-side session manager generating new random session IDs on login; invalidate on logout


---

## A08:2025 — Software or Data Integrity Failures

**Rank:** #8 (maintained from 2021)
**CWEs Mapped:** (data in ASVS V9, V15)
**Notable CWEs:** CWE-829 (Inclusion of Functionality from Untrusted Control Sphere),
CWE-494 (Download of Code Without Integrity Check), CWE-502 (Deserialization of Untrusted Data)

**Description:**
Software and data integrity failures relate to code and infrastructure that does
not protect against integrity violations. Includes insecure deserialization,
auto-update without integrity verification, and CI/CD pipeline attacks (e.g., SolarWinds).

Vulnerable if:
- Application relies on plugins, libraries, or modules from untrusted sources, repositories, CDNs
- Insecure CI/CD pipeline allows introduction of unauthorized code or access
- Auto-update functionality downloads and applies updates without integrity verification
- Objects or data encoded/serialised in a structure that an attacker can see and modify
- Insecure deserialization — application deserialises attacker-modified objects

**How to Prevent:**
- Use digital signatures or other mechanisms to verify software/data integrity
- Ensure libraries and dependencies (e.g., npm, Maven) consume known-good repos; host internal mirror
- Use software supply chain security tools to verify no known vulnerabilities in components
- Ensure CI/CD pipeline has proper segregation, configuration, and access control
- Do not send unsigned or unencrypted serialised data to untrusted clients
- Use integrity checks or digital signatures to detect tampering
- Use Subresource Integrity (SRI) for third-party JavaScript and CSS on HTML pages


---

## A09:2025 — Security Logging and Alerting Failures

**Rank:** #9 (maintained from 2021, renamed from "Security Logging and Monitoring Failures")
**CWEs Mapped:** (data in ASVS V16)
**Notable CWEs:** CWE-117 (Log Injection), CWE-223 (Omission of Security-relevant Information),
CWE-532 (Sensitive Information in Log Files)

**Description:**
Insufficient logging, detection, monitoring, and active response allows attackers
to further attack systems, maintain persistence, pivot to more systems, and tamper,
extract, or destroy data. Breaches often remain undetected for 200+ days.

Vulnerable if:
- Auditable events (logins, failed logins, high-value transactions) not logged
- Warnings and errors generate no, inadequate, or unclear log messages
- Logs not monitored for suspicious activity
- Logs stored locally only (no centralised, tamper-resistant log store)
- No alerting thresholds or escalation processes defined
- Log entries not structured or in a format that log tools cannot parse
- Sensitive data logged (PII, credentials, payment card data)
- Log injection possible (untrusted input written to logs without encoding)

**How to Prevent:**
- Log all login, access control, and server-side input validation failures with enough context
- Ensure log format is consumable by log management solutions
- Encode log data to prevent injection
- Protect logs from tampering — use append-only log stores or forward to remote SIEM
- Establish monitoring and alerting so suspicious activities are detected and responded to quickly
- Establish or adopt an incident response and recovery plan
- Use DAST tools and penetration testing to detect lack of monitoring


---

## A10:2025 — Mishandling of Exceptional Conditions

**Rank:** #10 (NEW for 2025 — replaces A10:2021 Server-Side Request Forgery)
**CWEs Mapped:** 24
**Avg Incidence Rate:** 2.95% | **Max Incidence Rate:** 20.67%
**Total Occurrences:** 769,581 | **Total CVEs:** 3,416
**Notable CWEs:** CWE-209 (Error Message with Sensitive Info), CWE-234 (Missing Parameter Handling),
CWE-274 (Insufficient Privileges Handling), CWE-476 (NULL Pointer Dereference),
CWE-636 (Failing Open)

**Description:**
Mishandling exceptional conditions occurs when programs fail to prevent, detect,
and respond to unusual and unpredictable situations — leading to crashes,
unexpected behaviour, and vulnerabilities. Covers missing/poor input validation,
high-level error handling instead of at the point of occurrence, unexpected
environmental states (memory, privilege, network), inconsistent exception handling,
and unhandled exceptions leaving the system in an unknown state.

Vulnerable if:
- Exceptions not caught at the point they occur, or not caught at all
- Application falls into unknown/unpredictable state on error
- Fail-open behaviour — transaction proceeds despite validation/logic errors
- Error messages expose sensitive internals (stack traces, query details, secrets)
- No global exception handler as last resort
- No rate limiting — exceptional conditions can be triggered by volume

**How to Prevent:**
- Catch every possible system error at the point where it occurs and handle meaningfully
- If part-way through a transaction: roll back every part (fail closed, never fail open)
- Include logging and alerting as part of exception handling
- Implement a global exception handler as a "last resort" safety net
- Add rate limiting, resource quotas, and throttling to prevent exceptional conditions
- Use strict input validation and centralised error handling
- Monitor for repeated identical errors — patterns may indicate an active attack

