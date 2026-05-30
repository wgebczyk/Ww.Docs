# Audit Integration — Shared Rules

Common contract for all five orchestrators (Entra ID, HTTP Headers, TLS, Azure
Resources, Dependencies). Load this file **once per run**, before any per-integration
`audit-integration.md`. Each per-integration file only carries what is specific to
that integration: architecture diagram, discovery sources, manifest keys, and ASVS
category mapping.

## Skill-Owned vs Skill-Managed

| Path | Owner | Writable by skill? |
|---|---|---|
| `references/{integration}/` (utility `.psm1`, `Test-*.ps1`, `Write-*.ps1`, `Invoke-*.template.ps1`) | Skill definition (immutable) | **No** |
| `docs/sec-docs/reports/{integration}/Invoke-*.ps1` | Skill-managed orchestrator (manifest block only) | Yes — edit between markers only |
| `docs/sec-docs/reports/{integration}/{integration}-audit-latest.{json,md}` | Audit script output | Read only; never write |

**CONSTRAINT [HARD-WRITE]:** Never write to anything under `references/{integration}/`.
If a check is missing or wrong, fix the skill definition in a separate change.

## Orchestrator Step — Four Phases

Run this step **once per sec-docs-mini invocation per integration**, before any
ASVS category that consumes that integration's evidence.

### Phase 1 — Discover units

Use the discovery table in the integration's `audit-integration.md` to scan the
current repository (from its root) for the entities the orchestrator must audit
(app registrations / base URLs / hostnames / Key Vaults + App Configs / .NET
solutions + npm workspaces).

Always exclude `node_modules/`, `.git/`, `bin/`, `obj/` from discovery scans.

### Phase 2 — Read existing manifest

If `docs/sec-docs/reports/{integration}/Invoke-*.ps1` exists, locate the block
bounded by:

```
# === MANIFEST BEGIN === (skill-managed; do not hand-edit between these markers)
...
# === MANIFEST END ===
```

Parse the entries (key names listed in the integration's doc). This is the
"previous" manifest.

### Phase 3 — Generate or edit the orchestrator

| State | Action |
|---|---|
| Orchestrator file does not exist | Copy `references/{integration}/Invoke-*.template.ps1` to `docs/sec-docs/reports/{integration}/Invoke-*.ps1`, then replace the manifest block with the discovered manifest. |
| Orchestrator exists; discovered manifest matches the previous | Do nothing. |
| Orchestrator exists; manifests differ | Use `Edit` to replace **only** the lines between the BEGIN / END markers. Touch nothing else. |
| Orchestrator exists; content outside the markers was hand-modified | Stop. Report exactly what diverged. Do not silently overwrite. |

**Manifest formatting** (whitespace-sensitive — required for predictable Edits):
- One hashtable per line.
- Two-space indentation inside the array. No trailing comma after the last entry.
- Keys in the exact order listed in the integration's doc.
- Sort entries by their declared sort key (typically `Unit`, then `Environment`, then identifier).
- Always emit every key — use `""` or `"Unknown"` rather than omitting.

### Phase 4 — Run or load the audit

In a **pipeline run**, the pipeline executes the orchestrator before the skill;
the JSON will already exist.

In an **interactive run**:
- If `docs/sec-docs/reports/{integration}/{integration}-audit-latest.json` exists
  and its modification time is within 7 days of the repo's HEAD commit timestamp
  (i.e., not stale by more than a week), read it directly.
- Otherwise instruct the user to run the orchestrator (see the integration's doc
  for the exact command line).
- If the user declines, mark every ASVS requirement listed in the integration's
  ASVS Category Mapping as `NOT-ASSESSED` and note the reason on each affected
  category page.

## JSON Schema

All five audits write the same top-level shape:

```json
{
  "auditDate": "ISO-8601 UTC",
  "applications": [ ... ],          // integration-specific list of audited units
  "findings": [
    { "Id": "...", "Asvs": "V#.#.#", "Owasp": "A##",
      "Status": "PASS|FAIL|WARN|UNABLE|INFO",
      "Title": "...", "Detail": "...", "Evidence": "...",
      ...                            // integration-specific fields (AppId, AppEnv, AppUnit, etc.)
    }
  ],
  "summary":     { "pass": 0, "fail": 0, "warn": 0, "unable": 0, "total": 0 },
  "asvsMapping": [ { "asvs": "V#.#.#", "overallStatus": "PASS", "findingIds": ["..."] } ]
}
```

Index `findings` by `Asvs` for fast lookup during category assessment.

## Citation Format

When citing audit evidence inside a category page, use this exact form:

```
(source: docs/sec-docs/reports/{integration}/{integration}-audit-latest.md — finding {Id})
```

Include the integration-specific scope (e.g. `AppUnit`/`AppEnv` for Entra ID;
hostname for TLS) so the reader sees which unit produced the evidence.

When the audit JSON and the codebase disagree, prefer the audit result (it is
authoritative for the audited surface) and note the discrepancy.
