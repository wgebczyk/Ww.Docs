# TLS Audit Integration

Performs TLS handshakes against each deployable endpoint using
`[System.Net.Security.SslStream]` to assess protocol and certificate posture.

Load `references/audit-integration-shared.md` for the 4-phase pattern, manifest
rules, JSON schema, citation format, and immutable-scripts constraint.

## Architecture

```
references/tls/                                        ← skill-owned (IMMUTABLE)
├── TlsAudit.Utils.psm1                # TLS handshake helpers, New-Finding
├── Test-TlsEndpoint.ps1               # audit ONE hostname:port -> finding[]
├── Write-TlsAuditReport.ps1           # write JSON + Markdown reports
└── Invoke-TlsAudit.template.ps1       # template for the orchestrator below

docs/sec-docs/reports/tls/                             ← skill-managed (per project)
├── Invoke-TlsAudit.ps1                # orchestrator — generated + edited by skill
├── tls-audit-latest.{json,md}         # audit output
└── tls-audit-{ts}.{json,md}           # historical copies
```

## Manifest

One entry per hostname: `@{ Unit; Environment; Hostname; Port; DisplayName }`.
`Port` defaults to `443` when omitted.

## Phase 1 — Hostname Discovery

Use the same URL sources as the HTTP Headers audit (scan the single repository
from its root). Extract the hostname from each discovered URL (strip scheme and
path). Deduplicate.

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\tls\Invoke-TlsAudit.ps1
```

## Protocol-Downgrade Limitation

`Test-TlsEndpoint.ps1` verifies the protocol negotiated by a current TLS 1.2/1.3
client. It cannot verify whether the server *accepts* TLS 1.0/1.1 connections
(OS policy disables those protocol versions on modern Windows/.NET). Mark V12.1.1
as PARTIAL if the TLS audit passes but source code does not explicitly configure
minimum TLS version — full downgrade testing requires testssl.sh or equivalent.

## ASVS Category Mapping

| ASVS Category | Finding `asvs` values |
|---|---|
| V11 Cryptography | `V11.2.3` (certificate key size) |
| V12 Secure Communication | `V12.1.1`, `V12.1.2`, `V12.2.1`, `V12.2.2` |
