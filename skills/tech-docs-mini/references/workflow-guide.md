# Workflow Guide

Full procedural workflow for the hybrid knowledge strategy.

**RULE:** Curated docs define intent. Generated docs summarize structure. Source code proves behavior.

**CONSTRAINT [HARD]:** Generated pages are orientation artifacts only. For security, data handling, authorization, financial logic, and other high-risk topics, verify against current source code every run before drawing conclusions.

---

## Part A — Init Mode

Run when `docs/tech-docs/index.md` does not exist, or `--init` is passed.

### Step 1 — Create directory structure

Create these directories if absent:

```text
docs/tech-docs/
docs/tech-docs/curated/
docs/tech-docs/pages/
docs/tech-docs/pages/modules/
docs/tech-docs/pages/design/
docs/tech-docs/reports/
```

`docs/tech-docs/index.md` and `docs/tech-docs/log.md` are files written at the root of the output directory, not subdirectories.

### Step 2 — Discover repositories

Scan workspace root for directories containing `.git/`.

```bash
# PowerShell
Get-ChildItem -Path . -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }

# bash
find . -maxdepth 2 -name ".git" -type d | sed 's|/.git||' | sort
```

Record per repo:

- `Name`
- `Path` (workspace-relative)
- `last-commit-hash` (`cd {repo-path} && git log -1 --format=%H`)

### Step 3 — Read curated docs

Read all `docs/tech-docs/curated/**/*.md`.

For each file:

1. Parse YAML frontmatter where present (`module:` or `topic:` if available).
2. Use curated docs as intent-level context and assumptions.
3. Record which generated pages should reference each curated file.

### Step 4 — Detect technology stack and modules

Use `references/module-heuristics.md`:

1. Step 0 for hypotheses and risk framing.
2. Step 1 for stack detection.
3. Step 2 for module boundary derivation.

Store module records:

- module name and slug
- source repo
- module root path
- likely related curated docs

Required slug format for module pages:

- `{repo-name}-{module-name}` in lowercase kebab-case
- if repo last token equals module first token, remove repeated module token
- example: `crackling-api` + `api-host` => `crackling-api-host`

### Step 5 — Analyze modules and verify code

For each module:

1. Read key files indicated by stack heuristics.
2. Extract components, dependencies, and main flows.
3. Build initial conclusions from narrowed scope.
4. Run expansion checks for hidden paths:
   - alternate routes and entry points
   - DI registration and overrides
   - background jobs and schedulers
   - event handlers and async consumers
   - feature flags and config
   - tests, migrations, legacy scripts
5. Mark known gaps and confidence level.
6. Capture mismatches between curated assumptions and verified code.

### Step 6 — Write module and design pages

Use `references/wiki-page-template.md`.

Write:

- `docs/tech-docs/pages/modules/{repo-module-kebab}.md`
- `docs/tech-docs/pages/design/{kebab-topic}.md`

Rules:

- include required metadata fields
- include citations for substantive claims
- include verification notes and known gaps
- use conflict and note markers when needed

### Step 7 — Write generated index

Write `docs/tech-docs/index.md` with:

- `last-scan`, `repositories[]` with `name`, `path`, `last-commit-hash`
- module and design topic table of contents
- links to report pages

### Step 8 — Write reports

Write or refresh:

- `docs/tech-docs/reports/latest-refresh-summary.md`
- `docs/tech-docs/reports/doc-code-mismatches.md`
- `docs/tech-docs/reports/stale-pages.md`
- `docs/tech-docs/reports/high-risk-changes.md`

Append run entry to:

- `docs/tech-docs/log.md`

### Step 9 — Verify

Run checklist from `SKILL.md` and correct failures before completion.

### Step 10 — Report outcome

Return summary including:

- repositories discovered
- modules created
- design topics created
- curated files referenced
- mismatches found
- known gaps and confidence caveats

---

## Part B — Update Mode

Run when `docs/tech-docs/index.md` exists and `--init` is not passed,
or when `--update` is passed.

The Update workflow is **change-driven**: it starts from the git delta,
maps changes to affected modules, and incrementally updates only impacted
sections of existing pages. Scope extends automatically when changes are
structural, but non-structural changes receive surgical page updates.

### Step 1 — Load prior metadata

Read `docs/tech-docs/index.md` frontmatter:

- previous `last-scan`
- `repositories[].last-commit-hash`

If a tracked repo is missing, warn and skip.
If a new repo appears on disk, treat it as new: run Init steps for that repo and
add it to index metadata.

### Step 2 — Re-read curated docs

Always re-read `docs/tech-docs/curated/**/*.md`, even with no git changes.

### Step 3 — Detect repository deltas

For each tracked repo:

```bash
cd {repo-path} && git log {last-commit-hash}..HEAD --name-only --format=
```

