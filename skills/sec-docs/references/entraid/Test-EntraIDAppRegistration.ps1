#Requires -Version 7.0
<#
.SYNOPSIS
    Audits a single Entra ID app registration against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Reads one app registration via Microsoft Graph and returns finding
    hashtables. Writes no files. Aggregation/persistence is the caller's job.

    Checks performed:
      V8.2.1   — App roles match code-defined roles
      V8.3.1   — Single-tenant sign-in audience
      V9.2.3   — App ID URI matches api://{clientId}
      V10.4.1  — Redirect URIs: no wildcards
      V10.4.4  — Implicit grant disabled
      V10.4.4  — Public client / ROPC settings
      V10.4.11 — OAuth2 scopes exposed
      V13.3.1  — Client secret / certificate hygiene

.PARAMETER ClientId
    GUID of the app registration to audit.

.PARAMETER TenantId
    Tenant GUID (informational; Graph token already targets the authenticated
    tenant via Azure CLI).

.PARAMETER Environment
    Environment label (e.g. Dev, QA, Prod). Defaults to "Unknown".

.PARAMETER Unit
    Deployable unit name (e.g. api1, web, integration). Optional.

.PARAMETER RepoRoots
    Repo paths to scan for role names (used by V8.2.1). Optional.

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check, plus errors.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ClientId,
    [string]$TenantId    = "",
    [string]$Environment = "Unknown",
    [string]$Unit        = "",
    [string[]]$RepoRoots = @()
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "EntraIDAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

