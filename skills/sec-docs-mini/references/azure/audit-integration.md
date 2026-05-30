# Azure Resource Audit Integration

Audits Azure Key Vault and App Configuration stores via the ARM REST API and
Key Vault data plane (authenticated through Azure CLI).

Load `references/audit-integration-shared.md` for the 4-phase pattern, manifest
rules, JSON schema, citation format, and immutable-scripts constraint.

## Architecture

```
references/azure/                                      ← skill-owned (IMMUTABLE)
├── AzureResourceAudit.Utils.psm1          # ARM + data-plane REST helpers, New-Finding
├── Test-AzureKeyVault.ps1                 # audit ONE Key Vault -> finding[]
├── Test-AzureAppConfig.ps1                # audit ONE App Config store -> finding[]
├── Write-AzureResourceAuditReport.ps1     # write JSON + Markdown reports
└── Invoke-AzureResourceAudit.template.ps1 # template for the orchestrator below

docs/sec-docs/reports/azure/                           ← skill-managed (per project)
├── Invoke-AzureResourceAudit.ps1          # orchestrator — generated + edited by skill
├── azure-audit-latest.{json,md}           # audit output
└── azure-audit-{ts}.{json,md}             # historical copies
```

## Manifest — Two Lists

This integration has **two** separate arrays. Edit each independently inside the
manifest block.

**Key Vaults:** `@{ Unit; Environment; VaultName; SubscriptionId; ResourceGroup; DisplayName }`

**App Config stores:** `@{ Unit; Environment; StoreName; SubscriptionId; ResourceGroup; DisplayName }`

## Phase 1 — Discovery

Scan the single repository (from its root). Sources:

**Key Vaults:**

| Source | Keys to read |
|---|---|
| `appsettings*.json`, `*.settings.json` | `KeyVault:VaultUri`, `Azure:KeyVaultName`, `VaultUri`, any string containing `.vault.azure.net` |
| `.env`, `*.env`, `.env.*` | `KEY_VAULT_URI`, `KEY_VAULT_NAME`, `AZURE_KEY_VAULT_NAME` |
| `helm/values*.yaml`, `values-*.yaml` | `keyVaultName`, `keyVaultUri` |
| `*.bicep`, ARM templates (`*.json`) | `Microsoft.KeyVault/vaults` resource definitions |

**App Config stores:**

| Source | Keys to read |
|---|---|
| `appsettings*.json`, `*.settings.json` | `AppConfiguration:Endpoint`, `Azure:AppConfig:Endpoint`, any string containing `.azconfig.io` |
| `.env`, `*.env`, `.env.*` | `APP_CONFIG_ENDPOINT`, `AZURE_APP_CONFIG_ENDPOINT` |
| `helm/values*.yaml` | `appConfigEndpoint`, `appConfigName` |
| `*.bicep`, ARM templates | `Microsoft.AppConfiguration/configurationStores` resource definitions |

**Subscription / Resource Group** discovery: read from `*.bicep` or ARM template
`resourceGroup()` / `subscriptionId()` calls, pipeline variable files
(`azure-pipelines.yml`, `*.tfvars`), or curated docs (`topic: azure` with a
`subscriptions:` list). If a subscription or resource group cannot be derived,
leave the field as `"Unknown"` and surface it in the run log — the manifest must
be completed by the user before the orchestrator can run.

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\azure\Invoke-AzureResourceAudit.ps1
```

Prerequisites: `az login`; Reader on the subscription; Key Vault Reader plus
Keys/List + Secrets/List on each vault.

## ASVS Category Mapping

| ASVS Category | Finding `asvs` values |
|---|---|
| V11 Cryptography | `V11.2.3` (Key Vault key sizes) |
| V13 Configuration | `V13.2.1`, `V13.2.4`, `V13.3.1`, `V13.3.2`, `V13.3.4` |