- Empty output: no code delta for that repo.
- If baseline hash is unreachable (rebased history), re-analyze full repo.

### Step 4 — Map changed files to modules

Use module boundary heuristics to map changed files.

If changed files are repo-level config or infra files, assess design topics and
risk reports even if no single module maps directly.

### Step 5 — Classify change impact per module

For each affected module, classify the delta:

| Change type | Classification | Action |
|---|---|---|
| New/removed entry points, controllers, or services | **Structural** | Full module re-read and page rewrite (Step 5a) |
| Changed DI/IoC registrations, module boundaries, or project references | **Structural** | Full module re-read and page rewrite (Step 5a) |
| Renamed module or moved files across boundaries | **Structural** | Full module re-read and page rewrite (Step 5a) |
| Modified implementation within existing components | **Incremental** | Targeted section update (Step 5b) |
| Changed configuration, feature flags, or environment overrides | **Incremental** | Targeted section update (Step 5b) |
| New/modified tests only | **Incremental** | Update verification notes section only |
| Documentation or comment-only changes | **Skip** | No page update needed |

#### Step 5a — Full module re-read (structural changes)

When the change is structural:

1. Re-read full module source.
2. Recompute module slug using required naming and de-duplication.
3. Re-run verification and expansion checks.
4. Rewrite module page completely with updated metadata.
5. Update design pages impacted by this module.

#### Step 5b — Targeted section update (incremental changes)

When the change is non-structural:

1. Read the existing module page from `docs/tech-docs/pages/modules/`.
2. Analyze the changed files to understand what aspect of the module is affected:
   - Changed a data flow → update the "Data Flow" or "Key Flows" section
   - Changed a dependency → update the "Dependencies" section
   - Changed error handling → update the relevant flow section
   - Changed configuration → update the "Configuration" section
3. Re-read only the source files relevant to the affected sections (the
   changed files plus their direct dependents/dependencies).
4. Run expansion checks scoped to the affected area:
   - If the change touches DI → check for override impacts
   - If the change touches an interface → check implementors
   - If the change touches a config value → check consumers
5. Rewrite only the affected sections of the page. Preserve all other
   sections verbatim (same text, same citations).
6. Update page metadata: `generated-on` = now, `generated-from-commit` = HEAD.
7. If expansion checks reveal the change has wider impact than initially
   scoped, **escalate to Step 5a** (full re-read).

### Step 6 — Update reports and stale analysis

Update all report pages:

- add new mismatches and resolve cleared mismatches
- refresh high-risk change report based on changed files
- refresh stale-pages report (pages whose evidence is older than code changes)
- refresh latest summary

Append Update entry to log.

### Step 7 — Update generated index metadata

Update in `docs/tech-docs/index.md`:

- `last-scan` = now (UTC ISO-8601)
- `repositories[].last-commit-hash` for changed repos to current HEAD

Update index body only when pages are added/removed/renamed.

### Step 8 — No-op guard

If no module/design/report content changed:

1. still update `last-scan` to reflect a completed scan,
2. append log entry,
3. report "No generated pages required updates."

### Step 9 — Report outcome

Return summary:

- repos checked / with changes / skipped
- modules updated: count (structural: N, incremental: N)
- design pages updated
- curated files reviewed
- mismatches found or resolved
- high-risk deltas detected
- scope extensions triggered: {N} (within-module: {N}, cross-module: {N})
- no-op status if applicable

---

## Run Log Format

`docs/tech-docs/log.md` is append-only.

Header:

```markdown
# Knowledge Update Run Log

<!-- append-only: one entry per run, newest last -->
```

Init entry:

```markdown
## {ISO-8601 UTC timestamp} — Init
- Repos: {comma-separated repo names}
- Modules created: {N}
- Design topics: {N}
- Curated files incorporated: {N}
- Mismatches flagged: {N}
```

Update entry:

```markdown
## {ISO-8601 UTC timestamp} — Update
- Repos checked: {N} ({N} with changes)
- Modules updated: {N} (structural: {N}, incremental: {N})
- Design topics updated: {N}
- Curated files incorporated: {N}
- Scope extensions triggered: {N} (within-module: {N}, cross-module: {N})
- Mismatches flagged: {N}
```

---

## Quality Guardrails

All guardrails are hard constraints — no exceptions.

| # | Constraint |
|---|---|
| 1 | Source code is the only authoritative proof. Curated docs declare intent; generated docs are orientation maps. Never cite either as runtime proof. |
| 2 | A claim without a source citation (`source: repo/path/file.ext`) must NOT appear in any generated page. |
| 3 | Prefer deterministic rewrites and minimal churn — only rewrite pages with actual content changes. |
| 4 | Keep generated content high-value: flows, boundaries, invariants, risks, mismatches. No restatement of obvious structure. |
| 5 | Record all uncertainty in `known-gaps` and `confidence`. Never silently assume completeness. |
