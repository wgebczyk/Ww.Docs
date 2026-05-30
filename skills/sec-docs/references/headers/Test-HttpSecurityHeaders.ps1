#Requires -Version 7.0
<#
.SYNOPSIS
    Audits HTTP security response headers for a single base URL against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Probes one URL and returns finding hashtables. Writes no files.
    Aggregation/persistence is the caller's job.

    Checks performed:
      V3.4.1  — Strict-Transport-Security: max-age >= 31536000; includeSubDomains
      V3.4.2  — CORS Access-Control-Allow-Origin not wildcard '*'
      V3.4.3  — Content-Security-Policy present with required directives
      V3.4.4  — X-Content-Type-Options: nosniff
      V3.4.5  — Referrer-Policy present
      V3.4.6  — CSP frame-ancestors directive restricts framing
      V3.4.8  — Cross-Origin-Opener-Policy present on document responses
      V12.1.1 — HTTP endpoint redirects to HTTPS (when probing http:// URL)
      V13.4.4 — HTTP TRACE method rejected
      V13.4.6 — Server/X-Powered-By headers do not expose version information

.PARAMETER BaseUrl
    The URL to probe (e.g. https://api.example.com or https://app.example.com).
    Should be the canonical base URL for the deployable unit.

.PARAMETER Unit
    Deployable unit name (e.g. api, web). Optional.

.PARAMETER Environment
    Environment label (e.g. Dev, QA, Prod). Defaults to "Unknown".

.PARAMETER SkipCertificateCheck
    Skip TLS certificate validation (useful for Dev/QA environments with self-signed certs).

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [string]$Unit        = "",
    [string]$Environment = "Unknown",
    [switch]$SkipCertificateCheck
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "HttpHeadersAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

$urlId = $BaseUrl -replace "[^a-zA-Z0-9]", "-"
$probeArgs = @{
    Uri                  = $BaseUrl
    SkipCertificateCheck = $SkipCertificateCheck.IsPresent
}

# ─── Probe the URL ────────────────────────────────────────────────────────────
$probe = Invoke-HttpProbe @probeArgs
if (-not $probe.Success) {
    Emit (New-Finding -Id "Probe-$urlId" -Asvs "V12.2.1" -Owasp "A05" -Status UNABLE `
        -Title "Could not connect to $BaseUrl" `
        -Detail $probe.Error -Evidence $probe.Error `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

$h = $probe.Headers

# ─── V12.1.1: HTTP → HTTPS redirect ──────────────────────────────────────────
if ($BaseUrl -match "^http://") {
    $httpProbe = Invoke-HttpProbe -Uri $BaseUrl -MaxRedirects 0 -SkipCertificateCheck:$SkipCertificateCheck.IsPresent
    if ($httpProbe.Success -and $httpProbe.StatusCode -in @(301, 302, 307, 308)) {
        $location = $httpProbe.Headers["location"] ?? ""
        if ($location -match "^https://") {
            Emit (New-Finding -Id "HttpsRedirect-$urlId" -Asvs "V12.1.1" -Owasp "A05" -Status PASS `
                -Title "HTTP redirects to HTTPS ($($httpProbe.StatusCode))" `
                -Detail "Location: $location" -Evidence "HTTP $($httpProbe.StatusCode) -> $location" `
                -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
        } else {
            Emit (New-Finding -Id "HttpsRedirect-$urlId" -Asvs "V12.1.1" -Owasp "A05" -Status FAIL `
                -Title "HTTP redirects but not to HTTPS" `
                -Detail "Location: $location" -Evidence "HTTP $($httpProbe.StatusCode) -> $location" `
                -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
        }
    } elseif ($httpProbe.Success) {
        Emit (New-Finding -Id "HttpsRedirect-$urlId" -Asvs "V12.1.1" -Owasp "A05" -Status FAIL `
            -Title "HTTP endpoint does not redirect to HTTPS (status $($httpProbe.StatusCode))" `
            -Detail "Expected 301/302 redirect to https://" -Evidence "HTTP $($httpProbe.StatusCode)" `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    }
}

# ─── V3.4.1: Strict-Transport-Security ────────────────────────────────────────
$hsts = $h["strict-transport-security"] ?? ""
if (-not $hsts) {
    Emit (New-Finding -Id "HSTS-Missing-$urlId" -Asvs "V3.4.1" -Owasp "A05" -Status FAIL `
        -Title "Strict-Transport-Security header absent" `
        -Detail "Add: Strict-Transport-Security: max-age=31536000; includeSubDomains" `
        -Evidence "(missing)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    $maxAge = 0
    if ($hsts -match "max-age=(\d+)") { $maxAge = [int]$Matches[1] }
    $hasSubdomains = $hsts -match "includeSubDomains"
    $hasPreload    = $hsts -match "preload"

    if ($maxAge -lt 31536000) {
        Emit (New-Finding -Id "HSTS-MaxAge-$urlId" -Asvs "V3.4.1" -Owasp "A05" -Status FAIL `
            -Title "HSTS max-age below required minimum (1 year = 31536000)" `
            -Detail "Current max-age: $maxAge" -Evidence $hsts `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } elseif (-not $hasSubdomains) {
        Emit (New-Finding -Id "HSTS-SubDomains-$urlId" -Asvs "V3.4.1" -Owasp "A05" -Status WARN `
            -Title "HSTS present but includeSubDomains missing (required for L2/L3)" `
            -Detail $hsts -Evidence $hsts `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } else {
        $preloadNote = if ($hasPreload) { " (preload flag set)" } else { "" }
        Emit (New-Finding -Id "HSTS-$urlId" -Asvs "V3.4.1" -Owasp "A05" -Status PASS `
            -Title "HSTS present with valid max-age and includeSubDomains$preloadNote" `
            -Detail $hsts -Evidence $hsts `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    }
}

# ─── V3.4.2: CORS Access-Control-Allow-Origin ─────────────────────────────────
$acao = $h["access-control-allow-origin"] ?? ""
if ($acao -eq "*") {
    Emit (New-Finding -Id "CORS-Wildcard-$urlId" -Asvs "V3.4.2" -Owasp "A01" -Status WARN `
        -Title "Access-Control-Allow-Origin: * (wildcard) on this endpoint" `
        -Detail "Verify response contains no sensitive data when Access-Control-Allow-Credentials is not set" `
        -Evidence "Access-Control-Allow-Origin: *" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} elseif ($acao) {
    Emit (New-Finding -Id "CORS-$urlId" -Asvs "V3.4.2" -Owasp "A01" -Status PASS `
        -Title "Access-Control-Allow-Origin is a fixed value" `
        -Detail "Value: $acao" -Evidence $acao `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "CORS-$urlId" -Asvs "V3.4.2" -Owasp "A01" -Status INFO `
        -Title "No Access-Control-Allow-Origin header (CORS not enabled on this endpoint)" `
        -Evidence "(absent)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

# ─── V3.4.3 + V3.4.6: Content-Security-Policy ────────────────────────────────
$cspRaw = $h["content-security-policy"] ?? ""
if (-not $cspRaw) {
    Emit (New-Finding -Id "CSP-Missing-$urlId" -Asvs "V3.4.3" -Owasp "A05" -Status FAIL `
        -Title "Content-Security-Policy header absent" `
        -Detail "Required directives: object-src 'none'; base-uri 'none'; frame-ancestors" `
        -Evidence "(missing)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    Emit (New-Finding -Id "CSP-FrameAncestors-$urlId" -Asvs "V3.4.6" -Owasp "A05" -Status FAIL `
        -Title "CSP frame-ancestors absent (no CSP header)" `
        -Evidence "(missing)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    $csp = Get-CspDirectives $cspRaw

    # V3.4.3: required directives
    $objectSrc = $csp["object-src"] ?? ($csp["default-src"] ?? "")
    $baseUri   = $csp["base-uri"]   ?? ""
    $scriptSrc = $csp["script-src"] ?? ($csp["default-src"] ?? "")

    $objectNone = $objectSrc -match "'none'"
    $baseNone   = $baseUri   -match "'none'"

    $hasNonce       = $scriptSrc -match "'nonce-[^']+'"
    $hasHash        = $scriptSrc -match "'sha(256|384|512)-[^']+'"
    $hasUnsafeInline = $scriptSrc -match "'unsafe-inline'"
    $hasUnsafeEval   = $scriptSrc -match "'unsafe-eval'"

    $cspFails  = [System.Collections.Generic.List[string]]::new()
    $cspWarns  = [System.Collections.Generic.List[string]]::new()

    if (-not $objectNone)   { [void]$cspFails.Add("object-src should be 'none'") }
    if (-not $baseNone)     { [void]$cspFails.Add("base-uri should be 'none'") }
    if ($hasUnsafeEval)     { [void]$cspFails.Add("'unsafe-eval' in script-src") }
    if ($hasUnsafeInline -and -not ($hasNonce -or $hasHash)) {
        [void]$cspFails.Add("'unsafe-inline' in script-src without nonce or hash")
    }
    if ($hasUnsafeInline -and ($hasNonce -or $hasHash)) {
        [void]$cspWarns.Add("'unsafe-inline' present with nonce/hash (browsers with nonce support ignore unsafe-inline, but older browsers don't)")
    }

    if ($cspFails.Count -gt 0) {
        Emit (New-Finding -Id "CSP-Policy-$urlId" -Asvs "V3.4.3" -Owasp "A05" -Status FAIL `
            -Title "CSP present but missing required directives" `
            -Detail ($cspFails -join " | ") -Evidence $cspRaw `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } elseif ($cspWarns.Count -gt 0) {
        Emit (New-Finding -Id "CSP-Policy-$urlId" -Asvs "V3.4.3" -Owasp "A05" -Status WARN `
            -Title "CSP meets minimum requirements with warnings" `
            -Detail ($cspWarns -join " | ") -Evidence $cspRaw `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "CSP-Policy-$urlId" -Asvs "V3.4.3" -Owasp "A05" -Status PASS `
            -Title "CSP contains required directives (object-src none, base-uri none, no unsafe-inline/eval)" `
            -Detail $cspRaw -Evidence $cspRaw `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    }

    # V3.4.6: frame-ancestors
    $frameAncestors = $csp["frame-ancestors"] ?? ""
    if (-not $frameAncestors) {
        Emit (New-Finding -Id "CSP-FrameAncestors-$urlId" -Asvs "V3.4.6" -Owasp "A05" -Status FAIL `
            -Title "CSP frame-ancestors directive missing" `
            -Detail "Add: frame-ancestors 'none' or frame-ancestors 'self'" `
            -Evidence "(directive absent)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } elseif ($frameAncestors -eq "*" -or $frameAncestors -match "^https?://") {
        Emit (New-Finding -Id "CSP-FrameAncestors-$urlId" -Asvs "V3.4.6" -Owasp "A05" -Status WARN `
            -Title "CSP frame-ancestors allows framing by external origins" `
            -Detail "frame-ancestors $frameAncestors" -Evidence "frame-ancestors $frameAncestors" `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "CSP-FrameAncestors-$urlId" -Asvs "V3.4.6" -Owasp "A05" -Status PASS `
            -Title "CSP frame-ancestors restricts framing" `
            -Detail "frame-ancestors $frameAncestors" -Evidence "frame-ancestors $frameAncestors" `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    }
}

# ─── V3.4.4: X-Content-Type-Options ──────────────────────────────────────────
$xcto = $h["x-content-type-options"] ?? ""
if ($xcto.Trim().ToLower() -eq "nosniff") {
    Emit (New-Finding -Id "XCTO-$urlId" -Asvs "V3.4.4" -Owasp "A05" -Status PASS `
        -Title "X-Content-Type-Options: nosniff" -Evidence $xcto `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} elseif (-not $xcto) {
    Emit (New-Finding -Id "XCTO-$urlId" -Asvs "V3.4.4" -Owasp "A05" -Status FAIL `
        -Title "X-Content-Type-Options header absent" `
        -Detail "Add: X-Content-Type-Options: nosniff" -Evidence "(missing)" `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "XCTO-$urlId" -Asvs "V3.4.4" -Owasp "A05" -Status FAIL `
        -Title "X-Content-Type-Options has invalid value" `
        -Detail "Expected 'nosniff'; got '$xcto'" -Evidence $xcto `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

# ─── V3.4.5: Referrer-Policy ─────────────────────────────────────────────────
$rp = $h["referrer-policy"] ?? ""
$safeReferrerValues = @(
    "no-referrer",
    "no-referrer-when-downgrade",
    "same-origin",
    "strict-origin",
    "strict-origin-when-cross-origin"
)
if (-not $rp) {
    Emit (New-Finding -Id "ReferrerPolicy-$urlId" -Asvs "V3.4.5" -Owasp "A05" -Status FAIL `
        -Title "Referrer-Policy header absent" `
        -Detail "Add: Referrer-Policy: strict-origin-when-cross-origin" `
        -Evidence "(missing)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} elseif ($rp.ToLower() -in $safeReferrerValues) {
    Emit (New-Finding -Id "ReferrerPolicy-$urlId" -Asvs "V3.4.5" -Owasp "A05" -Status PASS `
        -Title "Referrer-Policy is a safe value" `
        -Detail $rp -Evidence $rp -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "ReferrerPolicy-$urlId" -Asvs "V3.4.5" -Owasp "A05" -Status WARN `
        -Title "Referrer-Policy value may leak referrer information" `
        -Detail "Value: '$rp' — consider strict-origin-when-cross-origin" -Evidence $rp `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

# ─── V3.4.8: Cross-Origin-Opener-Policy ──────────────────────────────────────
$coop = $h["cross-origin-opener-policy"] ?? ""
$safeCoopValues = @("same-origin", "same-origin-allow-popups")
if (-not $coop) {
    Emit (New-Finding -Id "COOP-$urlId" -Asvs "V3.4.8" -Owasp "A05" -Status WARN `
        -Title "Cross-Origin-Opener-Policy header absent (L3 requirement)" `
        -Detail "Add: Cross-Origin-Opener-Policy: same-origin" `
        -Evidence "(missing)" -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} elseif ($coop.ToLower() -in $safeCoopValues) {
    Emit (New-Finding -Id "COOP-$urlId" -Asvs "V3.4.8" -Owasp "A05" -Status PASS `
        -Title "Cross-Origin-Opener-Policy is set" `
        -Detail $coop -Evidence $coop -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "COOP-$urlId" -Asvs "V3.4.8" -Owasp "A05" -Status WARN `
        -Title "Cross-Origin-Opener-Policy has unexpected value" `
        -Detail "Value: '$coop'" -Evidence $coop -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.4.6: Server / X-Powered-By information leakage ──────────────────────
$serverHdr  = $h["server"]       ?? ""
$xpb        = $h["x-powered-by"] ?? ""
$aspVersion = $h["x-aspnet-version"] ?? $h["x-aspnetmvc-version"] ?? ""

if ($serverHdr -match "\d+\.\d+" -or $serverHdr -match "(Apache|nginx|IIS|Kestrel|Microsoft)[/ ][\d.]") {
    Emit (New-Finding -Id "ServerHeader-$urlId" -Asvs "V13.4.6" -Owasp "A05" -Status FAIL `
        -Title "Server header exposes version information" `
        -Detail "Value: '$serverHdr'" -Evidence $serverHdr `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
} elseif ($serverHdr) {
    Emit (New-Finding -Id "ServerHeader-$urlId" -Asvs "V13.4.6" -Owasp "A05" -Status INFO `
        -Title "Server header present (no version detected)" `
        -Detail "Value: '$serverHdr'" -Evidence $serverHdr `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}
if ($xpb) {
    Emit (New-Finding -Id "XPoweredBy-$urlId" -Asvs "V13.4.6" -Owasp "A05" -Status FAIL `
        -Title "X-Powered-By header present (technology disclosure)" `
        -Detail "Value: '$xpb'" -Evidence $xpb `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}
if ($aspVersion) {
    Emit (New-Finding -Id "AspVersion-$urlId" -Asvs "V13.4.6" -Owasp "A05" -Status FAIL `
        -Title "ASP.NET version header present" `
        -Detail "Value: '$aspVersion'" -Evidence $aspVersion `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

# ─── V13.4.4: HTTP TRACE method ──────────────────────────────────────────────
try {
    $traceParams = @{
        Uri                = $BaseUrl
        Method             = "TRACE"
        TimeoutSec         = 10
        SkipHttpErrorCheck = $true
        ErrorAction        = "Stop"
        MaximumRedirection = 0
    }
    if ($SkipCertificateCheck) { $traceParams.SkipCertificateCheck = $true }
    $traceResp = Invoke-WebRequest @traceParams
    if ([int]$traceResp.StatusCode -in @(200, 201, 204)) {
        Emit (New-Finding -Id "Trace-$urlId" -Asvs "V13.4.4" -Owasp "A05" -Status FAIL `
            -Title "HTTP TRACE method accepted (status $($traceResp.StatusCode))" `
            -Detail "Server returned 2xx to TRACE request — should return 405 Method Not Allowed" `
            -Evidence "HTTP TRACE -> $($traceResp.StatusCode)" `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "Trace-$urlId" -Asvs "V13.4.4" -Owasp "A05" -Status PASS `
            -Title "HTTP TRACE method rejected (status $($traceResp.StatusCode))" `
            -Evidence "HTTP TRACE -> $($traceResp.StatusCode)" `
            -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
    }
} catch {
    Emit (New-Finding -Id "Trace-$urlId" -Asvs "V13.4.4" -Owasp "A05" -Status UNABLE `
        -Title "Could not test HTTP TRACE method" -Detail $_.Exception.Message -Evidence "" `
        -AppId $BaseUrl -AppEnv $Environment -AppUnit $Unit)
}

return @($Findings)
