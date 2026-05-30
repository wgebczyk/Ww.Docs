# Dependency Vulnerability Audit Integration

Runs `dotnet list package --vulnerable` and `npm audit --json` across all
solution and workspace roots discovered in the single repository.

Load `references/audit-integration-shared.md` for the 4-phase pattern, manifest
rules, JSON schema, citation format, and immutable-scripts constraint.

## Architecture

```
references/deps/                                       ← skill-owned (IMMUTABLE)
├── DependencyAudit.Utils.psm1             # New-Finding, severity helpers
├── Test-DotnetVulnerabilities.ps1         # scan one .NET solution -> finding[]
├── Test-NpmAudit.ps1                      # scan one npm workspace -> finding[]
├── Write-DependencyAuditReport.ps1        # write JSON + Markdown reports
└── Invoke-DependencyAudit.template.ps1    # template for the orchestrator below

docs/sec-docs/reports/deps/                            ← skill-managed (per project)
├── Invoke-DependencyAudit.ps1             # orchestrator — generated + edited by skill
├── deps-audit-latest.{json,md}            # audit output
└── deps-audit-{ts}.{json,md}              # historical copies
```

## Manifest — Two Lists

In single-repo mode `Unit` distinguishes solutions/workspaces inside the same
repository (typically the parent directory name of the solution or workspace
file).

**DotnetSolutions:** `@{ Unit; SolutionPath; DisplayName }`
`SolutionPath` is relative to the repo root (e.g. `src\MyApi\MyApi.slnx`).

**NpmWorkspaces:** `@{ Unit; WorkspacePath; DisplayName }`
`WorkspacePath` is relative to the repo root (e.g. `web`).

## Phase 1 — Discovery

**.NET solutions:** Glob `**/*.sln` and `**/*.slnx` under the repository root.
Exclude `bin/`, `obj/`, `node_modules/`. Derive `Unit` from the parent directory
name (or repo root if the solution sits at the top).

**npm workspaces:** Find directories containing `package.json` at the repository
root or one level below (not nested `node_modules/`). Derive `Unit` from the
directory name.

If no solutions or workspaces are discovered, note "Dependency audit: not
applicable" in the run log and skip the ASVS mapping below.

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\deps\Invoke-DependencyAudit.ps1
```

## ASVS Category Mapping

| ASVS Category | Finding `asvs` values |
|---|---|
| V15 Secure Coding | `V15.2.1` (vulnerable components) |
