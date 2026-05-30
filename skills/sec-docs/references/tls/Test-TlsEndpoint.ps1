#Requires -Version 7.0
<#
.SYNOPSIS
    Audits TLS configuration for a single hostname:port against ASVS controls.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Performs a TLS handshake to one endpoint and returns finding hashtables.
    Writes no files. Aggregation/persistence is the caller's job.

    Checks performed:
      V12.1.1 — TLS 1.2 and/or 1.3 negotiated (not older protocols)
      V12.1.2 — Cipher suite provides forward secrecy; no known-weak ciphers
      V12.2.1 — TLS connection succeeds (endpoint is reachable over TLS)
      V12.2.2 — Certificate is publicly trusted (valid chain)
      V11.2.3 — Certificate public key meets 128-bit security threshold
                RSA: >= 3072 bits (PASS), 2048-3071 (WARN), < 2048 (FAIL)
                EC:  >= 256 bits (PASS), < 256 (FAIL)

    NOTE: Testing whether a server *accepts* TLS 1.0/1.1 requires forcing those
    protocol versions at the .NET layer, which is disabled by OS policy on
    modern Windows/Linux. This script verifies what a current client negotiates,
    not the server's minimum version. Use testssl.sh for full downgrade testing.

.PARAMETER Hostname
    The DNS hostname to test (e.g. api.example.com).

.PARAMETER Port
    TCP port to connect to. Defaults to 443.

.PARAMETER Unit
    Deployable unit name (e.g. api, web). Optional.

.PARAMETER Environment
    Environment label (e.g. Dev, QA, Prod). Defaults to "Unknown".

.OUTPUTS
    System.Collections.Hashtable[] — one finding per check.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Hostname,
    [int]$Port        = 443,
    [string]$Unit     = "",
    [string]$Environment = "Unknown"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "TlsAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

$epId  = "$Hostname-$Port" -replace "[^a-zA-Z0-9]", "-"
$label = "$Hostname`:$Port"

# ─── TLS handshake ────────────────────────────────────────────────────────────
Write-Host "  Connecting to $label..." -ForegroundColor DarkGray
$tls = Invoke-TlsHandshake -Hostname $Hostname -Port $Port

