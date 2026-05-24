#Requires -Version 7.0
<#
.SYNOPSIS
    Writes the Entra ID audit JSON + Markdown reports consumed by sec-docs.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Aggregates findings produced by Test-EntraIDAppRegistration.ps1 and
    Test-EntraIDTenantPolicies.ps1 and persists them in a stable schema.

    Output files in $OutputDir:
      entraid-audit-latest.json   — schema consumed by sec-docs (stable)
      entraid-audit-latest.md     — human-readable summary
      entraid-audit-{ts}.json     — timestamped copy for history
      entraid-audit-{ts}.md       — timestamped copy for history

.PARAMETER Findings
    Array of finding hashtables (see New-Finding in EntraIDAudit.Utils.psm1).

.PARAMETER Applications
    Array of hashtables describing the audited apps:
        @{ Unit; Environment; ClientId; DisplayName }

.PARAMETER TenantId
    Tenant GUID this audit targeted.

.PARAMETER OutputDir
    Directory to write reports into. Created if absent.

.PARAMETER ScannedRoots
    Repository paths that were scanned (for the run-info section).
#>
[CmdletBinding()]
param(
    [hashtable[]]$Findings    = @(),
    [hashtable[]]$Applications = @(),
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$OutputDir,
    [string[]]$ScannedRoots = @()
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp  = (Get-Date -Format "yyyy-MM-dd_HHmm")
$jsonPath   = Join-Path $OutputDir "entraid-audit-$timestamp.json"
$mdPath     = Join-Path $OutputDir "entraid-audit-$timestamp.md"
$latestJson = Join-Path $OutputDir "entraid-audit-latest.json"
$latestMd   = Join-Path $OutputDir "entraid-audit-latest.md"

$safeFindings = @($Findings | Where-Object { $_ -is [hashtable] })

$passCount   = @($safeFindings | Where-Object { $_.Status -eq "PASS"   }).Count
$failCount   = @($safeFindings | Where-Object { $_.Status -eq "FAIL"   }).Count
$warnCount   = @($safeFindings | Where-Object { $_.Status -eq "WARN"   }).Count
$unableCount = @($safeFindings | Where-Object { $_.Status -eq "UNABLE" }).Count

$asvsMapping = @(
    $safeFindings | Group-Object { $_.Asvs } | ForEach-Object {
        $statuses = @($_.Group | ForEach-Object { $_.Status })
        $worst = if ($statuses -contains "FAIL")   { "FAIL"   }
                 elseif ($statuses -contains "WARN")   { "WARN"   }
                 elseif ($statuses -contains "PASS")   { "PASS"   }
                 elseif ($statuses -contains "UNABLE") { "UNABLE" }
                 else                                  { "INFO"   }
        @{
            asvs          = $_.Name
            overallStatus = $worst
            findingIds    = @($_.Group | ForEach-Object { $_.Id })
        }
    }
)

$jsonReport = [ordered]@{
    auditDate    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    tenantId     = $TenantId
    scannedRoots = $ScannedRoots
    applications = $Applications
    findings     = $safeFindings
    summary      = @{
        pass   = $passCount
        fail   = $failCount
        warn   = $warnCount
        unable = $unableCount
        total  = $safeFindings.Count
    }
    asvsMapping  = $asvsMapping
}

$jsonReport | ConvertTo-Json -Depth 20 | Out-File -FilePath $jsonPath -Encoding utf8
Copy-Item $jsonPath $latestJson -Force
Write-Host "  JSON     -> $jsonPath" -ForegroundColor Gray
Write-Host "  Latest   -> $latestJson" -ForegroundColor Gray

# ─── Markdown report ──────────────────────────────────────────────────────
$appsDisplay = if (@($Applications).Count -gt 0) {
    (@($Applications) | ForEach-Object {
        $unitLabel = if ($_.Unit) { "$($_.Unit) / " } else { "" }
        $envLabel  = if ($_.Environment) { $_.Environment } else { "Unknown" }
        $nameSfx   = if ($_.DisplayName) { " ($($_.DisplayName))" } else { "" }
        "- **$unitLabel$envLabel**: ``$($_.ClientId)``$nameSfx"
    }) -join "`n"
} else {
    "_No app registrations configured_"
}

$rootsDisplay = if (@($ScannedRoots).Count -gt 0) { ($ScannedRoots -join ', ') } else { "(none)" }

$md = @"
# Entra ID ASVS Audit

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm") UTC
**Tenant:** $TenantId
**Scanned Repos:** $rootsDisplay

## App Registrations Audited

$appsDisplay

## Summary

| Status | Count |
|--------|-------|
| PASS   | $passCount |
| FAIL   | $failCount |
| WARN   | $warnCount |
| UNABLE | $unableCount |

## Findings

| ID | Unit | Env | ASVS | OWASP | Status | Title | Evidence |
|----|------|-----|------|-------|--------|-------|----------|
"@

foreach ($f in $safeFindings) {
    $unit     = if ($f.AppUnit)  { $f.AppUnit }  else { "" }
    $envCol   = if ($f.AppEnv)   { $f.AppEnv }   else { "" }
    $evidence = if ($f.Evidence) { $f.Evidence } else { "" }
    $owasp    = if ($f.Owasp)    { $f.Owasp }    else { "" }
    $md += "`n| $($f.Id) | $unit | $envCol | $($f.Asvs) | $owasp | $($f.Status) | $($f.Title) | ``$evidence`` |"
}

$md += @"


## ASVS Requirement Summary

| ASVS | Status |
|------|--------|
"@
foreach ($row in (@($asvsMapping) | Sort-Object { $_.asvs })) {
    $md += "`n| $($row.asvs) | $($row.overallStatus) |"
}

$md | Out-File -FilePath $mdPath -Encoding utf8
Copy-Item $mdPath $latestMd -Force
Write-Host "  Markdown -> $mdPath" -ForegroundColor Gray

Write-Host "`n  PASS   : $passCount" -ForegroundColor Green
Write-Host "  FAIL   : $failCount" -ForegroundColor Red
Write-Host "  WARN   : $warnCount" -ForegroundColor Yellow
Write-Host "  UNABLE : $unableCount" -ForegroundColor Cyan
