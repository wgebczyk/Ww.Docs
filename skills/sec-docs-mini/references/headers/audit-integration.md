# HTTP Security Headers Audit Integration

Probes each deployable unit's base URL for HTTP security response headers (CSP,
HSTS, X-Frame-Options, etc.). The skill generates and maintains a project
orchestrator that delegates to immutable utility scripts.

Load `references/audit-integration-shared.md` for the 4-phase pattern, manifest
rules, JSON schema, citation format, and immutable-scripts constraint.

## Architecture

```
references/headers/                                    ← skill-owned (IMMUTABLE)
├── HttpHeadersAudit.Utils.psm1            # HTTP probe helpers, CSP parser, New-Finding
├── Test-HttpSecurityHeaders.ps1           # audit ONE base URL -> finding[]
├── Write-HttpHeadersAuditReport.ps1       # write JSON + Markdown reports
└── Invoke-HttpHeadersAudit.template.ps1   # template for the orchestrator below

docs/sec-docs/reports/headers/                         ← skill-managed (per project)
├── Invoke-HttpHeadersAudit.ps1            # orchestrator — generated + edited by skill
├── headers-audit-latest.{json,md}         # audit output
└── headers-audit-{ts}.{json,md}           # historical copies
```

## Manifest

One entry per URL: `@{ Unit; Environment; BaseUrl; DisplayName }`.
Usually one entry per unit per environment.

## Phase 1 — Base URL Discovery

Scan the single repository (from its root) for the following sources:

| Source | Keys to read |
|---|---|
| `appsettings*.json`, `*.settings.json` | `ASPNETCORE_URLS`, `Kestrel:Endpoints:*:Url`, `AllowedOrigins[]` (CORS — first `https://` entry), `BaseUrl`, `AppUrl` |
| `.env`, `*.env`, `.env.*` | `APP_URL`, `BASE_URL`, `ASPNETCORE_URLS`, `FRONTEND_URL` |
| `helm/values*.yaml`, `values-*.yaml` | `ingress.hosts[].host` (prefix `https://`), `baseUrl` |
| `docker-compose*.yml`, `*.compose.yml` | `ASPNETCORE_URLS` in `environment:` sections |

Deduplicate URLs. Strip path segments — use only scheme + host.

Derive `Environment` from path/filename hints or hostname pattern. Use `"Unknown"`
if not derivable.

If no base URLs are discoverable, note "HTTP Headers audit: not applicable" in
the run log and skip the ASVS mapping below.

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\headers\Invoke-HttpHeadersAudit.ps1
```

## ASVS Category Mapping

| ASVS Category | Finding `asvs` values |
|---|---|
| V3 Web Frontend | `V3.4.1`, `V3.4.2`, `V3.4.3`, `V3.4.4`, `V3.4.5`, `V3.4.6`, `V3.4.8` |
| V12 Secure Communication | `V12.1.1` (HTTP→HTTPS redirect) |
| V13 Configuration | `V13.4.4`, `V13.4.6` |
