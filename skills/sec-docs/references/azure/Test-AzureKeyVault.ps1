#Requires -Version 7.0
<#
.SYNOPSIS
    Audits a single Azure Key Vault against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Queries both the ARM management plane and Key Vault data plane. Returns finding
    hashtables. Writes no files. Aggregation/persistence is the caller's job.

    Management-plane checks (ARM — requires Reader on the vault):
      V13.3.1  — Soft-delete enabled
      V13.3.1  — Purge protection enabled
      V13.2.4  — Network ACL default action is "Deny" (not open to internet)
      V13.2.1  — RBAC authorization model in use (not legacy access policies)

    Data-plane checks (vault.azure.net — requires Key Vault Reader/List):
      V11.2.3  — Enabled keys: RSA >= 3072 bits (PASS), 2048–3071 (WARN), < 2048 (FAIL)
                              EC: P-256 or larger (>= 256 bits)
      V13.3.4  — Secrets: check for entries with no expiry date set

.PARAMETER VaultName
    Name of the Key Vault (without .vault.azure.net).

.PARAMETER SubscriptionId
    Azure subscription GUID that contains the vault.

.PARAMETER ResourceGroup
    Resource group name that contains the vault.

.PARAMETER Unit
    Deployable unit name (e.g. api, integration). Optional.

.PARAMETER Environment
    Environment label (e.g. Dev, QA, Prod). Defaults to "Unknown".

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VaultName,
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

$vaultId   = $VaultName -replace "[^a-zA-Z0-9]", "-"
$armId     = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.KeyVault/vaults/$VaultName"
$vaultUri  = "https://$VaultName.vault.azure.net"

