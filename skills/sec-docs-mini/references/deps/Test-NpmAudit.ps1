#Requires -Version 7.0
<#
.SYNOPSIS
    Audits an npm workspace for vulnerable packages using npm audit.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Calls `npm audit --json` in the workspace directory and returns finding hashtables.
    Writes no files — aggregation is the caller's job.

    Checks performed:
      V15.2.1 — No components with known vulnerabilities (OWASP A06)
                critical/high severity → FAIL
                moderate severity      → WARN
                low/info severity      → INFO
                No vulnerabilities     → PASS

    NOTE: npm audit exits non-zero when vulnerabilities exist. This is expected
    and does not indicate a script error — output is captured and parsed regardless.

.PARAMETER WorkspacePath
    Absolute path to the directory containing package.json.

.PARAMETER Unit
    Deployable unit name (e.g. app, web).

.OUTPUTS
    System.Collections.Hashtable[] — one finding per vulnerable package (or one clean finding).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspacePath,
    [string]$Unit = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "DependencyAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

$unitSlug = ConvertTo-Slug (if ($Unit) { $Unit } else { Split-Path -Leaf $WorkspacePath })
$label    = if ($Unit) { $Unit } else { Split-Path -Leaf $WorkspacePath }

# ─── Prerequisite checks ──────────────────────────────────────────────────────
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Emit (New-Finding -Id "DEP-Npm-$unitSlug-Tool" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "npm not found — cannot scan npm packages in $label" `
        -AppId $WorkspacePath -AppUnit $Unit)
    return @($Findings)
}

if (-not (Test-Path (Join-Path $WorkspacePath "package.json"))) {
    Emit (New-Finding -Id "DEP-Npm-$unitSlug-NoPackage" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "No package.json at $WorkspacePath — cannot run npm audit for $label" `
        -AppId $WorkspacePath -AppUnit $Unit)
    return @($Findings)
}

# ─── Run npm audit --json ─────────────────────────────────────────────────────
Write-Host "  Running: npm audit --json ($label)" -ForegroundColor DarkGray
Push-Location $WorkspacePath
try {
    # Capture both stdout and stderr; npm exits 1 when vulns exist — that is expected
    $rawLines = & npm audit --json 2>&1
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

# ─── Parse JSON ───────────────────────────────────────────────────────────────
$jsonText = ($rawLines | Where-Object { $_ -is [string] }) -join ""
try {
    $auditResult = $jsonText | ConvertFrom-Json -ErrorAction Stop
} catch {
    Emit (New-Finding -Id "DEP-Npm-$unitSlug-ParseError" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "Failed to parse npm audit output for $label" `
        -Detail $_.Exception.Message `
        -AppId $WorkspacePath -AppUnit $Unit)
    return @($Findings)
}

# ─── npm audit v2 format (npm >= 7) ──────────────────────────────────────────
$vulnMap = $auditResult.vulnerabilities
if ($vulnMap) {
    $vulnNames = @($vulnMap.PSObject.Properties.Name)

    if ($vulnNames.Count -eq 0) {
        Emit (New-Finding -Id "DEP-Npm-$unitSlug-Clean" -Asvs "V15.2.1" -Owasp "A06" -Status PASS `
            -Title "No vulnerable npm packages found in $label" `
            -Evidence "npm audit: clean" `
            -AppId $WorkspacePath -AppUnit $Unit)
        return @($Findings)
    }

    foreach ($pkgName in $vulnNames) {
        $vuln     = $vulnMap.$pkgName
        $severity = $vuln.severity
        $isDirect = $vuln.isDirect
        $range    = $vuln.range
        $fixAvail = $vuln.fixAvailable

        $pkgSlug     = ConvertTo-Slug $pkgName
        $status      = Get-SeverityStatus $severity
        $directLabel = if ($isDirect) { "direct" } else { "transitive" }
        $fixLabel    = if ($fixAvail -eq $true) { "fix available" } else { "no fix available" }

        Emit (New-Finding -Id "DEP-Npm-$unitSlug-$pkgSlug" -Asvs "V15.2.1" -Owasp "A06" -Status $status `
            -Title "Vulnerable npm package: $pkgName ($severity, $directLabel) in $label" `
            -Detail "Range: $range | $fixLabel" `
            -Evidence "$pkgName ($severity)" `
            -AppId $WorkspacePath -AppUnit $Unit)
    }

    return @($Findings)
}

# ─── npm audit v1 format (npm < 7) ───────────────────────────────────────────
$advisories = $auditResult.advisories
if ($advisories) {
    $advisoryIds = @($advisories.PSObject.Properties.Name)

    if ($advisoryIds.Count -eq 0) {
        Emit (New-Finding -Id "DEP-Npm-$unitSlug-Clean" -Asvs "V15.2.1" -Owasp "A06" -Status PASS `
            -Title "No vulnerable npm packages found in $label" `
            -Evidence "npm audit: clean" `
            -AppId $WorkspacePath -AppUnit $Unit)
        return @($Findings)
    }

    foreach ($id in $advisoryIds) {
        $adv      = $advisories.$id
        $pkgName  = $adv.module_name
        $severity = $adv.severity
        $title    = $adv.title
        $url      = $adv.url

        $pkgSlug = ConvertTo-Slug $pkgName
        $status  = Get-SeverityStatus $severity

        Emit (New-Finding -Id "DEP-Npm-$unitSlug-$pkgSlug-$id" -Asvs "V15.2.1" -Owasp "A06" -Status $status `
            -Title "Vulnerable npm package: $pkgName ($severity) in $label — $title" `
            -Detail "Advisory: $url" `
            -Evidence "$pkgName ($severity)" `
            -AppId $WorkspacePath -AppUnit $Unit)
    }

    return @($Findings)
}

# ─── Unknown format ───────────────────────────────────────────────────────────
Emit (New-Finding -Id "DEP-Npm-$unitSlug-UnknownFormat" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
    -Title "npm audit output format not recognised for $label — review manually" `
    -Detail "npm exit code: $exitCode" `
    -AppId $WorkspacePath -AppUnit $Unit)

return @($Findings)
