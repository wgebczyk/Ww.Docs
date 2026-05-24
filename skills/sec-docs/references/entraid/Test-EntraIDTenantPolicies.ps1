#Requires -Version 7.0
<#
.SYNOPSIS
    Audits tenant-wide Entra ID policies against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Performs tenant-level checks once per audit run and returns finding
    hashtables. Writes no files.

    Checks performed:
      V6.1.1   — Tenant security defaults / legacy auth blocking
      V6.3.3   — MFA via Conditional Access
      V9.1.2   — Approved token signing algorithms
      V9.1.3   — JWKS URI from trusted authority / OIDC discovery
      V9.2.1   — Token lifetime enforcement
      V11.2.3  — RSA signing key ≥ 2048 bits

.PARAMETER TenantId
    Tenant GUID.

.PARAMETER ScopeClientIds
    Client IDs to test Conditional Access targeting against. Optional.

.PARAMETER SkipPublicChecks
    Skip OIDC discovery and JWKS checks (useful in air-gapped environments).

.PARAMETER SkipConditionalAccess
    Skip Conditional Access and MFA checks (requires Policy.Read.All).

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check, plus errors.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [string[]]$ScopeClientIds = @(),
    [switch]$SkipPublicChecks,
    [switch]$SkipConditionalAccess
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "EntraIDAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