# ─── ARM: Fetch vault properties ─────────────────────────────────────────────
$vault = Invoke-Arm -ResourceId $armId -ApiVersion "2023-07-01" -Silent
if ($null -eq $vault) {
    Emit (New-Finding -Id "KV-Fetch-$vaultId" -Asvs "V13.3.1" -Owasp "A05" -Status UNABLE `
        -Title "Key Vault '$VaultName' not accessible via ARM" `
        -Detail "Either the vault does not exist, or Reader permission is missing on subscription $SubscriptionId" `
        -Evidence $armId -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

$props = $vault.properties

# ─── V13.3.1: Soft delete ─────────────────────────────────────────────────────
$softDelete = Get-SafeBool $props.enableSoftDelete
if ($softDelete) {
    $retentionDays = if ($props.softDeleteRetentionInDays) { [int]$props.softDeleteRetentionInDays } else { 90 }
    Emit (New-Finding -Id "KV-SoftDelete-$vaultId" -Asvs "V13.3.1" -Owasp "A05" -Status PASS `
        -Title "Key Vault soft-delete enabled (retention: $retentionDays days)" `
        -Evidence "enableSoftDelete=true, retentionDays=$retentionDays" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "KV-SoftDelete-$vaultId" -Asvs "V13.3.1" -Owasp "A05" -Status FAIL `
        -Title "Key Vault soft-delete is NOT enabled — deleted secrets cannot be recovered" `
        -Detail "Enable soft-delete to prevent accidental or malicious permanent deletion" `
        -Evidence "enableSoftDelete=false" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.3.1: Purge protection ────────────────────────────────────────────────
$purgeProtection = Get-SafeBool $props.enablePurgeProtection
if ($purgeProtection) {
    Emit (New-Finding -Id "KV-PurgeProtection-$vaultId" -Asvs "V13.3.1" -Owasp "A05" -Status PASS `
        -Title "Key Vault purge protection enabled" `
        -Evidence "enablePurgeProtection=true" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "KV-PurgeProtection-$vaultId" -Asvs "V13.3.1" -Owasp "A05" -Status WARN `
        -Title "Key Vault purge protection is NOT enabled — soft-deleted items can be purged immediately" `
        -Detail "Enable purge protection to enforce the soft-delete retention period" `
        -Evidence "enablePurgeProtection=false/null" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.2.4: Network ACLs ────────────────────────────────────────────────────
$networkAcls    = $props.networkAcls
$defaultAction  = if ($networkAcls?.defaultAction) { $networkAcls.defaultAction } else { "Allow" }
$privateEps     = @(Get-SafeArray $props.privateEndpointConnections | Where-Object { $_ })
$ipRules        = @(Get-SafeArray $networkAcls?.ipRules | Where-Object { $_ })
$vnetRules      = @(Get-SafeArray $networkAcls?.virtualNetworkRules | Where-Object { $_ })

if ($defaultAction -eq "Deny") {
    $accessSummary = "ipRules=$($ipRules.Count) vnetRules=$($vnetRules.Count) privateEndpoints=$($privateEps.Count)"
    Emit (New-Finding -Id "KV-NetworkACL-$vaultId" -Asvs "V13.2.4" -Owasp "A05" -Status PASS `
        -Title "Key Vault network ACL default action is Deny (not publicly accessible)" `
        -Detail $accessSummary -Evidence "defaultAction=Deny" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    $publicNote = if ($privateEps.Count -gt 0) {
        "Private endpoint(s) configured ($($privateEps.Count)) but network ACL still allows public access"
    } else {
        "No private endpoints and default action is Allow — vault is reachable from the internet"
    }
    $status = if ($privateEps.Count -gt 0 -and $ipRules.Count -eq 0 -and $vnetRules.Count -eq 0) { "WARN" } else { "FAIL" }
    Emit (New-Finding -Id "KV-NetworkACL-$vaultId" -Asvs "V13.2.4" -Owasp "A05" -Status $status `
        -Title "Key Vault network ACL default action is Allow — public network access permitted" `
        -Detail $publicNote -Evidence "defaultAction=$defaultAction" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.2.1: Authorization model (RBAC vs. legacy access policies) ───────────
$enableRbac = Get-SafeBool $props.enableRbacAuthorization
if ($enableRbac) {
    Emit (New-Finding -Id "KV-RBAC-$vaultId" -Asvs "V13.2.1" -Owasp "A01" -Status PASS `
        -Title "Key Vault uses Azure RBAC authorization (not legacy access policies)" `
        -Evidence "enableRbacAuthorization=true" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    $apCount = @(Get-SafeArray $props.accessPolicies | Where-Object { $_ }).Count
    Emit (New-Finding -Id "KV-RBAC-$vaultId" -Asvs "V13.2.1" -Owasp "A01" -Status WARN `
        -Title "Key Vault uses legacy Vault Access Policies ($apCount policies) instead of Azure RBAC" `
        -Detail "Migrate to Azure RBAC for fine-grained, auditable access control" `
        -Evidence "enableRbacAuthorization=false, accessPolicies=$apCount" `
        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
}

# ─── Data-plane: Keys ─────────────────────────────────────────────────────────
$keysResp = Invoke-DataPlane -Uri "$vaultUri/keys" -ApiVersion "7.4" -TokenType "vault" -Silent
if ($null -eq $keysResp) {
    Emit (New-Finding -Id "KV-Keys-Fetch-$vaultId" -Asvs "V11.2.3" -Owasp "A02" -Status UNABLE `
        -Title "Key Vault keys list not accessible (data plane)" `
        -Detail "Ensure the identity has Key Vault Reader or Keys List permission on $VaultName" `
        -Evidence $vaultUri -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    $keys = Get-SafeArray $keysResp.value
    if ($keys.Count -eq 0) {
        Emit (New-Finding -Id "KV-Keys-$vaultId" -Asvs "V11.2.3" -Owasp "A02" -Status INFO `
            -Title "No keys found in Key Vault '$VaultName'" `
            -Evidence "0 keys" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    } else {
        foreach ($keyItem in $keys) {
            $keyName    = $keyItem.kid -replace ".*/keys/([^/]+).*", '$1'
            $keyEnabled = Get-SafeBool $keyItem.attributes?.enabled $true
            if (-not $keyEnabled) { continue }

            # Fetch key details for type/size
            $keyDetail = Invoke-DataPlane -Uri "$vaultUri/keys/$keyName" -ApiVersion "7.4" -TokenType "vault" -Silent
            $kty  = $keyDetail?.key?.kty  ?? "Unknown"
            $nB64 = $keyDetail?.key?.n    ?? ""

            if ($kty -in @("RSA", "RSA-HSM") -and $nB64) {
                try {
                    $padded  = $nB64.Replace('-','+').Replace('_','/').PadRight([math]::Ceiling($nB64.Length/4)*4,'=')
                    $nBytes  = [System.Convert]::FromBase64String($padded)
                    $keyBits = $nBytes.Length * 8

                    if ($keyBits -ge 3072) {
                        Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status PASS `
                            -Title "Key '$keyName': RSA-$keyBits meets 128-bit security level (>= 3072 bits)" `
                            -Evidence "$kty-$keyBits" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
                    } elseif ($keyBits -ge 2048) {
                        Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status WARN `
                            -Title "Key '$keyName': RSA-$keyBits meets legacy minimum but is below ASVS v5 128-bit threshold (3072 bits)" `
                            -Detail "Plan to rotate key to RSA-3072 or EC P-256+" `
                            -Evidence "$kty-$keyBits" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
                    } else {
                        Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status FAIL `
                            -Title "Key '$keyName': RSA-$keyBits is below 2048-bit minimum — must be rotated immediately" `
                            -Evidence "$kty-$keyBits" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
                    }
                } catch {
                    Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status UNABLE `
                        -Title "Key '$keyName': RSA modulus could not be decoded" `
                        -Detail $_.Exception.Message -Evidence $kty `
                        -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
                }
            } elseif ($kty -in @("EC", "EC-HSM")) {
                $curve    = $keyDetail?.key?.crv ?? "Unknown"
                $ecStatus = if ($curve -in @("P-256","P-256K","P-384","P-521")) { "PASS" } else { "WARN" }
                Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status $ecStatus `
                    -Title "Key '$keyName': EC curve $curve" `
                    -Evidence "$kty-$curve" -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
            } else {
                Emit (New-Finding -Id "KV-Key-$vaultId-$keyName" -Asvs "V11.2.3" -Owasp "A02" -Status INFO `
                    -Title "Key '$keyName': key type $kty — manual review required" `
                    -Evidence $kty -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
            }
        }
    }
}

# ─── Data-plane: Secrets (expiry checks) ──────────────────────────────────────
$secretsResp = Invoke-DataPlane -Uri "$vaultUri/secrets" -ApiVersion "7.4" -TokenType "vault" -Silent
if ($null -eq $secretsResp) {
    Emit (New-Finding -Id "KV-Secrets-Fetch-$vaultId" -Asvs "V13.3.4" -Owasp "A02" -Status UNABLE `
        -Title "Key Vault secrets list not accessible (data plane)" `
        -Detail "Ensure the identity has Secrets List permission on $VaultName" `
        -Evidence $vaultUri -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
} else {
    $secrets     = @(Get-SafeArray $secretsResp.value | Where-Object { $_ })
    $enabledSec  = @($secrets | Where-Object { Get-SafeBool $_.attributes?.enabled $true })
    $now         = [datetime]::UtcNow

    $noExpiry  = @($enabledSec | Where-Object { -not $_.attributes?.expires })
    $expired   = @($enabledSec | Where-Object { $_.attributes?.expires -and ([datetime]::Parse($_.attributes.expires) -lt $now) })
    $expiring  = @($enabledSec | Where-Object { $_.attributes?.expires -and ([datetime]::Parse($_.attributes.expires) -lt $now.AddDays(30)) -and ([datetime]::Parse($_.attributes.expires) -ge $now) })

    $summary = "total=$($enabledSec.Count) noExpiry=$($noExpiry.Count) expired=$($expired.Count) expiringIn30d=$($expiring.Count)"

    if ($expired.Count -gt 0) {
        Emit (New-Finding -Id "KV-Secrets-Expired-$vaultId" -Asvs "V13.3.4" -Owasp "A02" -Status FAIL `
            -Title "$($expired.Count) expired secret(s) in '$VaultName'" `
            -Detail "Expired secrets should be rotated or disabled" -Evidence $summary `
            -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    }
    if ($noExpiry.Count -gt 0) {
        $names = @($noExpiry | ForEach-Object { $_.id -replace ".*/secrets/([^/]+).*", '$1' }) -join ", "
        Emit (New-Finding -Id "KV-Secrets-NoExpiry-$vaultId" -Asvs "V13.3.4" -Owasp "A02" -Status WARN `
            -Title "$($noExpiry.Count) secret(s) with no expiry date set" `
            -Detail "Secrets without expiry cannot be automatically rotated: $names" `
            -Evidence "noExpiry=$($noExpiry.Count)" `
            -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    }
    if ($expiring.Count -gt 0) {
        Emit (New-Finding -Id "KV-Secrets-Expiring-$vaultId" -Asvs "V13.3.4" -Owasp "A02" -Status WARN `
            -Title "$($expiring.Count) secret(s) expiring within 30 days" `
            -Evidence "expiringIn30d=$($expiring.Count)" `
            -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    }
    if ($expired.Count -eq 0 -and $noExpiry.Count -eq 0 -and $expiring.Count -eq 0) {
        Emit (New-Finding -Id "KV-Secrets-$vaultId" -Asvs "V13.3.4" -Owasp "A02" -Status PASS `
            -Title "All $($enabledSec.Count) enabled secret(s) have future expiry dates" `
            -Evidence $summary -AppId $VaultName -AppEnv $Environment -AppUnit $Unit)
    }
}

return @($Findings)
