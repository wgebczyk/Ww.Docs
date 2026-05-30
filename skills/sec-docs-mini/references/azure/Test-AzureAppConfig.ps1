#Requires -Version 7.0
<#
.SYNOPSIS
    Audits a single Azure App Configuration store against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Queries the ARM management plane for the configuration store properties.
    Returns finding hashtables. Writes no files.

    Checks performed:
      V13.2.1  — Local authentication disabled (Entra ID auth enforced)
      V13.2.4  — Public network access disabled or restricted
      V13.3.1  — Soft-delete retention configured (> 0 days)
      V13.3.2  — Encryption: customer-managed key in use (informational if not)

.PARAMETER StoreName
    Name of the App Configuration store.

.PARAMETER SubscriptionId
    Azure subscription GUID that contains the store.

.PARAMETER ResourceGroup
    Resource group name that contains the store.

.PARAMETER Unit
    Deployable unit name (e.g. api, web). Optional.

.PARAMETER Environment
    Environment label (e.g. Dev, QA, Prod). Defaults to "Unknown".

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StoreName,
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [string]$Unit        = "",
    [string]$Environment = "Unknown"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "AzureResourceAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

$storeId = $StoreName -replace "[^a-zA-Z0-9]", "-"
$armId   = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.AppConfiguration/configurationStores/$StoreName"

# ─── ARM: Fetch store properties ──────────────────────────────────────────────
$store = Invoke-Arm -ResourceId $armId -ApiVersion "2023-03-01" -Silent
if ($null -eq $store) {
    Emit (New-Finding -Id "AppConfig-Fetch-$storeId" -Asvs "V13.3.1" -Owasp "A05" -Status UNABLE `
        -Title "App Configuration store '$StoreName' not accessible via ARM" `
        -Detail "Either the store does not exist, or Reader permission is missing on subscription $SubscriptionId" `
        -Evidence $armId -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

$props = $store.properties

# ─── V13.2.1: Local authentication ────────────────────────────────────────────
$localAuthDisabled = Get-SafeBool $props.disableLocalAuth
if ($localAuthDisabled) {
    Emit (New-Finding -Id "AppConfig-LocalAuth-$storeId" -Asvs "V13.2.1" -Owasp "A07" -Status PASS `
        -Title "App Configuration local authentication is disabled (Entra ID enforced)" `
        -Evidence "disableLocalAuth=true" -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "AppConfig-LocalAuth-$storeId" -Asvs "V13.2.1" -Owasp "A07" -Status WARN `
        -Title "App Configuration allows local authentication (access keys)" `
        -Detail "Set disableLocalAuth=true to enforce Entra ID authentication and disable access-key auth" `
        -Evidence "disableLocalAuth=false/null" -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.2.4: Public network access ──────────────────────────────────────────
$publicAccess = if ($props.publicNetworkAccess) { $props.publicNetworkAccess } else { "Enabled" }
$privateEps   = @(Get-SafeArray $props.privateEndpointConnections | Where-Object { $_ })

if ($publicAccess -eq "Disabled") {
    Emit (New-Finding -Id "AppConfig-Network-$storeId" -Asvs "V13.2.4" -Owasp "A05" -Status PASS `
        -Title "App Configuration public network access is disabled" `
        -Evidence "publicNetworkAccess=Disabled" -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
} else {
    $accessDetail = if ($privateEps.Count -gt 0) {
        "Private endpoint(s) configured ($($privateEps.Count)), but public access is still enabled"
    } else {
        "No private endpoints. Store is reachable from the public internet"
    }
    $status = if ($privateEps.Count -gt 0) { "WARN" } else { "FAIL" }
    Emit (New-Finding -Id "AppConfig-Network-$storeId" -Asvs "V13.2.4" -Owasp "A05" -Status $status `
        -Title "App Configuration public network access is Enabled" `
        -Detail $accessDetail -Evidence "publicNetworkAccess=$publicAccess" `
        -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.3.1: Soft-delete retention ──────────────────────────────────────────
$softDeleteDays = if ($props.softDeleteRetentionInDays -ne $null) { [int]$props.softDeleteRetentionInDays } else { 0 }
if ($softDeleteDays -gt 0) {
    Emit (New-Finding -Id "AppConfig-SoftDelete-$storeId" -Asvs "V13.3.1" -Owasp "A05" -Status PASS `
        -Title "App Configuration soft-delete retention: $softDeleteDays day(s)" `
        -Evidence "softDeleteRetentionInDays=$softDeleteDays" `
        -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "AppConfig-SoftDelete-$storeId" -Asvs "V13.3.1" -Owasp "A05" -Status WARN `
        -Title "App Configuration soft-delete retention is 0 or not configured" `
        -Detail "Free-tier stores do not support soft-delete. Standard tier supports 1–7 days. Upgrade if this store holds production configuration." `
        -Evidence "softDeleteRetentionInDays=$softDeleteDays" `
        -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.3.2: Customer-managed key encryption ────────────────────────────────
$cmkProps = $props.encryption?.keyVaultProperties
$hasCmk   = $cmkProps?.keyIdentifier -ne $null -and $cmkProps.keyIdentifier -ne ""

if ($hasCmk) {
    Emit (New-Finding -Id "AppConfig-CMK-$storeId" -Asvs "V13.3.2" -Owasp "A02" -Status PASS `
        -Title "App Configuration uses customer-managed key encryption" `
        -Detail "Key: $($cmkProps.keyIdentifier)" `
        -Evidence "CMK=$($cmkProps.keyIdentifier)" `
        -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "AppConfig-CMK-$storeId" -Asvs "V13.3.2" -Owasp "A02" -Status INFO `
        -Title "App Configuration uses Microsoft-managed keys (not customer-managed)" `
        -Detail "For L3 applications handling sensitive configuration, consider customer-managed key (CMK) encryption via Key Vault" `
        -Evidence "CMK=none" -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)
}

# ─── Sku / tier (informational — needed for capability context) ───────────────
$sku = $store.sku?.name ?? "unknown"
Emit (New-Finding -Id "AppConfig-Sku-$storeId" -Asvs "V13.3.1" -Owasp "A05" -Status INFO `
    -Title "App Configuration SKU: $sku" `
    -Detail "Free tier lacks private endpoints, soft-delete, and CMK. Standard tier is required for full ASVS compliance." `
    -Evidence "sku=$sku" -AppId $StoreName -AppEnv $Environment -AppUnit $Unit)

return @($Findings)
