#Requires -Version 7.0
<#
.SYNOPSIS
    Audits a .NET solution for vulnerable packages using dotnet list package --vulnerable.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Calls `dotnet list package --vulnerable --include-transitive` on one .sln/.slnx file
    and returns finding hashtables. Writes no files — aggregation is the caller's job.

    Checks performed:
      V15.2.1 — No components with known vulnerabilities (OWASP A06)
                Critical/High severity → FAIL
                Moderate severity      → WARN
                Low/Info severity      → INFO
                No vulnerabilities     → PASS

.PARAMETER SolutionPath
    Absolute path to a .sln or .slnx file (or directory containing one).

.PARAMETER Unit
    Deployable unit name (e.g. api, integration).

.OUTPUTS
    System.Collections.Hashtable[] — one finding per package (plus one clean finding if none).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SolutionPath,
    [string]$Unit = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $ScriptDir "DependencyAudit.Utils.psm1") -Force

$Findings = [System.Collections.Generic.List[hashtable]]::new()
function Emit { param([hashtable]$F); [void]$Findings.Add($F) }

$unitSlug = ConvertTo-Slug (if ($Unit) { $Unit } else { Split-Path -Leaf $SolutionPath })
$label    = if ($Unit) { $Unit } else { Split-Path -Leaf $SolutionPath }

# ─── Prerequisite check ───────────────────────────────────────────────────────
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Emit (New-Finding -Id "DEP-Dotnet-$unitSlug-Tool" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "dotnet CLI not found — cannot scan .NET packages in $label" `
        -AppId $SolutionPath -AppUnit $Unit)
    return @($Findings)
}

if (-not (Test-Path $SolutionPath)) {
    Emit (New-Finding -Id "DEP-Dotnet-$unitSlug-NotFound" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "Solution path not found: $SolutionPath" `
        -AppId $SolutionPath -AppUnit $Unit)
    return @($Findings)
}

# ─── Run dotnet list package --vulnerable ─────────────────────────────────────
Write-Host "  Running: dotnet list package --vulnerable ($label)" -ForegroundColor DarkGray
try {
    $output = & dotnet list $SolutionPath package --vulnerable --include-transitive 2>&1
} catch {
    Emit (New-Finding -Id "DEP-Dotnet-$unitSlug-Error" -Asvs "V15.2.1" -Owasp "A06" -Status UNABLE `
        -Title "dotnet list package failed for $label" `
        -Detail $_.Exception.Message `
        -AppId $SolutionPath -AppUnit $Unit)
    return @($Findings)
}

# ─── Parse vulnerable package lines ──────────────────────────────────────────
# dotnet output format:  "> PackageName   Requested   Resolved   Severity   AdvisoryUrl"
$vulnLines = @($output | Where-Object { $_ -match '^\s*>\s+\S' })

if ($vulnLines.Count -eq 0) {
    Emit (New-Finding -Id "DEP-Dotnet-$unitSlug-Clean" -Asvs "V15.2.1" -Owasp "A06" -Status PASS `
        -Title "No vulnerable .NET packages found in $label" `
        -Evidence "dotnet list package --vulnerable --include-transitive: clean" `
        -AppId $SolutionPath -AppUnit $Unit)
    return @($Findings)
}

# Track emitted IDs to deduplicate transitive packages reported multiple times
$emitted = @{}

foreach ($line in $vulnLines) {
    $trimmed = $line -replace '^\s*>\s+', ''
    # Split on 2+ whitespace to handle variable-width columns
    $parts = @($trimmed -split '\s{2,}' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    if ($parts.Count -lt 3) { continue }

    $pkgName     = $parts[0]
    $requested   = if ($parts.Count -ge 2) { $parts[1] } else { "?" }
    $resolved    = if ($parts.Count -ge 3) { $parts[2] } else { "?" }
    $severity    = if ($parts.Count -ge 4) { $parts[3] } else { "Unknown" }
    $advisoryUrl = if ($parts.Count -ge 5) { $parts[4] } else { "" }

    $pkgSlug = ConvertTo-Slug $pkgName
    $findId  = "DEP-Dotnet-$unitSlug-$pkgSlug"

    # Deduplicate: same package may appear for multiple target frameworks
    if ($emitted.ContainsKey($findId)) { continue }
    $emitted[$findId] = $true

    $status  = Get-SeverityStatus $severity
    $detail  = "Requested: $requested | Resolved: $resolved | Severity: $severity"
    if ($advisoryUrl) { $detail += " | Advisory: $advisoryUrl" }

    Emit (New-Finding -Id $findId -Asvs "V15.2.1" -Owasp "A06" -Status $status `
        -Title "Vulnerable .NET package: $pkgName $resolved ($severity) in $label" `
        -Detail $detail `
        -Evidence "$pkgName@$resolved ($severity)" `
        -AppId $SolutionPath -AppUnit $Unit)
}

return @($Findings)