if (-not (Test-IsGuid $TenantId)) {
    Emit (New-Finding -Id "InvalidTenant" -Asvs "V9.1.3" -Owasp "A07" -Status FAIL `
        -Title "Invalid TenantId: '$TenantId'" -Evidence $TenantId)
    return @($Findings)
}

$graphBase = Get-GraphBaseUrl

# ─── OIDC public checks ───────────────────────────────────────────────────
if ($SkipPublicChecks) {
    Emit (New-Finding -Id "OIDC-Skipped" -Asvs "V9.1.3" -Owasp "A07" -Status UNABLE `
        -Title "OIDC/JWKS public checks skipped (-SkipPublicChecks)" -Evidence "" -Detail "")
} else {
    $OIDC_BASE = "https://login.microsoftonline.com/$TenantId/v2.0"
    $oidcDoc   = $null
    try {
        $oidcDoc = Invoke-RestMethod -Uri "$OIDC_BASE/.well-known/openid-configuration" -ErrorAction Stop
        Emit (New-Finding -Id "OIDC-Discovery" -Asvs "V9.1.3" -Owasp "A07" -Status INFO `
            -Title "OIDC discovery document retrieved" `
            -Detail "issuer: $($oidcDoc.issuer)" -Evidence ($oidcDoc.issuer ?? ""))
    } catch {
        Emit (New-Finding -Id "OIDC-Discovery" -Asvs "V9.1.3" -Owasp "A07" -Status FAIL `
            -Title "OIDC discovery document unreachable" `
            -Detail $_.Exception.Message -Evidence "")
    }

    if ($oidcDoc) {
        # JWKS URI
        $jwksUri       = $oidcDoc.jwks_uri ?? ""
        $trustedPrefix = "https://login.microsoftonline.com/$TenantId"
        if ($jwksUri -and $jwksUri -like "$trustedPrefix*") {
            Emit (New-Finding -Id "OIDC-JwksUri" -Asvs "V9.1.3" -Owasp "A07" -Status PASS `
                -Title "JWKS URI is from pre-configured trusted authority" `
                -Detail $jwksUri -Evidence $jwksUri)
        } elseif (-not $jwksUri) {
            Emit (New-Finding -Id "OIDC-JwksUri" -Asvs "V9.1.3" -Owasp "A07" -Status FAIL `
                -Title "OIDC document does not declare a jwks_uri" `
                -Detail "Expected prefix: $trustedPrefix" -Evidence "(missing)")
        } else {
            Emit (New-Finding -Id "OIDC-JwksUri" -Asvs "V9.1.3" -Owasp "A07" -Status FAIL `
                -Title "JWKS URI does not match expected tenant authority" `
                -Detail "Expected prefix: $trustedPrefix | Actual: $jwksUri" -Evidence $jwksUri)
        }

        # Grant types
        $grantTypes = Get-SafeArray $oidcDoc.grant_types_supported
        $hasImplicit = $grantTypes -contains "implicit"
        $hasPassword = $grantTypes -contains "password"
        $grantList   = ($grantTypes -join ", ")
        if (-not $hasImplicit -and -not $hasPassword) {
            Emit (New-Finding -Id "OIDC-GrantTypes" -Asvs "V10.4.4" -Owasp "A07" -Status PASS `
                -Title "Implicit and ROPC grants not in tenant OIDC supported list" `
                -Detail "Supported: $grantList" -Evidence $grantList)
        } else {
            $bad = @()
            if ($hasImplicit) { $bad += "implicit" }
            if ($hasPassword) { $bad += "password" }
            Emit (New-Finding -Id "OIDC-GrantTypes" -Asvs "V10.4.4" -Owasp "A07" -Status WARN `
                -Title "Tenant OIDC document lists potentially unsafe grant types" `
                -Detail "Listed: $($bad -join ', ') — verify these are not enabled on app registrations" `
                -Evidence $grantList)
        }

        # Signing algorithms
        $algSupported = Get-SafeArray $oidcDoc.id_token_signing_alg_values_supported
        $algValues    = ($algSupported -join ", ")
        $hasNoneAlg   = $algSupported -contains "none"
        if ($hasNoneAlg) {
            Emit (New-Finding -Id "OIDC-Alg-None" -Asvs "V9.1.2" -Owasp "A07" -Status FAIL `
                -Title "OIDC discovery lists 'none' as a supported signing algorithm" `
                -Detail $algValues -Evidence $algValues)
        } elseif ($algSupported.Count -eq 0) {
            Emit (New-Finding -Id "OIDC-Alg" -Asvs "V9.1.2" -Owasp "A07" -Status UNABLE `
                -Title "OIDC discovery does not declare id_token_signing_alg_values_supported" `
                -Detail "" -Evidence "")
        } else {
            Emit (New-Finding -Id "OIDC-Alg" -Asvs "V9.1.2" -Owasp "A07" -Status PASS `
                -Title "Signing algorithms do not include 'none'" `
                -Detail "Listed: $algValues" -Evidence $algValues)
        }

        # JWKS keys
        if ($jwksUri) {
            $jwks = $null
            try {
                $jwks = Invoke-RestMethod -Uri $jwksUri -ErrorAction Stop
            } catch {
                Emit (New-Finding -Id "JWKS-Fetch" -Asvs "V9.1.3" -Owasp "A07" -Status FAIL `
                    -Title "JWKS endpoint unreachable" -Detail $_.Exception.Message -Evidence "")
            }

            if ($jwks) {
                $keys = Get-SafeArray $jwks.keys
                Emit (New-Finding -Id "JWKS-Count" -Asvs "V9.1.3" -Owasp "A07" -Status INFO `
                    -Title "Active signing keys in JWKS" `
                    -Detail "$($keys.Count) key(s) published" `
                    -Evidence "$($keys.Count) keys")

                foreach ($key in $keys) {
                    if ($null -eq $key) { continue }
                    $kid = if ($key.kid) { $key.kid } else { "(no-kid)" }
                    $kty = if ($key.kty) { $key.kty } else { "" }
                    $alg = if ($key.alg) { $key.alg }
                           elseif ($kty)  { "$kty (no alg claim)" }
                           else            { "(unknown)" }

                    if ($kty -eq "RSA" -and $key.n) {
                        try {
                            $nB64    = $key.n.Replace('-', '+').Replace('_', '/')
                            $padded  = $nB64.PadRight([math]::Ceiling($nB64.Length / 4) * 4, '=')
                            $nBytes  = [System.Convert]::FromBase64String($padded)
                            $keyBits = $nBytes.Length * 8
                            $sizeStatus = if ($keyBits -ge 2048) { "PASS" } else { "FAIL" }
                            $sizeQual   = if ($keyBits -ge 2048) { "meets" } else { "does not meet" }
                            Emit (New-Finding -Id "JWKS-KeySize-$kid" -Asvs "V11.2.3" -Owasp "A04" -Status $sizeStatus `
                                -Title "RSA signing key $sizeQual 2048-bit minimum" `
                                -Detail "kid=$kid  size=$keyBits bits  alg=$alg" `
                                -Evidence "$keyBits bits")
                        } catch {
                            Emit (New-Finding -Id "JWKS-KeySize-$kid" -Asvs "V11.2.3" -Owasp "A04" -Status UNABLE `
                                -Title "RSA key modulus could not be decoded" `
                                -Detail "kid=$kid  error=$($_.Exception.Message)" -Evidence "")
                        }
                    }

                    $approvedAlgs = @("RS256","RS384","RS512","ES256","ES384","ES512","PS256","PS384","PS512")
                    if ($alg -notin $approvedAlgs) {
                        Emit (New-Finding -Id "JWKS-Alg-$kid" -Asvs "V9.1.2" -Owasp "A07" -Status WARN `
                            -Title "Signing key uses unexpected algorithm" `
                            -Detail "kid=$kid  alg=$alg  kty=$kty" -Evidence $alg)
                    } else {
                        Emit (New-Finding -Id "JWKS-Alg-$kid" -Asvs "V9.1.2" -Owasp "A07" -Status PASS `
                            -Title "Signing key algorithm is approved" `
                            -Detail "kid=$kid  alg=$alg" -Evidence $alg)
                    }
                }
            }
        }
    }
}

