#Requires -Version 7.0
<#
.SYNOPSIS
    Writes the dependency vulnerability audit JSON + Markdown reports consumed by sec-docs.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.

    Output files in $OutputDir:
      deps-audit-latest.json   — schema consumed by sec-docs
      deps-audit-latest.md     — human-readable summary
      deps-audit-{ts}.json     — timestamped copy for history
      deps-audit-{ts}.md       — timestamped copy for history

.PARAMETER Findings
    Array of finding hashtables produced by Test-DotnetVulnerabilities.ps1 / Test-NpmAudit.ps1.

.PARAMETER DotnetSolutions
    Array of hashtables describing the .NET solutions scanned.

.PARAMETER NpmWorkspaces
    Array of hashtables describing the npm workspaces scanned.

.PARAMETER OutputDir
    Directory to write reports into. Created if absent.
#>
[CmdletBinding()]
param(
    [hashtable[]]$Findings          = @(),
    [hashtable[]]$DotnetSolutions   = @(),
    [hashtable[]]$NpmWorkspaces     = @(),
    [Parameter(Mandatory)][string]$OutputDir
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp  = (Get-Date -Format "yyyy-MM-dd_HHmm")
$jsonPath   = Join-Path $OutputDir "deps-audit-$timestamp.json"
$mdPath     = Join-Path $OutputDir "deps-audit-$timestamp.md"
$latestJson = Join-Path $OutputDir "deps-audit-latest.json"
$latestMd   = Join-Path $OutputDir "deps-audit-latest.md"

$safeFindings = @($Findings | Where-Object { $_ -is [hashtable] })

$passCount   = @($safeFindings | Where-Object { $_.Status -eq "PASS"   }).Count
$failCount   = @($safeFindings | Where-Object { $_.Status -eq "FAIL"   }).Count
$warnCount   = @($safeFindings | Where-Object { $_.Status -eq "WARN"   }).Count
$infoCount   = @($safeFindings | Where-Object { $_.Status -eq "INFO"   }).Count
$unableCount = @($safeFindings | Where-Object { $_.Status -eq "UNABLE" }).Count

$asvsMapping = @(
    $safeFindings | Group-Object { $_.Asvs } | ForEach-Object {
        $statuses = @($_.Group | ForEach-Object { $_.Status })
        $worst = if     ($statuses -contains "FAIL")   { "FAIL"   }
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
    auditDate       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    targetType      = "deps"
    dotnetSolutions = $DotnetSolutions
    npmWorkspaces   = $NpmWorkspaces
    findings        = $safeFindings
    summary         = @{
        pass   = $passCount
        fail   = $failCount
        warn   = $warnCount
        info   = $infoCount
        unable = $unableCount
        total  = $safeFindings.Count
    }
    asvsMapping = $asvsMapping
}

$jsonReport | ConvertTo-Json -Depth 20 | Out-File -FilePath $jsonPath -Encoding utf8
Copy-Item $jsonPath $latestJson -Force
Write-Host "  JSON     -> $jsonPath"    -ForegroundColor Gray
Write-Host "  Latest   -> $latestJson" -ForegroundColor Gray

# ─── Markdown ─────────────────────────────────────────────────────────────────

$dotnetDisplay = if (@($DotnetSolutions).Count -gt 0) {
    (@($DotnetSolutions) | ForEach-Object {
        $unitLabel = if ($_.Unit) { "$($_.Unit) — " } else { "" }
        "- **$unitLabel``$($_.SolutionPath)``**$(if ($_.DisplayName) { " ($($_.DisplayName))" })"
    }) -join "`n"
} else { "_None_" }

$npmDisplay = if (@($NpmWorkspaces).Count -gt 0) {
    (@($NpmWorkspaces) | ForEach-Object {
        $unitLabel = if ($_.Unit) { "$($_.Unit) — " } else { "" }
        "- **$unitLabel``$($_.WorkspacePath)``**$(if ($_.DisplayName) { " ($($_.DisplayName))" })"
    }) -join "`n"
} else { "_None_" }

$md = @"
# Dependency Vulnerability Audit

**Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm") UTC

## Targets Scanned

### .NET Solutions

$dotnetDisplay

### npm Workspaces

$npmDisplay

## Summary

| Status | Count |
|--------|-------|
| PASS   | $passCount   |
| FAIL   | $failCount   |
| WARN   | $warnCount   |
| INFO   | $infoCount   |
| UNABLE | $unableCount |

## Findings

| ID | Unit | ASVS | OWASP | Status | Title | Evidence |
|----|------|------|-------|--------|-------|----------|
"@

foreach ($f in $safeFindings) {
    $unit     = if ($f.AppUnit)  { $f.AppUnit }  else { "" }
    $evidence = if ($f.Evidence) { $f.Evidence } else { "" }
    $owasp    = if ($f.Owasp)    { $f.Owasp }    else { "" }
    $md += "`n| $($f.Id) | $unit | $($f.Asvs) | $owasp | $($f.Status) | $($f.Title) | ``$evidence`` |"
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

Write-Host "`n  PASS   : $passCount"   -ForegroundColor Green
Write-Host "  FAIL   : $failCount"     -ForegroundColor Red
Write-Host "  WARN   : $warnCount"     -ForegroundColor Yellow
Write-Host "  INFO   : $infoCount"     -ForegroundColor DarkGray
Write-Host "  UNABLE : $unableCount"   -ForegroundColor Cyan