if (-not $tls.Success) {
    Emit (New-Finding -Id "TLS-Connect-$epId" -Asvs "V12.2.1" -Owasp "A05" -Status UNABLE `
        -Title "TLS connection to $label failed" `
        -Detail $tls.Error -Evidence $tls.Error `
        -AppId $label -AppEnv $Environment -AppUnit $Unit)
    return @($Findings)
}

# ─── V12.2.1: TLS connectivity ────────────────────────────────────────────────
Emit (New-Finding -Id "TLS-Connect-$epId" -Asvs "V12.2.1" -Owasp "A05" -Status PASS `
    -Title "TLS connection successful to $label" `
    -Detail "Protocol: $($tls.Protocol)" -Evidence $tls.Protocol `
    -AppId $label -AppEnv $Environment -AppUnit $Unit)

# ─── V12.1.1: Protocol version ────────────────────────────────────────────────
$acceptedProtocols = @("Tls12", "Tls13")
$legacyProtocols   = @("Ssl2", "Ssl3", "Tls", "Tls11", "Default")

if ($tls.Protocol -in $acceptedProtocols) {
    Emit (New-Finding -Id "TLS-Protocol-$epId" -Asvs "V12.1.1" -Owasp "A02" -Status PASS `
        -Title "Negotiated protocol is TLS 1.2 or 1.3: $($tls.Protocol)" `
        -Evidence $tls.Protocol -AppId $label -AppEnv $Environment -AppUnit $Unit)
} elseif ($tls.Protocol -in $legacyProtocols) {
    Emit (New-Finding -Id "TLS-Protocol-$epId" -Asvs "V12.1.1" -Owasp "A02" -Status FAIL `
        -Title "Negotiated a legacy/insecure TLS protocol: $($tls.Protocol)" `
        -Detail "Expected TLS 1.2 or TLS 1.3" -Evidence $tls.Protocol `
        -AppId $label -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "TLS-Protocol-$epId" -Asvs "V12.1.1" -Owasp "A02" -Status WARN `
        -Title "Unexpected TLS protocol value: $($tls.Protocol)" `
        -Evidence $tls.Protocol -AppId $label -AppEnv $Environment -AppUnit $Unit)
}

# ─── V12.1.2: Cipher suite — forward secrecy and weak-cipher detection ────────
$suite = $tls.NegotiatedSuite
$algo  = $tls.CipherAlgorithm
$kex   = $tls.KeyExchangeAlgorithm
$bits  = $tls.CipherStrength

# Weak symmetric ciphers
$weakCiphers = @("Null", "Des", "TripleDes", "Rc2", "Rc4")
$isWeakCipher = $algo -in $weakCiphers -or $suite -match "(RC4|3DES|DES_CBC|NULL|EXPORT)"

# Forward secrecy: ECDHE or DHE key exchange
$hasPfs = ($kex -match "(?i)(DiffieHellman|ECDiffieHellman|ECDH)") -or
          ($suite -match "(?i)(ECDHE|DHE|_ECDH_)")

if ($isWeakCipher) {
    Emit (New-Finding -Id "TLS-Cipher-Weak-$epId" -Asvs "V12.1.2" -Owasp "A02" -Status FAIL `
        -Title "Weak cipher algorithm negotiated" `
        -Detail "Algorithm: $algo | Suite: $suite | Strength: $bits bits" `
        -Evidence "$algo / $suite" -AppId $label -AppEnv $Environment -AppUnit $Unit)
} elseif (-not $hasPfs) {
    Emit (New-Finding -Id "TLS-Cipher-PFS-$epId" -Asvs "V12.1.2" -Owasp "A02" -Status WARN `
        -Title "Cipher suite does not provide Forward Secrecy (no ECDHE/DHE)" `
        -Detail "Suite: $suite | KEX: $kex" -Evidence "$suite" `
        -AppId $label -AppEnv $Environment -AppUnit $Unit)
} else {
    Emit (New-Finding -Id "TLS-Cipher-$epId" -Asvs "V12.1.2" -Owasp "A02" -Status PASS `
        -Title "Cipher suite is strong and provides Forward Secrecy" `
        -Detail "Suite: $suite | KEX: $kex | Strength: $bits bits" `
        -Evidence "$suite" -AppId $label -AppEnv $Environment -AppUnit $Unit)
}

# ─── V12.2.2: Certificate trust chain ─────────────────────────────────────────
if ($tls.IsChainTrusted) {
    Emit (New-Finding -Id "TLS-CertTrust-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status PASS `
        -Title "Certificate is publicly trusted (chain valid)" `
        -Detail "Subject: $($tls.CertSubject)" -Evidence $tls.CertSubject `
        -AppId $label -AppEnv $Environment -AppUnit $Unit)
} else {
    $chainDetail = ($tls.ChainStatusMessages -join " | ")
    if ($chainDetail -match "(?i)(NameMismatch|name does not match)") {
        Emit (New-Finding -Id "TLS-CertHostname-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status FAIL `
            -Title "Certificate hostname does not match $Hostname" `
            -Detail "Subject: $($tls.CertSubject) | SANs: $($tls.CertSanNames -join ', ')" `
            -Evidence "SslPolicyErrors: $($tls.SslPolicyErrors)" `
            -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "TLS-CertTrust-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status FAIL `
            -Title "Certificate chain is not trusted" `
            -Detail "Errors: $chainDetail" `
            -Evidence "SslPolicyErrors: $($tls.SslPolicyErrors)" `
            -AppId $label -AppEnv $Environment -AppUnit $Unit)
    }
}

# ─── V12.2.2: Certificate expiry ──────────────────────────────────────────────
if ($tls.CertNotAfter) {
    $now      = [datetime]::UtcNow
    $notAfter = $tls.CertNotAfter.ToUniversalTime()
    $daysLeft = [math]::Round(($notAfter - $now).TotalDays)

    if ($notAfter -lt $now) {
        Emit (New-Finding -Id "TLS-CertExpired-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status FAIL `
            -Title "TLS certificate EXPIRED $([math]::Abs($daysLeft)) day(s) ago" `
            -Detail "NotAfter: $($notAfter.ToString('yyyy-MM-dd'))" `
            -Evidence "expired $([math]::Abs($daysLeft))d ago" `
            -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } elseif ($daysLeft -le 30) {
        Emit (New-Finding -Id "TLS-CertExpiring-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status WARN `
            -Title "TLS certificate expiring in $daysLeft day(s)" `
            -Detail "NotAfter: $($notAfter.ToString('yyyy-MM-dd'))" `
            -Evidence "expires in ${daysLeft}d" `
            -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "TLS-CertExpiry-$epId" -Asvs "V12.2.2" -Owasp "A02" -Status PASS `
            -Title "TLS certificate valid for $daysLeft more day(s)" `
            -Detail "NotAfter: $($notAfter.ToString('yyyy-MM-dd'))" `
            -Evidence "expires in ${daysLeft}d" `
            -AppId $label -AppEnv $Environment -AppUnit $Unit)
    }
}

# ─── V11.2.3: Certificate key size (128-bit security level) ───────────────────
$keyBits = $tls.CertKeyBits
$keyAlgo = $tls.CertKeyAlgorithm

if ($keyBits -eq 0) {
    Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status UNABLE `
        -Title "Certificate public key size could not be determined" `
        -Detail "Algorithm: $keyAlgo" -Evidence "$keyAlgo / unknown bits" `
        -AppId $label -AppEnv $Environment -AppUnit $Unit)
} elseif ($keyAlgo -match "(?i)RSA") {
    if ($keyBits -ge 3072) {
        Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status PASS `
            -Title "RSA certificate key meets 128-bit security level ($keyBits bits >= 3072)" `
            -Evidence "RSA-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } elseif ($keyBits -ge 2048) {
        Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status WARN `
            -Title "RSA certificate key ($keyBits bits) meets legacy NIST SP 800-57 but is below ASVS v5 128-bit security threshold (3072 bits)" `
            -Detail "Plan to reissue with RSA-3072 or migrate to ECDSA P-256+" `
            -Evidence "RSA-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status FAIL `
            -Title "RSA certificate key is too small ($keyBits bits < 2048)" `
            -Evidence "RSA-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
    }
} elseif ($keyAlgo -match "(?i)(EC|ECDSA|elliptic)") {
    if ($keyBits -ge 256) {
        Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status PASS `
            -Title "ECDSA certificate key meets 128-bit security level ($keyBits bits >= 256)" `
            -Evidence "$keyAlgo-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
    } else {
        Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status FAIL `
            -Title "ECDSA certificate key is below 256 bits ($keyBits bits)" `
            -Evidence "$keyAlgo-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
    }
} else {
    Emit (New-Finding -Id "TLS-CertKeySize-$epId" -Asvs "V11.2.3" -Owasp "A02" -Status INFO `
        -Title "Certificate key algorithm: $keyAlgo / $keyBits bits — manual review required" `
        -Evidence "$keyAlgo-$keyBits" -AppId $label -AppEnv $Environment -AppUnit $Unit)
}

return @($Findings)