# ─── Token lifetime policies ──────────────────────────────────────────────
$defaultPolicies = Invoke-GraphOdata -Uri "$graphBase/policies/tokenLifetimePolicies?`$filter=isOrganizationDefault eq true" -Silent
# Note: Invoke-GraphOdata returns @() on failure — there's no way to distinguish "no policies" from "no permission" without a status code.
# We treat empty as platform defaults; specific permission errors are surfaced via Write-Warning in the helper.
if ($defaultPolicies.Count -eq 0) {
    Emit (New-Finding -Id "TokenPolicy-Default" -Asvs "V9.2.1" -Owasp "A07" -Status INFO `
        -Title "No custom token lifetime policy — Azure AD platform defaults apply" `
        -Detail "Access Token: 1 hour | Refresh Token: 24 hours (90-day max sliding)" `
        -Evidence "platform defaults")
} else {
    foreach ($policy in $defaultPolicies) {
        if (-not $policy) { continue }
        $atLifetime = "(unknown)"
        try {
            if ($policy.definition) {
                $defJson = $policy.definition
                if ($defJson -is [array]) { $defJson = $defJson[0] }
                if ($defJson) {
                    $def = $defJson | ConvertFrom-Json -ErrorAction Stop
                    if ($def -and $def.TokenLifetimePolicy -and $def.TokenLifetimePolicy.AccessTokenLifetime) {
                        $atLifetime = $def.TokenLifetimePolicy.AccessTokenLifetime
                    }
                }
            }
        } catch {
            $atLifetime = "(parse-error: $($_.Exception.Message))"
        }
        $displayName = if ($policy.displayName) { $policy.displayName } else { "(unnamed)" }
        Emit (New-Finding -Id "TokenPolicy-Custom-$displayName" -Asvs "V9.2.1" -Owasp "A07" -Status INFO `
            -Title "Custom tenant-wide token lifetime policy active: $displayName" `
            -Detail "AccessTokenLifetime=$atLifetime" -Evidence "AccessTokenLifetime=$atLifetime")
    }
}

# ─── Conditional Access ───────────────────────────────────────────────────
if ($SkipConditionalAccess) {
    Emit (New-Finding -Id "CA-Skipped" -Asvs "V6.3.3" -Owasp "A07" -Status UNABLE `
        -Title "Conditional Access check skipped (-SkipConditionalAccess)" -Evidence "" -Detail "")
} else {
    $caPolicies = Invoke-GraphOdata -Uri "$graphBase/identity/conditionalAccess/policies" -Silent
    if ($caPolicies.Count -eq 0) {
        Emit (New-Finding -Id "CA-Access" -Asvs "V6.3.3" -Owasp "A07" -Status UNABLE `
            -Title "No Conditional Access policies retrieved (missing Policy.Read.All or zero policies)" `
            -Detail "Verify MFA enforcement manually in Entra ID portal" -Evidence "")
    } else {
        $enabledPolicies = @($caPolicies | Where-Object { $_ -and $_.state -eq "enabled" })
        $relevantPolicies = @($enabledPolicies | Where-Object {
            $appIds = Get-SafeArray $_.conditions?.applications?.includeApplications
            @($appIds | Where-Object { $_ -and ($_ -in $ScopeClientIds -or $_ -eq "All") }).Count -gt 0
        })
        Emit (New-Finding -Id "CA-Count" -Asvs "V6.3.3" -Owasp "A07" -Status INFO `
            -Title "Conditional Access: $($caPolicies.Count) total, $($enabledPolicies.Count) enabled, $($relevantPolicies.Count) targeting in-scope apps" `
            -Evidence "$($caPolicies.Count) policies")

        $mfaPolicies = @($relevantPolicies | Where-Object {
            $controls = Get-SafeArray $_.grantControls?.builtInControls
            "mfa" -in $controls
        })
        $mfaStatus = if ($mfaPolicies.Count -gt 0) { "PASS" } else { "WARN" }
        $mfaTitle  = if ($mfaPolicies.Count -gt 0) {
                        "MFA enforced by Conditional Access for in-scope apps"
                     } else {
                        "No CA policy with MFA found targeting in-scope apps"
                     }
        $mfaDetail = if ($mfaPolicies.Count -gt 0) {
                        @($mfaPolicies | ForEach-Object { $_.displayName } | Where-Object { $_ }) -join ", "
                     } else {
                        "Verify via Entra ID portal"
                     }
        Emit (New-Finding -Id "CA-MFA" -Asvs "V6.3.3" -Owasp "A07" -Status $mfaStatus `
            -Title $mfaTitle -Detail $mfaDetail -Evidence "$($mfaPolicies.Count) MFA policies")

        $blockLegacy = @($enabledPolicies | Where-Object {
            $clients  = Get-SafeArray $_.conditions?.clientAppTypes
            $controls = Get-SafeArray $_.grantControls?.builtInControls
            ($clients -contains "exchangeActiveSync" -or $clients -contains "other") -and ($controls -contains "block")
        })
        $blockStatus = if ($blockLegacy.Count -gt 0) { "PASS" } else { "WARN" }
        $blockTitle  = if ($blockLegacy.Count -gt 0) {
                        "Legacy authentication blocked by Conditional Access"
                       } else {
                        "No CA policy explicitly blocking legacy authentication found"
                       }
        $blockDetail = if ($blockLegacy.Count -gt 0) {
                        @($blockLegacy | ForEach-Object { $_.displayName } | Where-Object { $_ }) -join ", "
                       } else {
                        "Verify in Entra ID portal under CA > Policies"
                       }
        Emit (New-Finding -Id "CA-BlockLegacy" -Asvs "V6.1.1" -Owasp "A07" -Status $blockStatus `
            -Title $blockTitle -Detail $blockDetail `
            -Evidence "$($blockLegacy.Count) block-legacy policies")
    }

    $secDefaults = Invoke-Graph -Uri "$graphBase/policies/identitySecurityDefaultsEnforcementPolicy" -Select "isEnabled" -Silent
    if ($secDefaults) {
        $sdEnabled = Get-SafeBool $secDefaults.isEnabled
        $sdStatus  = if ($sdEnabled) { "WARN" } else { "INFO" }
        $sdTitle   = if ($sdEnabled) {
                        "Tenant Security Defaults: ENABLED (conflicts with CA — migrate to CA)"
                     } else {
                        "Tenant Security Defaults: disabled (CA policies in use)"
                     }
        Emit (New-Finding -Id "SecDefaults" -Asvs "V6.1.1" -Owasp "A07" -Status $sdStatus `
            -Title $sdTitle -Detail "" -Evidence "isEnabled=$sdEnabled")
    }
}

return @($Findings)
