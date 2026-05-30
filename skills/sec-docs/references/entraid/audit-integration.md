# Entra ID Audit Integration

Audits Entra ID (Azure AD) app registrations and tenant policies via Microsoft Graph.
The skill does not call Graph itself — it generates and maintains a project orchestrator
that delegates to immutable utility scripts.

Load `references/audit-integration-shared.md` for the 4-phase pattern, manifest rules,
JSON schema, citation format, and immutable-scripts constraint. This file only carries
Entra-ID-specific content.

## Architecture

```
references/entraid/                                    ← skill-owned (IMMUTABLE)
├── EntraIDAudit.Utils.psm1                # Graph auth + finding helpers (null-safe)
├── Test-EntraIDAppRegistration.ps1        # audit ONE app registration  -> finding[]
├── Test-EntraIDTenantPolicies.ps1         # tenant-wide policies        -> finding[]
├── Write-EntraIDAuditReport.ps1           # write JSON + Markdown reports
└── Invoke-EntraIDAudit.template.ps1       # template for the orchestrator below

docs/sec-docs/reports/entraid/                         ← skill-managed (per project)
├── Invoke-EntraIDAudit.ps1                # orchestrator — generated + edited by skill
├── entraid-audit-latest.{json,md}         # audit output (skill reads + cites)
└── entraid-audit-{ts}.{json,md}           # historical copies
```

## Deployable Units Model

A "deployable unit" is an independently deployed component (e.g. `api1`, `api2`,
`web`, `app`, `integration`). A project always has at least one unit; many have
several. A unit may have zero, one, or multiple app registrations (e.g. API + SPA,
or one per environment).

Manifest entry: `@{ Unit; Environment; ClientId; DisplayName }`.

## Phase 1 — Unit & App-Registration Discovery

Unit signals, in order of authority:

| Signal | Source |
|---|---|
| Explicit declaration | `docs/sec-docs/curated/*.md` with `topic: entraid` + `deployable-units:`. **Overrides everything else.** |
| One repo per unit | Each `.git/`-containing directory at workspace root. Repo name = unit name. |
| Multi-unit repo | `src/<name>/`, `services/<name>/`, `apps/<name>/`, or services in `docker-compose.yml`. |
| Helm chart packaging | One unit per top-level chart directory. |

App-registration sources per unit:

| Source | Keys to read |
|---|---|
| `appsettings*.json`, `*.settings.json`, `local.settings.json` | `AzureAd:ClientId`, `AzureAD:ClientId`, `EntraId:ClientId`, `MicrosoftIdentity:ClientId`, `Authentication:ClientId` (and matching `:TenantId`) |
| `.env`, `*.env`, `.env.*` | `AZURE_CLIENT_ID` / `CLIENT_ID`, `AZURE_TENANT_ID` / `TENANT_ID` |
| `helm/values*.yaml`, `values-*.yaml` | `clientId:`, `tenantId:` |
| `docker-compose*.yml`, `*.compose.yml` | `CLIENT_ID` / `AZURE_CLIENT_ID` in `environment:` sections |

A unit may have **multiple** distinct app registrations — record each separately
and set `DisplayName` so the role is identifiable (e.g. `"web Dev (API)"`,
`"web Dev (SPA)"`).

Derive `Environment` from path/filename hints (`Dev`, `QA`, `Stage`, `Prod`) or
from curated metadata. Use `"Unknown"` if no signal.

Derive `TenantId` from the same sources or a curated doc. If multiple tenant IDs
appear, prefer the curated doc; otherwise pick the most common and surface the
conflict in the run log.

If no app registrations are found anywhere, the orchestrator is not needed —
note "Entra ID audit: not applicable" in the run log and skip ASVS mapping below.

## Manifest

Key order per entry: `Unit`, `Environment`, `ClientId`, `DisplayName`.
Sort by `Unit`, then `Environment`, then `ClientId`. Always emit all four keys.

Canonical example (whitespace-sensitive):

```powershell
# === MANIFEST BEGIN === (skill-managed; do not hand-edit between these markers)

# Tenant GUID. Replaced by the sec-docs skill on first generation.
$TenantId = "11111111-1111-1111-1111-111111111111"

# Deployable units and their app registrations.
# A project may have several units (api1, api2, web, integration, ...).
# A unit may have one or more app registrations across environments.
# Each entry: @{ Unit; Environment; ClientId; DisplayName }
$Applications = @(
    @{ Unit = "api1"; Environment = "Dev";  ClientId = "22222222-2222-2222-2222-222222222222"; DisplayName = "api1 Dev"  }
    @{ Unit = "api1"; Environment = "Prod"; ClientId = "33333333-3333-3333-3333-333333333333"; DisplayName = "api1 Prod" }
    @{ Unit = "web";  Environment = "Dev";  ClientId = "44444444-4444-4444-4444-444444444444"; DisplayName = "web Dev"   }
)

# === MANIFEST END ===
```

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\entraid\Invoke-EntraIDAudit.ps1 -RepoRoots .\<repo1>,.\<repo2>
```

Optional flags: `-SkipPublicChecks` (air-gapped), `-SkipConditionalAccess`
(when Policy.Read.All is unavailable).

## ASVS Category Mapping

Pull these `Asvs` values from `findings[]` when assessing each category:

| ASVS Category | Finding `asvs` values |
|---|---|
| V6 Authentication | `V6.1.1`, `V6.3.3` |
| V7 Session Management | `V7.2.2`, `V9.2.1` (token lifetime) |
| V8 Authorization | `V8.2.1`, `V8.3.1`, `V8.4.1` |
| V9 Self-contained Tokens | `V9.1.2`, `V9.1.3`, `V9.2.1`, `V9.2.3` |
| V10 OAuth and OIDC | `V10.4.1`, `V10.4.4`, `V10.4.11` |
| V11 Cryptography | `V11.2.3` |
| V13 Configuration | `V13.3.1` |

If the audit JSON does not exist, mark these requirements `NOT-ASSESSED` and note:
> Entra ID audit not yet run. Orchestrator at
> `docs/sec-docs/reports/entraid/Invoke-EntraIDAudit.ps1` exists; run it to produce evidence.

## Index Row

Add a row to `docs/sec-docs/index.md` showing whether the audit has been run, its
date, and the per-unit / per-environment app count from the manifest. See
`references/category-page-template.md`.
