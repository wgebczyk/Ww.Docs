# Dependency Vulnerability Audit Integration

Runs `dotnet list package --vulnerable` and `npm audit --json` across all
discovered solution and workspace roots.

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

**DotnetSolutions:** `@{ Unit; SolutionPath; DisplayName }`
`SolutionPath` is relative to the repo root (e.g. `cold-wave-api\ColdWave.Api.slnx`).

**NpmWorkspaces:** `@{ Unit; WorkspacePath; DisplayName }`
`WorkspacePath` is relative to the repo root (e.g. `cold-wave-app`).

## Phase 1 — Discovery

**.NET solutions:** Glob `**/*.sln` and `**/*.slnx` under each sub-repo root.
Exclude `bin/`, `obj/`, `node_modules/`. Derive `Unit` from the sub-repo
directory name.

**npm workspaces:** Find directories containing `package.json` at the sub-repo
root level (not nested `node_modules/`). Derive `Unit` from the directory name.

## Interactive Run Command

```powershell
.\docs\sec-docs\reports\deps\Invoke-DependencyAudit.ps1
```

## ASVS Category Mapping

| ASVS Category | Finding `asvs` values |
|---|---|
| V15 Secure Coding | `V15.2.1` (vulnerable components) |