if (-not (Test-IsGuid $ClientId)) {
    Emit (New-Finding -Id "InvalidClientId-$Environment" -Asvs "V10.4.1" -Owasp "A07" -Status FAIL `
        -Title "Invalid ClientId format: '$ClientId'" -Evidence $ClientId `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

$graphBase = Get-GraphBaseUrl

$appSelectFields = "id,appId,displayName,signInAudience,web,publicClient,spa,isFallbackPublicClient," +
                   "appRoles,requiredResourceAccess,passwordCredentials,keyCredentials,identifierUris," +
                   "info,tags,api"

$apps = Invoke-GraphOdata -Uri "$graphBase/applications?`$filter=appId eq '$ClientId'&`$select=$appSelectFields"
if ($apps.Count -eq 0) {
    Emit (New-Finding -Id "AppReg-Fetch-$Environment-$ClientId" -Asvs "V10.4.1" -Owasp "A07" -Status UNABLE `
        -Title "App registration not accessible (clientId: $ClientId)" `
        -Detail "Either the app doesn't exist in the tenant or Application.Read.All is missing" `
        -Evidence "" -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

$app = $apps[0]

# ─── V8.3.1: Sign-in audience ─────────────────────────────────────────────
$audience  = if ($app.signInAudience) { $app.signInAudience } else { "Unknown" }
$audStatus = if ($audience -eq "AzureADMyOrg") { "PASS" } else { "FAIL" }
$audDetail = if ($audStatus -eq "PASS") {
                "Correctly single-tenant"
             } else {
                "External accounts may authenticate — expected AzureADMyOrg"
             }
Emit (New-Finding -Id "Audience-$Environment-$ClientId" -Asvs "V8.3.1" -Owasp "A01" -Status $audStatus `
    -Title "Sign-in audience: $audience" -Detail $audDetail -Evidence $audience `
    -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)

# ─── V10.4.1: Redirect URIs ───────────────────────────────────────────────
# Graph omits .web for API-only apps and .spa for non-SPA apps — guard both.
$webRedirects = Get-SafeArray $app.web?.redirectUris
$spaRedirects = Get-SafeArray $app.spa?.redirectUris
$allRedirects = @(@($webRedirects) + @($spaRedirects) | Where-Object { $_ } | Select-Object -Unique)
$wildcardUris = @($allRedirects | Where-Object { $_ -match '\*' })
if ($wildcardUris.Count -gt 0) {
    Emit (New-Finding -Id "RedirectUri-Wildcard-$Environment-$ClientId" -Asvs "V10.4.1" -Owasp "A07" -Status FAIL `
        -Title "Wildcard redirect URI(s) registered" `
        -Detail "Wildcards: $($wildcardUris -join ', ')" -Evidence ($wildcardUris -join "; ") `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
} elseif ($allRedirects.Count -eq 0) {
    Emit (New-Finding -Id "RedirectUri-$Environment-$ClientId" -Asvs "V10.4.1" -Owasp "A07" -Status INFO `
        -Title "No redirect URIs registered (API-only registration)" `
        -Detail "Expected for backend APIs" -Evidence "none" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "RedirectUri-$Environment-$ClientId" -Asvs "V10.4.1" -Owasp "A07" -Status PASS `
        -Title "Redirect URIs registered without wildcards" `
        -Detail ($allRedirects -join " | ") -Evidence ($allRedirects -join "; ") `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

# ─── V10.4.4: Implicit grant ──────────────────────────────────────────────
# .web.implicitGrantSettings can be missing entirely on newer apps.
$implicitAccess  = Get-SafeBool $app.web?.implicitGrantSettings?.enableAccessTokenIssuance
$implicitIdToken = Get-SafeBool $app.web?.implicitGrantSettings?.enableIdTokenIssuance
$implicitAccessStatus = if ($implicitAccess) { "FAIL" } else { "PASS" }
$implicitAccessTitle  = if ($implicitAccess) { "Implicit grant (Access Token): ENABLED" } else { "Implicit grant (Access Token): disabled" }
$implicitAccessDetail = if ($implicitAccess) { "enableAccessTokenIssuance=true — must be disabled" } else { "" }
Emit (New-Finding -Id "ImplicitAccess-$Environment-$ClientId" -Asvs "V10.4.4" -Owasp "A07" `
    -Status $implicitAccessStatus -Title $implicitAccessTitle -Detail $implicitAccessDetail `
    -Evidence "enableAccessTokenIssuance=$implicitAccess" `
    -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)

$implicitIdStatus = if ($implicitIdToken) { "FAIL" } else { "PASS" }
$implicitIdTitle  = if ($implicitIdToken) { "Implicit grant (ID Token): ENABLED" } else { "Implicit grant (ID Token): disabled" }
$implicitIdDetail = if ($implicitIdToken) { "enableIdTokenIssuance=true — Hybrid flow active" } else { "" }
Emit (New-Finding -Id "ImplicitIdToken-$Environment-$ClientId" -Asvs "V10.4.4" -Owasp "A07" `
    -Status $implicitIdStatus -Title $implicitIdTitle -Detail $implicitIdDetail `
    -Evidence "enableIdTokenIssuance=$implicitIdToken" `
    -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)

# ─── V10.4.4: Public client / ROPC ────────────────────────────────────────
$isFallback   = Get-SafeBool $app.isFallbackPublicClient
$pubRedirects = Get-SafeArray $app.publicClient?.redirectUris
if ($isFallback -or $pubRedirects.Count -gt 0) {
    Emit (New-Finding -Id "PublicClient-$Environment-$ClientId" -Asvs "V10.4.4" -Owasp "A07" -Status WARN `
        -Title "Public client / ROPC settings configured" `
        -Detail "isFallbackPublicClient=$isFallback  publicClient.redirectUris=$($pubRedirects -join ',')" `
        -Evidence "isFallbackPublicClient=$isFallback" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "PublicClient-$Environment-$ClientId" -Asvs "V10.4.4" -Owasp "A07" -Status PASS `
        -Title "Public client / ROPC not configured" `
        -Detail "" -Evidence "isFallbackPublicClient=false" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

# ─── V8.2.1: App roles vs. code-discovered roles ──────────────────────────
$registeredRoles = @(
    Get-SafeArray $app.appRoles |
        Where-Object { $_ -and (Get-SafeBool $_.isEnabled) } |
        ForEach-Object { $_.value } |
        Where-Object { $_ }   # drop null/empty role names
)
$codeRoles = if ($RepoRoots.Count -gt 0) { @(Get-CodeRoles -RepoRoots $RepoRoots) } else { @() }

if ($codeRoles.Count -gt 0) {
    $missingInReg = @($codeRoles       | Where-Object { $_ -notin $registeredRoles })
    $extraInReg   = @($registeredRoles | Where-Object { $_ -notin $codeRoles })
    if ($missingInReg.Count -gt 0) {
        Emit (New-Finding -Id "AppRoles-Missing-$Environment-$ClientId" -Asvs "V8.2.1" -Owasp "A01" -Status WARN `
            -Title "Role(s) in code not found in app registration" `
            -Detail "Missing: $($missingInReg -join ', ')" -Evidence ($missingInReg -join ", ") `
            -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
    }
    if ($extraInReg.Count -gt 0) {
        Emit (New-Finding -Id "AppRoles-Extra-$Environment-$ClientId" -Asvs "V8.2.1" -Owasp "A01" -Status WARN `
            -Title "Role(s) registered but not found in code" `
            -Detail "Extra: $($extraInReg -join ', ') — verify intentional" `
            -Evidence ($extraInReg -join ", ") `
            -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
    }
    if ($missingInReg.Count -eq 0 -and $extraInReg.Count -eq 0) {
        Emit (New-Finding -Id "AppRoles-$Environment-$ClientId" -Asvs "V8.2.1" -Owasp "A01" -Status PASS `
            -Title "App roles match code-defined roles" `
            -Detail "Registered: $($registeredRoles -join ', ')" `
            -Evidence ($registeredRoles -join ", ") `
            -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
    }
} else {
    Emit (New-Finding -Id "AppRoles-$Environment-$ClientId" -Asvs "V8.2.1" -Owasp "A01" -Status INFO `
        -Title "App roles registered: $($registeredRoles -join ', ')" `
        -Detail "Code-defined roles not extracted (no -RepoRoots) — manual review required" `
        -Evidence ($registeredRoles -join ", ") `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.3.1: Client secrets ──────────────────────────────────────────────
$secrets = Get-SafeArray $app.passwordCredentials
$now     = [datetime]::UtcNow
$expiredSecrets  = @($secrets | Where-Object { $_ -and $_.endDateTime -and ([datetime]$_.endDateTime -lt $now) })
$expiringSecrets = @($secrets | Where-Object { $_ -and $_.endDateTime -and ([datetime]$_.endDateTime -lt $now.AddDays(30)) -and ([datetime]$_.endDateTime -ge $now) })
$noExpiry        = @($secrets | Where-Object { $_ -and -not $_.endDateTime })

if ($secrets.Count -eq 0) {
    Emit (New-Finding -Id "Secrets-$Environment-$ClientId" -Asvs "V13.3.1" -Owasp "A02" -Status INFO `
        -Title "No client secrets (certificate-only or Managed Identity)" `
        -Detail "" -Evidence "0 secrets" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
} else {
    $summary   = "Total=$($secrets.Count) Expired=$($expiredSecrets.Count) ExpiringIn30d=$($expiringSecrets.Count) NoExpiry=$($noExpiry.Count)"
    $secStatus = if ($expiredSecrets.Count -gt 0)                                                  { "FAIL" }
                 elseif ($expiringSecrets.Count -gt 0 -or $noExpiry.Count -gt 0)                   { "WARN" }
                 else                                                                              { "PASS" }
    $noExpiryDetail = if ($noExpiry.Count -gt 0) {
                        $names = @($noExpiry | ForEach-Object { $_.displayName } | Where-Object { $_ })
                        "Secrets with no expiry: $($names -join ', ')"
                      } else { "" }
    Emit (New-Finding -Id "Secrets-$Environment-$ClientId" -Asvs "V13.3.1" -Owasp "A02" -Status $secStatus `
        -Title "Client secret status: $summary" -Detail $noExpiryDetail -Evidence $summary `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.3.1: Certificate credentials ─────────────────────────────────────
$certs         = Get-SafeArray $app.keyCredentials
$expiredCerts  = @($certs | Where-Object { $_ -and $_.endDateTime -and ([datetime]$_.endDateTime -lt $now) })
$expiringCerts = @($certs | Where-Object { $_ -and $_.endDateTime -and ([datetime]$_.endDateTime -lt $now.AddDays(30)) -and ([datetime]$_.endDateTime -ge $now) })
if ($expiredCerts.Count -gt 0) {
    Emit (New-Finding -Id "Certs-Expired-$Environment-$ClientId" -Asvs "V13.3.1" -Owasp "A02" -Status FAIL `
        -Title "Expired certificate credential(s) on app registration" `
        -Detail "$($expiredCerts.Count) expired certificate(s)" `
        -Evidence "$($expiredCerts.Count) expired" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
} elseif ($expiringCerts.Count -gt 0) {
    Emit (New-Finding -Id "Certs-Expiring-$Environment-$ClientId" -Asvs "V13.3.1" -Owasp "A02" -Status WARN `
        -Title "Certificate credential(s) expiring within 30 days" `
        -Detail "$($expiringCerts.Count) cert(s)" `
        -Evidence "$($expiringCerts.Count) expiring" `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

# ─── V9.2.3: App ID URI ───────────────────────────────────────────────────
$identifierUris = Get-SafeArray $app.identifierUris
$expectedUri    = "api://$ClientId"
$uriStatus      = if ($identifierUris -contains $expectedUri) { "PASS" } else { "WARN" }
$uriTitle       = if ($uriStatus -eq "PASS") {
                    "App ID URI matches api://{clientId}"
                  } else {
                    "App ID URI does not include expected api://{clientId}"
                  }
Emit (New-Finding -Id "IdentifierUri-$Environment-$ClientId" -Asvs "V9.2.3" -Owasp "A07" -Status $uriStatus `
    -Title $uriTitle `
    -Detail "Expected: $expectedUri  Registered: $($identifierUris -join ', ')" `
    -Evidence ($identifierUris -join ", ") `
    -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)

# ─── V10.4.11: OAuth2 scopes via service principal ────────────────────────
$sps = Invoke-GraphOdata -Uri "$graphBase/servicePrincipals?`$filter=appId eq '$ClientId'&`$select=id,displayName,oauth2PermissionScopes,accountEnabled" -Silent
if ($sps.Count -gt 0) {
    $sp = $sps[0]
    $scopes = @(Get-SafeArray $sp.oauth2PermissionScopes | Where-Object { $_ -and (Get-SafeBool $_.isEnabled) })
    $scopeValues = @($scopes | ForEach-Object { $_.value } | Where-Object { $_ })
    Emit (New-Finding -Id "SP-Scopes-$Environment-$ClientId" -Asvs "V10.4.11" -Owasp "A01" -Status INFO `
        -Title "Exposed OAuth2 scopes: $($scopeValues -join ', ')" `
        -Detail "Review that only required scopes are exposed" `
        -Evidence ($scopeValues -join ", ") `
        -AppId $ClientId -AppEnv $Environment -AppUnit $Unit)
}

return @($Findings)
