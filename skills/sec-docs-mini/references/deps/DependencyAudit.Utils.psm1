#Requires -Version 7.0
<#
.SYNOPSIS
    Shared utilities for the dependency vulnerability audit scripts.

.DESCRIPTION
    IMMUTABLE — part of the sec-docs skill definition.
    Provides New-Finding, ConvertTo-Slug, and Get-SeverityStatus helpers used by
    Test-DotnetVulnerabilities.ps1 and Test-NpmAudit.ps1.
#>

function New-Finding {
    param(
        [string]$Id,
        [string]$Asvs,
        [string]$Owasp,
        [ValidateSet("PASS","FAIL","WARN","INFO","UNABLE")][string]$Status,
        [string]$Title,
        [string]$Detail   = "",
        [string]$Evidence = "",
        [string]$AppId    = "",
        [string]$AppUnit  = ""
    )
    return @{
        Id       = $Id
        Asvs     = $Asvs
        Owasp    = $Owasp
        Status   = $Status
        Title    = $Title
        Detail   = $Detail
        Evidence = $Evidence
        AppId    = $AppId
        AppEnv   = ""
        AppUnit  = $AppUnit
    }
}

function ConvertTo-Slug {
    param([string]$Value)
    return ($Value -replace '[^a-zA-Z0-9]', '-') -replace '-{2,}', '-'
}

function Get-SeverityStatus {
    param([string]$Severity)
    switch ($Severity.ToLower()) {
        "critical" { return "FAIL" }
        "high"     { return "FAIL" }
        "moderate" { return "WARN" }
        "medium"   { return "WARN" }
        "low"      { return "INFO" }
        "info"     { return "INFO" }
        default    { return "WARN" }
    }
}

Export-ModuleMember -Function New-Finding, ConvertTo-Slug, Get-SeverityStatus
